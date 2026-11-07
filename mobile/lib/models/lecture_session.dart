class LectureSession {
  final String id;
  final String courseId;
  final String manualCourseCode;
  final String manualCourseTitle;
  final int day;
  final int startMinute;
  final int endMinute;
  final String venue;
  final String lecturer;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isDeleted;
  final int syncVersion;

  const LectureSession({
    required this.id,
    required this.courseId,
    required this.day,
    required this.startMinute,
    required this.endMinute,
    required this.venue,
    required this.lecturer,
    required this.createdAt,
    required this.updatedAt,
    this.manualCourseCode = '',
    this.manualCourseTitle = '',
    this.isDeleted = false,
    this.syncVersion = 0,
  });

  bool get isManual => manualCourseCode.trim().isNotEmpty;

  LectureSession copyWith({
    String? id,
    String? courseId,
    String? manualCourseCode,
    String? manualCourseTitle,
    int? day,
    int? startMinute,
    int? endMinute,
    String? venue,
    String? lecturer,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isDeleted,
    int? syncVersion,
  }) {
    return LectureSession(
      id: id ?? this.id,
      courseId: courseId ?? this.courseId,
      manualCourseCode:
          manualCourseCode ?? this.manualCourseCode,
      manualCourseTitle:
          manualCourseTitle ?? this.manualCourseTitle,
      day: day ?? this.day,
      startMinute: startMinute ?? this.startMinute,
      endMinute: endMinute ?? this.endMinute,
      venue: venue ?? this.venue,
      lecturer: lecturer ?? this.lecturer,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
      syncVersion: syncVersion ?? this.syncVersion,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'course_id': courseId,
      'manual_course_code': manualCourseCode,
      'manual_course_title': manualCourseTitle,
      'day': day,
      'start_minute': startMinute,
      'end_minute': endMinute,
      'venue': venue,
      'lecturer': lecturer,
      'created_at': createdAt.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
      'is_deleted': isDeleted,
      'sync_version': syncVersion,
    };
  }

  factory LectureSession.fromMap(Map<String, dynamic> map) {
    dynamic read(String snake, String camel) {
      return map[snake] ?? map[camel];
    }

    String stringValue(dynamic value) =>
        value?.toString() ?? '';

    int intValue(dynamic value, [int fallback = 0]) {
      if (value is num) return value.toInt();
      return int.tryParse(value?.toString() ?? '') ??
          fallback;
    }

    bool boolValue(dynamic value) {
      return value == true ||
          value == 1 ||
          value == 'true' ||
          value == '1';
    }

    DateTime dateValue(dynamic value) {
      if (value is DateTime) return value.toUtc();
      return DateTime.tryParse(value?.toString() ?? '')
              ?.toUtc() ??
          DateTime.fromMillisecondsSinceEpoch(
            0,
            isUtc: true,
          );
    }

    return LectureSession(
      id: stringValue(map['id']),
      courseId:
          stringValue(read('course_id', 'courseId')),
      manualCourseCode: stringValue(
        read('manual_course_code', 'manualCourseCode'),
      ),
      manualCourseTitle: stringValue(
        read('manual_course_title', 'manualCourseTitle'),
      ),
      day: intValue(map['day'], 1),
      startMinute:
          intValue(read('start_minute', 'startMinute')),
      endMinute:
          intValue(read('end_minute', 'endMinute')),
      venue: stringValue(map['venue']),
      lecturer: stringValue(map['lecturer']),
      createdAt:
          dateValue(read('created_at', 'createdAt')),
      updatedAt:
          dateValue(read('updated_at', 'updatedAt')),
      isDeleted:
          boolValue(read('is_deleted', 'isDeleted')),
      syncVersion:
          intValue(read('sync_version', 'syncVersion')),
    );
  }
}