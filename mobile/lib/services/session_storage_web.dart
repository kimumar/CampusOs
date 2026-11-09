// Browser preview uses an in-memory session only. No refresh tokens are
// written to localStorage, sessionStorage, cookies, or untrusted HTTP origins.
class SessionStorage {
  SessionStorage._();
  static String? _refresh;
  static Future<void> writeRefresh(String? token) async { _refresh = token; }
  static Future<String?> readRefresh() async => _refresh;
  static Future<void> clearRefresh() async { _refresh = null; }
}
