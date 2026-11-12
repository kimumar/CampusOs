import 'package:hive_ce_flutter/hive_flutter.dart';
import 'account_scope.dart';

/// Stores resumable recall sessions locally and within the current account scope.
/// It contains no uploaded document bytes and makes no network requests.
class RecallSessionStorage {
  RecallSessionStorage._();

  static const boxName = 'campus_recall_sessions_v1';
  static Box<dynamic>? _box;

  static Future<void> initialize() async {
    _box ??= await Hive.openBox<dynamic>(boxName);
  }

  static Box<dynamic> get _db {
    final box = _box;
    if (box == null || !box.isOpen) {
      throw StateError('Recall session storage not initialized');
    }
    return box;
  }

  static String _key(String sessionId) =>
      AccountScope.key('recall_session::$sessionId');

  static Map<String, dynamic>? read(String sessionId) {
    final raw = _db.get(_key(sessionId));
    return raw is Map && raw['is_deleted'] != true ? Map<String, dynamic>.from(raw) : null;
  }

  static List<Map<String, dynamic>> all() {
    final results = <Map<String, dynamic>>[];
    for (final key in _db.keys) {
      final keyText = key.toString();
      if (!AccountScope.owns(key) ||
          !keyText.contains('::recall_session::')) {
        continue;
      }
      final raw = _db.get(key);
      if (raw is Map && raw['is_deleted'] != true) results.add(Map<String, dynamic>.from(raw));
    }
    results.sort((a, b) =>
        (b['updated_at'] as String? ?? '').compareTo(a['updated_at'] as String? ?? ''));
    return results;
  }

  static List<Map<String, dynamic>> allForSync() {
    final records = <Map<String, dynamic>>[];
    for (final key in _db.keys) {
      if (!AccountScope.owns(key) || !key.toString().contains('::recall_session::')) continue;
      final value = _db.get(key);
      if (value is Map) records.add(Map<String, dynamic>.from(value));
    }
    return records;
  }

  /// Remote snapshots only win when strictly newer; preserve local answers.
  static Future<void> mergeFromCloud(Map<String, dynamic> remote) async {
    final identifier = (remote['session_id'] ?? '').toString();
    if (identifier.isEmpty || identifier.length > 100) return;
    final updated = DateTime.tryParse((remote['updated_at'] ?? '').toString());
    if (updated == null) return;
    final key = _key(identifier);
    final existing = _db.get(key);
    if (existing is Map) {
      final localTime = DateTime.tryParse((existing['updated_at'] ?? '').toString());
      if (localTime != null && !updated.isAfter(localTime)) return;
    }
    await _db.put(key, Map<String, dynamic>.from(remote));
  }

  static Future<void> save({
    required String sessionId,
    required String missionId,
    required String topic,
    required String notes,
    required List<Map<String, dynamic>> questions,
    required int currentIndex,
    required Map<String, String> answers,
    required List<int> completedIndices,
    required List<int> skippedIndices,
    required List<String> warnings,
    String courseId = '',
    String courseName = '',
    String courseCode = '',
  }) async {
    if (sessionId.trim().isEmpty) {
      throw ArgumentError.value(sessionId, 'sessionId');
    }
    await _db.put(_key(sessionId), <String, dynamic>{
      'session_id': sessionId,
      'mission_id': missionId,
      'topic': topic,
      'course_id': courseId,
      'course_name': courseName,
      'course_code': courseCode,
      'notes': notes,
      'questions': questions,
      'current_index': currentIndex,
      'answers': answers,
      'completed_indices': completedIndices,
      'skipped_indices': skippedIndices,
      'warnings': warnings,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  static Future<void> delete(String sessionId) async {
    final existing = _db.get(_key(sessionId));
    if (existing is! Map) return;
    await _db.put(_key(sessionId), {
      ...Map<String, dynamic>.from(existing),
      'is_deleted': true,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
  }
}
