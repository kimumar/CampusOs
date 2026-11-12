import 'package:hive_ce_flutter/hive_flutter.dart';
import 'account_scope.dart';

/// Lightweight learning activity log; it never counts an untimed study minute.
class StudySessionStorage {
  StudySessionStorage._();
  static const boxName = 'campus_study_sessions_v1';
  static Box<dynamic>? _box;

  static Future<void> initialize() async {
    if (_box == null || !_box!.isOpen) _box = await Hive.openBox<dynamic>(boxName);
  }

  static Box<dynamic> get _db {
    final box = _box;
    if (box == null || !box.isOpen) throw StateError('Study activity storage not initialized');
    return box;
  }

  static List<Map<String, dynamic>> all() {
    final records = <Map<String, dynamic>>[];
    for (final key in _db.keys) {
      if (!AccountScope.owns(key) || !key.toString().contains('::study_session::')) continue;
      final raw = _db.get(key);
      if (raw is Map) records.add(Map<String, dynamic>.from(raw));
    }
    records.sort((a, b) => (b['finished_at'] ?? '').toString().compareTo((a['finished_at'] ?? '').toString()));
    return records;
  }

  static Future<void> record({
    required String id,
    required String missionId,
    required String topic,
    String courseId = '',
    String courseName = '',
    String courseCode = '',
    required int timedMinutes,
    bool hasLearningWork = false,
  }) async {
    if (id.trim().isEmpty) throw ArgumentError('Study session ID is required');
    await _db.put(AccountScope.key('study_session::$id'), <String, dynamic>{
      'id': id,
      'mission_id': missionId,
      'topic': topic.trim(),
      'course_id': courseId,
      'course_name': courseName,
      'course_code': courseCode,
      'timed_minutes': timedMinutes < 0 ? 0 : timedMinutes,
      'has_learning_work': hasLearningWork,
      'finished_at': DateTime.now().toUtc().toIso8601String(),
    });
  }
}
