import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';

class SessionStorage {
  SessionStorage._();
  static const _storage = FlutterSecureStorage();
  static Future<void> writeRefresh(String? token) async {
    if (token == null) {
      await _storage.delete(key: 'campusos_refresh');
    } else {
      await _storage.write(key: 'campusos_refresh', value: token);
    }
  }
  static Future<String?> readRefresh() => _storage.read(key: 'campusos_refresh');
  static Future<void> clearRefresh() => _storage.delete(key: 'campusos_refresh');
  static Future<void> writeVerifiedAccount(Map<String, dynamic> account) =>
      _storage.write(key: 'campusos_offline_account', value: jsonEncode({
        'account': account,
        'verified_at': DateTime.now().toUtc().toIso8601String(),
      }));
  static Future<Map<String, dynamic>?> readVerifiedAccount() async {
    final raw = await _storage.read(key: 'campusos_offline_account');
    if (raw == null) return null;
    try { return Map<String, dynamic>.from(jsonDecode(raw) as Map); }
    catch (_) { return null; }
  }
  static Future<void> clearVerifiedAccount() => _storage.delete(key: 'campusos_offline_account');
}
