import 'package:hive_ce_flutter/hive_flutter.dart';
import 'account_scope.dart';

/// Plain-text student notes only. Imported image bytes are never stored here.
class LessonNotesStorage {
  LessonNotesStorage._();
  static const boxName = 'campus_lesson_notes_v1';
  static Box<dynamic>? _box;

  static Future<void> initialize() async {
    if (_box == null || !_box!.isOpen) _box = await Hive.openBox<dynamic>(boxName);
  }

  static Box<dynamic> get _db {
    final box = _box;
    if (box == null || !box.isOpen) throw StateError('Lesson notes storage not initialized');
    return box;
  }

  static List<Map<String, dynamic>> all() {
    final records = <Map<String, dynamic>>[];
    for (final key in _db.keys) {
      if (!AccountScope.owns(key) || !key.toString().contains('::lesson_note::')) continue;
      final raw = _db.get(key);
      if (raw is Map && raw['deleted'] != true) records.add(Map<String, dynamic>.from(raw));
    }
    records.sort((a, b) => (b['updated_at'] ?? '').toString().compareTo((a['updated_at'] ?? '').toString()));
    return records;
  }

  /// Never replace newer local text with an older server snapshot.
  static Future<void> mergeFromCloud(Map<String, dynamic> remote) async {
    final identifier = (remote['id'] ?? '').toString();
    if (identifier.isEmpty || identifier.length > 100) return;
    final updated = DateTime.tryParse((remote['updated_at'] ?? '').toString());
    if (updated == null) return;
    final key = AccountScope.key('lesson_note::$identifier');
    final existing = _db.get(key);
    if (existing is Map) {
      final localTime = DateTime.tryParse((existing['updated_at'] ?? '').toString());
      if (localTime != null && !updated.isAfter(localTime)) return;
    }
    await _db.put(key, Map<String, dynamic>.from(remote));
  }

  static Future<String> save({String? id, required String title, required String text,
    String courseId = '', String courseName = '', String courseCode = ''}) async {
    if (text.trim().isEmpty) throw ArgumentError('Notes text is empty');
    final now = DateTime.now().toUtc();
    final identifier = id ?? '${now.microsecondsSinceEpoch}_${title.hashCode.abs()}';
    final previous = _db.get(AccountScope.key('lesson_note::$identifier'));
    final prior = previous is Map ? Map<String, dynamic>.from(previous) : null;
    final changed = prior == null || (prior['text'] ?? '').toString().trim() != text.trim();
    final meaningfulAt = changed && text.trim().length >= 20
        ? now.toIso8601String()
        : (prior?['meaningful_updated_at'] ?? prior?['updated_at'] ?? '').toString();
    await _db.put(AccountScope.key('lesson_note::$identifier'), <String, dynamic>{
      'id': identifier, 'title': title.trim(), 'text': text.trim(),
      'course_id': courseId, 'course_name': courseName, 'course_code': courseCode,
      'updated_at': now.toIso8601String(),
      'meaningful_updated_at': meaningfulAt,
    });
    return identifier;
  }
}
