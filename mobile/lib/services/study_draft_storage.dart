import 'package:hive_ce_flutter/hive_flutter.dart';
import 'account_scope.dart';

/// M04-B1: account-isolated local drafts. Not synced to Django.
class StudyDraftStorage {
  StudyDraftStorage._();
  static const boxName = 'campus_study_drafts_v1';
  static Box<dynamic>? _box;

  static Future<void> initialize() async {
    _box ??= await Hive.openBox<dynamic>(boxName);
  }

  static Box<dynamic> get _db {
    final box = _box;
    if (box == null || !box.isOpen) {
      throw StateError('Study draft storage not initialized');
    }
    return box;
  }

  static String _key(String missionId) => AccountScope.key('study_draft::$missionId');

  static Map<String, dynamic>? read(String missionId) {
    final raw = _db.get(_key(missionId));
    return raw is Map ? Map<String, dynamic>.from(raw) : null;
  }

  static Future<void> save({
    required String missionId,
    required String topic,
    required String objective,
    required String notes,
    required int elapsedSeconds,
    bool useTimer = false,
    int targetMinutes = 25,
    String courseId = '',
  }) async {
    await _db.put(_key(missionId), <String, dynamic>{
      'topic': topic,
      'course_id': courseId,
      'objective': objective,
      'notes': notes,
      'elapsed_seconds': elapsedSeconds,
      'use_timer': useTimer,
      'target_minutes': targetMinutes,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  static Future<void> clear(String missionId) => _db.delete(_key(missionId));
}
