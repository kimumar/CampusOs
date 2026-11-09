import 'cloud_sync.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'account_scope.dart';

import '../models/campus_course.dart';

class CourseStorage {
  CourseStorage._();

  static const String _boxName = 'campus_courses_v1';

  static Box<dynamic>? _box;

  static Future<void> initialize() async {
    await Hive.initFlutter();

    _box = await Hive.openBox<dynamic>(_boxName);
  }

  static Box<dynamic> get _database {
    final box = _box;

    if (box == null || !box.isOpen) {
      throw StateError(
        'CourseStorage has not been initialized.',
      );
    }

    return box;
  }

  static List<CampusCourse> allForSync() {
    final result = <CampusCourse>[];
    for (final entry in _database.toMap().entries) {
      if (!AccountScope.owns(entry.key) || entry.value is! Map) continue;
      try { result.add(CampusCourse.fromMap(Map<String, dynamic>.from(entry.value as Map))); } catch (_) {}
    }
    return result;
  }

  static List<CampusCourse> getCourses() {
    final courses = <CampusCourse>[];

    for (final entry in _database.toMap().entries) {
      if (!AccountScope.owns(entry.key)) continue;
      final value = entry.value;
      if (value is Map) {
        try {
          final course = CampusCourse.fromMap(
            Map<String, dynamic>.from(value),
          );

          if (!course.isDeleted) {
            courses.add(course);
          }
        } catch (_) {
          // Preserve other readable records.
          // Do not automatically delete unreadable data.
        }
      }
    }

    courses.sort(
      (a, b) => a.code.compareTo(b.code),
    );

    return courses;
  }

  static Future<void> saveCourse(
    CampusCourse course,
  ) async {
    await _database.put(
      AccountScope.key(course.id),
      course.toMap(),
    );
    CloudSync.queueSync();
  }

  static Future<void> deleteCourse(
    CampusCourse course,
  ) async {
    final deleted = course.copyWith(
      isDeleted: true,
      updatedAt: DateTime.now().toUtc(),
    );

    await _database.put(
      AccountScope.key(course.id),
      deleted.toMap(),
    );
    CloudSync.queueSync();
  }

  static bool courseCodeExists(
    String code, {
    String? excludeId,
  }) {
    final normalized = code.trim().toUpperCase();

    return getCourses().any(
      (course) =>
          course.code.toUpperCase() == normalized &&
          course.id != excludeId,
    );
  }

  static int get totalUnits {
    return getCourses().fold(
      0,
      (total, course) => total + course.units,
    );
  }

  static int get courseCount {
    return getCourses().length;
  }
}