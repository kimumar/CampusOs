import 'cloud_sync.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'account_scope.dart';

import '../models/lecture_session.dart';

class LectureStorage {
  LectureStorage._();

  static const String _boxName = 'campus_lectures_v1';

  static Box<dynamic>? _box;

  static Future<void> initialize() async {
    if (_box != null && _box!.isOpen) return;

    _box = await Hive.openBox<dynamic>(_boxName);
  }

  static Box<dynamic> get _database {
    final box = _box;

    if (box == null || !box.isOpen) {
      throw StateError(
        'LectureStorage has not been initialized.',
      );
    }

    return box;
  }

  static List<LectureSession> allForSync() {
    final result = <LectureSession>[];
    for (final entry in _database.toMap().entries) {
      if (!AccountScope.owns(entry.key) || entry.value is! Map) continue;
      try { result.add(LectureSession.fromMap(Map<String, dynamic>.from(entry.value as Map))); } catch (_) {}
    }
    return result;
  }

  static List<LectureSession> getLectures() {
    final lectures = <LectureSession>[];

    for (final entry in _database.toMap().entries) {
      if (!AccountScope.owns(entry.key)) continue;
      final value = entry.value;
      if (value is! Map) continue;

      try {
        final lecture = LectureSession.fromMap(
          Map<String, dynamic>.from(value),
        );

        if (!lecture.isDeleted) {
          lectures.add(lecture);
        }
      } catch (_) {
        // Preserve unreadable records in storage.
        // Never delete data automatically.
      }
    }

    lectures.sort((a, b) {
      final dayCompare = a.day.compareTo(b.day);

      if (dayCompare != 0) return dayCompare;

      return a.startMinute.compareTo(b.startMinute);
    });

    return lectures;
  }

  static Future<void> saveLecture(
    LectureSession lecture,
  ) async {
    if (lecture.id.trim().isEmpty) {
      throw ArgumentError('Lecture ID is required.');
    }

    if (lecture.day < 1 || lecture.day > 7) {
      throw ArgumentError('Invalid lecture day.');
    }

    if (lecture.startMinute < 0 ||
        lecture.endMinute > 1440 ||
        lecture.endMinute <= lecture.startMinute) {
      throw ArgumentError('Invalid lecture time.');
    }

    if (lecture.courseId.trim().isEmpty &&
        lecture.manualCourseCode.trim().isEmpty) {
      throw ArgumentError(
        'Select or manually enter a course.',
      );
    }

    await _database.put(AccountScope.key(lecture.id), lecture.toMap());
    CloudSync.queueSync();
  }

  static Future<void> deleteLecture(
    LectureSession lecture,
  ) async {
    final deleted = lecture.copyWith(
      isDeleted: true,
      updatedAt: DateTime.now().toUtc(),
    );

    await _database.put(AccountScope.key(deleted.id), deleted.toMap());
    CloudSync.queueSync();
  }

  static LectureSession? findConflict(
    LectureSession candidate,
  ) {
    for (final lecture in getLectures()) {
      if (lecture.id == candidate.id) continue;
      if (lecture.day != candidate.day) continue;

      final overlaps =
          candidate.startMinute < lecture.endMinute &&
          candidate.endMinute > lecture.startMinute;

      if (overlaps) return lecture;
    }

    return null;
  }
}