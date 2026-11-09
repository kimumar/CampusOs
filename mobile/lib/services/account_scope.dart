class AccountScope {
  AccountScope._();
  static String? _id;
  static String get id {
    final value = _id;
    if (value == null || value.isEmpty) throw StateError('No authenticated account');
    return value;
  }
  static void activate(String id) {
    if (id.isEmpty || !RegExp(r'^[a-fA-F0-9-]{36}$').hasMatch(id)) {
      throw ArgumentError('Invalid account ID');
    }
    _id = id;
  }
  static void clear() => _id = null;
  static String key(String recordId) => '$id::$recordId';
  static bool owns(Object? key) => key is String && key.startsWith('$id::');
}
