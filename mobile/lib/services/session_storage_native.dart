import 'package:flutter_secure_storage/flutter_secure_storage.dart';

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
}
