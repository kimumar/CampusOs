import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'session_storage.dart';
import 'account_scope.dart';
import 'api_endpoint_policy.dart';
import 'community_pulse.dart';

class AuthApi {
  AuthApi._();
  static const String base = String.fromEnvironment('API_BASE_URL', defaultValue: 'http://127.0.0.1:8000');
  static String? _access;
  static String? _refresh;
  static Map<String, dynamic>? account;
  static DateTime? _lastVerifiedOnlineUtc;
  static bool _offlineMode = false;
  static DateTime? get offlineAccessUntil {
    final verified = _lastVerifiedOnlineUtc;
    if (verified == null) return null;
    final expiryCandidates = [account?['trial_ends_at'], account?['paid_until'], account?['complimentary_until']]
      .map((value) => DateTime.tryParse((value ?? '').toString())?.toUtc())
      .whereType<DateTime>().where((date) => date.isAfter(DateTime.now().toUtc())).toList();
    if (account?['complimentary_lifetime'] == true) {
      expiryCandidates.add(DateTime.now().toUtc().add(const Duration(days: 36500)));
    }
    if (expiryCandidates.isEmpty) return null;
    final maxEntitlement = expiryCandidates.reduce((a,b) => a.isAfter(b) ? a : b);
    final rawHours = account?['offline_hours'];
    final safeHours = rawHours is int && rawHours > 0 && rawHours <= 24 ? rawHours : 24;
    final offlineLimit = verified.add(Duration(hours: safeHours));
    return maxEntitlement.isBefore(offlineLimit) ? maxEntitlement.toLocal() : offlineLimit.toLocal();
  }
  static bool get academicAccess => account?['academic_access'] == true &&
      _lastVerifiedOnlineUtc != null && offlineAccessUntil?.isAfter(DateTime.now()) == true && !_offlineMode;
  static bool get offlineAcademicAccess => _offlineMode && account?['academic_access'] == true &&
      offlineAccessUntil?.isAfter(DateTime.now()) == true;
  static bool get hasUsableAccess => academicAccess || offlineAcademicAccess;
  static Uri _uri(String path) {
    final origin = ApiEndpointPolicy.validate(base, releaseMode: kReleaseMode);
    return origin.replace(path: '/api/v1/auth/$path/');
  }
  static Map<String,String> get _headers => {'Content-Type':'application/json', if (_access != null) 'Authorization':'Bearer $_access'};
  static Future<Map<String,dynamic>> _call(String path, {String method='POST', Map<String,dynamic>? data}) async {
    final request = http.Request(method, _uri(path));
    // A redirect must never forward an access or refresh token to a new host.
    request.followRedirects = false;
    request.headers.addAll(_headers);
    if (data != null) request.body = jsonEncode(data);
    final client = http.Client();
    late final http.Response response;
    try { response = await http.Response.fromStream(await client.send(request).timeout(const Duration(seconds: 15))); } finally { client.close(); }
    if (response.isRedirect) {
      throw const FormatException('Unexpected API redirect. Check the CampusOS server address.');
    }
    Map<String,dynamic> payload;
    try { payload = Map<String,dynamic>.from(jsonDecode(response.body) as Map); }
    catch (_) { throw Exception('Server returned an unexpected response (${response.statusCode}).'); }
    if (response.statusCode >= 400) {
      final message = payload['detail'] ?? payload['message'] ?? payload.values.join(', ');
      throw Exception(message.toString());
    }
    return payload;
  }
  static Future<String> register(String email, String password, {String referralCode = ''}) async =>
      (await _call('register', data:{'email':email,'password':password,
        if (referralCode.trim().isNotEmpty) 'referral_code':referralCode.trim().toUpperCase()}))['message'].toString();
  static Future<String> verifyCode(String email, String code) async =>
      (await _call('verify-code', data:{'email':email,'code':code}))['message'].toString();
  static Future<String> verify(String uid, String token) async =>
      (await _call('verify-email', data:{'uid':uid,'token':token}))['message'].toString();
  static Future<String> resend(String email) async =>
      (await _call('resend-verification', data:{'email':email}))['message'].toString();
  static Future<String> resetRequest(String email) async =>
      (await _call('password-reset', data:{'email':email}))['message'].toString();
  static Future<String> resetConfirm(String uid,String token,String password) async =>
      (await _call('password-reset/confirm',data:{'uid':uid,'token':token,'password':password}))['message'].toString();
  static Future<void> login(String email,String password) async {
    final tokens = await _call('login', data:{'email':email,'password':password});
    _access = tokens['access'] as String;
    _refresh = tokens['refresh'] as String;
    try { await loadMe(); }
    catch (_) { _access=null; _refresh=null; rethrow; }
    await SessionStorage.writeRefresh(_refresh);
  }
  static Future<bool> restore() async {
    _refresh = await SessionStorage.readRefresh();
    if (_refresh == null) return false;
    try { await refresh(); await loadMe(); return true; }
    catch (_) {
      // A temporary outage must not delete a student's secure refresh token.
      return _restoreOfflineAccount();
    }
  }
  static Future<bool> _restoreOfflineAccount() async {
    final cached = await SessionStorage.readVerifiedAccount();
    if (cached == null) return false;
    final validatedAt = DateTime.tryParse((cached['verified_at'] ?? '').toString())?.toUtc();
    final info = cached['account'];
    if (validatedAt == null || info is! Map ||
        DateTime.now().toUtc().difference(validatedAt).isNegative ||
        DateTime.now().toUtc().difference(validatedAt) > const Duration(days: 30)) {
      return false;
    }
    final result = Map<String, dynamic>.from(info);
    if (result['academic_access'] != true) return false;
    // Keep the account shell usable after access expires. Only the gate,
    // not the session restoration, decides whether academic tools unlock.
    try { AccountScope.activate((result['id'] ?? '').toString()); }
    catch (_) { return false; }
    account = result;
    _lastVerifiedOnlineUtc = validatedAt;
    _offlineMode = true;
    return true;
  }
  static Future<bool> tryOfflineAccess() => _restoreOfflineAccount();
  static Future<void> refresh() async {
    if (_refresh == null) throw Exception('Please log in again.');
    final tokens = await _call('refresh',data:{'refresh':_refresh});
    _access = tokens['access'] as String;
    if (tokens['refresh'] is String) {
      _refresh = tokens['refresh'] as String;
      await SessionStorage.writeRefresh(_refresh);
    }
  }
  static Future<void> loadMe() async {
    Map<String,dynamic> result;
    try { result = await _call('me',method:'GET'); }
    catch (_) { await refresh(); result = await _call('me',method:'GET'); }
    final id = result['id']?.toString() ?? '';
    AccountScope.activate(id);
    account = result;
    _lastVerifiedOnlineUtc = DateTime.now().toUtc();
    _offlineMode = false;
    if (result['academic_access'] == true) {
      try { await SessionStorage.writeVerifiedAccount(result); }
      catch (_) { /* Secure cache failure cannot invalidate a live login. */ }
    }
  }
  static Future<Map<String,dynamic>> fetchProfile() => _call('profile', method:'GET');
  static Future<Map<String,dynamic>> myInvitation() => _call('my-invitation', method:'GET');
  static Future<void> changePassword(String currentPassword, String newPassword) async {
    await _call('change-password', data:{'current_password':currentPassword,'new_password':newPassword});
  }

  static Future<void> submitSupportTicket(String category, String message) async {
    await _call('support-tickets', data: {'category': category, 'message': message});
  }
  static Future<void> saveProfile(Map<String,dynamic> profile) async { await _call('profile', method:'PATCH', data:profile); }
  static bool get pulseOptedIn => account?['profile'] is Map && account!['profile']['pulse_opt_in'] == true;
  static Future<void> setPulseOptIn(bool optedIn) async {
    final response = await _call('profile', method:'PATCH', data:{'pulse_opt_in': optedIn});
    if (account != null) account!['profile'] = response;
    // Cache only if already validated and academically eligible.
    if (account?['academic_access'] == true) await SessionStorage.writeVerifiedAccount(account!);
  }
  static Future<List<dynamic>> syncRecords(List<Map<String,dynamic>> records) async {
    final result = await _call('academic-records', data:{'records':records});
    return (result['records'] as List?) ?? [];
  }
  /// The server is authoritative: never reinterpret local progress as a
  /// community percentage. The endpoint authenticates subscription status.
  static Future<CommunityPulse> communityPulse(String period) async {
    if (!const {'today', 'week', 'month'}.contains(period)) {
      throw ArgumentError.value(period, 'period');
    }
    final result = await _call('community-pulse/$period', method: 'GET');
    return CommunityPulse.fromJson(result, period);
  }

  static Future<void> uploadAcademicProgress(List<Map<String, dynamic>> days) async {
    if (days.isEmpty) return;
    await _call('academic-progress', data: {'days': days});
  }
  static Future<void> logout() async {
    _access=null; _refresh=null; account=null; _lastVerifiedOnlineUtc=null; _offlineMode=false;
    AccountScope.clear();
    await SessionStorage.clearRefresh();
    await SessionStorage.clearVerifiedAccount();
  }
}
