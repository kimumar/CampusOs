import 'dart:convert';
import 'package:http/http.dart' as http;
import 'session_storage.dart';
import 'account_scope.dart';

class AuthApi {
  AuthApi._();
  static const String base = String.fromEnvironment('API_BASE_URL', defaultValue: 'http://127.0.0.1:8000');
  static String? _access;
  static String? _refresh;
  static Map<String, dynamic>? account;
  static DateTime? _lastValidated;
  static bool get academicAccess => account?['academic_access'] == true &&
      _lastValidated != null && DateTime.now().difference(_lastValidated!).inMinutes < 5;
  static Uri _uri(String path) => Uri.parse('$base/api/v1/auth/$path/');
  static Map<String,String> get _headers => {'Content-Type':'application/json', if (_access != null) 'Authorization':'Bearer $_access'};
  static Future<Map<String,dynamic>> _call(String path, {String method='POST', Map<String,dynamic>? data}) async {
    final request = http.Request(method, _uri(path));
    request.headers.addAll(_headers);
    if (data != null) request.body = jsonEncode(data);
    final client = http.Client();
    late final http.Response response;
    try { response = await http.Response.fromStream(await client.send(request).timeout(const Duration(seconds: 15))); } finally { client.close(); }
    Map<String,dynamic> payload;
    try { payload = Map<String,dynamic>.from(jsonDecode(response.body) as Map); }
    catch (_) { throw Exception('Server returned an unexpected response (${response.statusCode}).'); }
    if (response.statusCode >= 400) {
      final message = payload['detail'] ?? payload['message'] ?? payload.values.join(', ');
      throw Exception(message.toString());
    }
    return payload;
  }
  static Future<String> register(String email, String password) async =>
      (await _call('register', data:{'email':email,'password':password}))['message'].toString();
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
    catch (_) { await logout(); return false; }
  }
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
    _lastValidated = DateTime.now();
  }
  static Future<Map<String,dynamic>> fetchProfile() => _call('profile', method:'GET');
  static Future<void> saveProfile(Map<String,dynamic> profile) async { await _call('profile', method:'PATCH', data:profile); }
  static Future<List<dynamic>> syncRecords(List<Map<String,dynamic>> records) async {
    final result = await _call('academic-records', data:{'records':records});
    return (result['records'] as List?) ?? [];
  }
  static Future<void> logout() async {
    _access=null; _refresh=null; account=null; _lastValidated=null;
    AccountScope.clear();
    await SessionStorage.clearRefresh();
  }
}
