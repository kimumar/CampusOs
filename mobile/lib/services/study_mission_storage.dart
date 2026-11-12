import 'package:hive_ce_flutter/hive_flutter.dart';
import 'account_scope.dart';
import 'academic_mission_planner.dart';
import 'academic_task_storage.dart';
import 'course_storage.dart';
import 'lecture_storage.dart';
import 'recall_session_storage.dart';
import 'recall_storage.dart';
import 'study_session_storage.dart';
import 'lesson_notes_storage.dart';
import 'campus_pulse_calculator.dart';
import 'academic_progress_engine.dart';

/// M04-C: real-record-based, gentle missions. Old missions stay archived in
/// the existing Hive box. No timer quota, invented tasks, or penalty for skips.
class StudyMissionStorage {
  StudyMissionStorage._();
  static const boxName = 'campus_study_missions_v1';
  static Box<dynamic>? _box;

  static Future<void> initialize() async {
    if (_box == null || !_box!.isOpen) _box = await Hive.openBox<dynamic>(boxName);
    await AcademicTaskStorage.initialize();
    await StudySessionStorage.initialize();
    await LessonNotesStorage.initialize();
    await RecallStorage.initialize();
    await RecallSessionStorage.initialize();
  }

  static Box<dynamic> get _db {
    final box = _box;
    if (box == null || !box.isOpen) throw StateError('Study missions storage not initialized');
    return box;
  }

  static String dayKey([DateTime? now]) {
    final day = now ?? DateTime.now();
    return '${day.year.toString().padLeft(4, '0')}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
  }

  static String _key(String date) => AccountScope.key('missions::$date');

  static List<Map<String, dynamic>> _read(String date) {
    final raw = _db.get(_key(date));
    if (raw is! List) return [];
    return raw.whereType<Map>().map((record) => Map<String, dynamic>.from(record)).toList();
  }

  static List<Map<String, dynamic>> today() {
    final saved = _read(dayKey());
    if (saved.isNotEmpty && saved.every((record) => record['version'] == 2)) return saved;
    return suggestionsFor(DateTime.now());
  }

  static List<Map<String, dynamic>> suggestionsFor(DateTime day) {
    final date = dayKey(day);
    final candidates = <Map<String, dynamic>>[];
    void add(String id, String title, String kind, int priority, {
      String courseId = '', String courseName = '', String courseCode = '', String refId = ''}) {
      candidates.add(<String, dynamic>{
        'id': '$date::$id', 'title': title, 'kind': kind, 'priority': priority,
        'course_id': courseId, 'course_name': courseName, 'course_code': courseCode,
        'ref_id': refId, 'done': false, 'minutes': 0, 'version': 2,
      });
    }

    for (final task in AcademicTaskStorage.all(includeDone: false)) {
      final due = DateTime.tryParse((task['due_at'] ?? '').toString())?.toLocal();
      if (due == null) continue;
      final priority = AcademicMissionPlanner.urgency(due, day);
      if (priority <= 0) continue;
      final kind = (task['kind'] ?? 'assignment').toString();
      final action = kind == 'exam' ? 'Prepare for' : 'Work on';
      add('task::${task['id']}', '$action ${task['title']}', 'task', priority,
        refId: (task['id'] ?? '').toString(),
        courseId: (task['course_id'] ?? '').toString(),
        courseName: (task['course_name'] ?? '').toString(),
        courseCode: (task['course_code'] ?? '').toString());
    }

    for (final session in RecallSessionStorage.all()) {
      final rawQuestions = session['questions'];
      final rawCompleted = session['completed_indices'];
      final rawSkipped = session['skipped_indices'];
      final total = rawQuestions is List ? rawQuestions.length : 0;
      final completed = rawCompleted is List ? rawCompleted.length : 0;
      final skipped = rawSkipped is List ? rawSkipped.length : 0;
      if (total == 0 || completed + skipped >= total) continue;
      final topic = (session['topic'] ?? '').toString().trim();
      add('recall::${session['session_id']}', 'Continue recall${topic.isEmpty ? '' : ': $topic'}', 'recall', 72,
        refId: (session['session_id'] ?? '').toString(),
        courseId: (session['course_id'] ?? '').toString(),
        courseName: (session['course_name'] ?? '').toString(),
        courseCode: (session['course_code'] ?? '').toString());
    }

    final dueGrouped = <String, Map<String, dynamic>>{};
    for (final item in RecallStorage.all()) {
      final next = DateTime.tryParse((item['next_review_at'] ?? '').toString())?.toLocal();
      if (next == null || next.isAfter(day.add(const Duration(days: 1)))) continue;
      final courseId = (item['course_id'] ?? '').toString();
      final group = courseId.isEmpty ? (item['topic'] ?? '').toString() : courseId;
      dueGrouped.putIfAbsent(group, () => item);
    }
    for (final item in dueGrouped.entries) {
      final record = item.value;
      final courseName = (record['course_name'] ?? '').toString();
      final topic = (record['topic'] ?? '').toString();
      add('due::${item.key}', 'Review due questions: ${courseName.isEmpty ? topic : courseName}', 'due', 86,
        refId: item.key, courseId: (record['course_id'] ?? '').toString(),
        courseName: courseName, courseCode: (record['course_code'] ?? '').toString());
    }

    for (final lecture in LectureStorage.getLectures()) {
      final offset = (lecture.day - day.weekday + 7) % 7;
      if (offset > 2) continue;
      final course = CourseStorage.getCourses().where((item) => item.id == lecture.courseId);
      final name = course.isNotEmpty ? course.first.title : lecture.manualCourseTitle;
      final code = course.isNotEmpty ? course.first.code : lecture.manualCourseCode;
      if (name.trim().isEmpty && code.trim().isEmpty) continue;
      add('lecture::${lecture.id}', 'Prepare for ${name.isEmpty ? code : name}', 'study', 40 - offset * 8,
        courseId: lecture.courseId, courseName: name, courseCode: code, refId: lecture.id);
    }

    for (final record in StudySessionStorage.all().take(6)) {
      final topic = (record['topic'] ?? '').toString();
      if (topic.isEmpty) continue;
      final dateText = (record['finished_at'] ?? '').toString();
      final finished = DateTime.tryParse(dateText)?.toLocal();
      if (finished == null || finished.isBefore(day.subtract(const Duration(days: 7)))) continue;
      add('study::${record['id']}', 'Revisit $topic', 'study', 30,
        courseId: (record['course_id'] ?? '').toString(),
        courseName: (record['course_name'] ?? '').toString(),
        courseCode: (record['course_code'] ?? '').toString());
    }

    for (final course in CourseStorage.getCourses()) {
      add('explore::${course.id}', 'Explore ${course.title}', 'study', 10,
        courseId: course.id, courseName: course.title, courseCode: course.code);
    }
    return AcademicMissionPlanner.select(candidates);
  }

  static Future<List<Map<String, dynamic>>> ensureToday() => ensureForDate(DateTime.now());

  static Future<List<Map<String, dynamic>>> ensureForDate(DateTime date) async {
    final key = _key(dayKey(date));
    final old = _read(dayKey(date));
    if (old.isNotEmpty && old.any((item) => item['version'] != 2)) {
      // Archive without deleting original records or their completion evidence.
      final archiveKey = AccountScope.key('legacy_missions::${dayKey(date)}');
      if (!_db.containsKey(archiveKey)) await _db.put(archiveKey, old);
    }
    final latest = suggestionsFor(date);
    final previous = {for (final item in old.where((m) => m['version'] == 2)) item['id'].toString(): item};
    final completed = <Map<String, dynamic>>[];
    for (final item in old.where((m) => m['version'] == 2 && m['done'] == true)) {
      if (!completed.any((m) => m['id'] == item['id'])) completed.add(Map<String, dynamic>.from(item));
    }
    final result = <Map<String, dynamic>>[...completed];
    for (final candidate in latest) {
      if (result.any((item) => item['id'] == candidate['id'])) continue;
      final original = previous[candidate['id']];
      if (original != null) {
        candidate['done'] = original['done'] == true;
        candidate['minutes'] = original['minutes'] ?? 0;
      }
      result.add(candidate);
      if (result.length >= 3) break;
    }
    final selection = result.take(3).toList();
    await _db.put(key, selection);
    return selection;
  }

  static Future<void> setCompleted(String id, bool done) async {
    final missions = await ensureToday();
    final index = missions.indexWhere((record) => record['id'] == id);
    if (index < 0) return;
    missions[index]['done'] = done;
    missions[index]['updated_at'] = DateTime.now().toUtc().toIso8601String();
    await _db.put(_key(dayKey()), missions);
  }

  static Future<void> recordFocus(String id, int minutes) async {
    if (minutes <= 0) return;
    final missions = await ensureToday();
    final index = missions.indexWhere((record) => record['id'] == id);
    if (index < 0) return;
    final previous = (missions[index]['minutes'] as num?)?.toInt() ?? 0;
    missions[index]['minutes'] = previous + minutes;
    // Time alone never means the student has understood or completed a topic.
    await _db.put(_key(dayKey()), missions);
  }

  /// Only saved academic work qualifies, not logins, page visits, or a checkmark.
  /// Use local calendar dates (not a rolling 24-hour interval).
  static Set<String> learningDays() {
    final days = <String>{};
    void addTimestamp(Object? raw) {
      final date = DateTime.tryParse(raw?.toString() ?? '')?.toLocal();
      if (date != null) {
        days.add(dayKey(date));
      }
    }
    for (final session in StudySessionStorage.all()) {
      final legacyActivity = !session.containsKey('has_learning_work') &&
          (session['topic'] ?? '').toString().trim().isNotEmpty &&
          (session['topic'] ?? '').toString() != 'Untitled topic';
      if (session['has_learning_work'] == true || legacyActivity ||
          (session['timed_minutes'] as num? ?? 0) > 0) {
        addTimestamp(session['finished_at']);
      }
    }
    for (final answer in RecallStorage.all()) {
      addTimestamp(answer['created_at']);
    }
    for (final note in LessonNotesStorage.all()) {
      if ((note['text'] ?? '').toString().trim().length >= 20) {
        addTimestamp(note['meaningful_updated_at'] ?? note['updated_at']);
      }
    }
    for (final task in AcademicTaskStorage.all()) {
      if (task['done'] == true) {
        addTimestamp(task['completed_at']);
      }
    }
    return days;
  }

  /// One grace day can bridge a missed calendar day, but never adds a
  /// fabricated learning day to the count. A second gap ends the run.
  static int streakFromDays(Set<String> activityDays, DateTime now) {
    var cursor = DateTime(now.year, now.month, now.day);
    var earned = 0;
    var graceUsed = false;
    for (var index = 0; index < 366; index++) {
      if (activityDays.contains(dayKey(cursor))) {
        earned++;
      } else if (!graceUsed) {
        graceUsed = true;
      } else {
        break;
      }
      cursor = DateTime(cursor.year, cursor.month, cursor.day - 1);
    }
    return earned;
  }

  static int streak({DateTime? now}) => streakFromDays(learningDays(), now ?? DateTime.now());

  static bool learnedToday({DateTime? now}) => learningDays().contains(dayKey(now));

  /// Only previously saved missions count. Do not invent historical goals.
  static CampusPulseSnapshot localPulse(int period, {DateTime? now}) {
    final today = now ?? DateTime.now();
    DateTime start;
    if (period == 0) {
      start = DateTime(today.year, today.month, today.day);
    } else if (period == 1) {
      start = DateTime(today.year, today.month, today.day - (today.weekday - 1));
    } else {
      start = DateTime(today.year, today.month, 1);
    }
    final records = <List<Map<String, dynamic>>>[];
    for (var day = start; !day.isAfter(today); day = DateTime(day.year, day.month, day.day + 1)) {
      records.add(_read(dayKey(day)));
    }
    return AcademicProgressEngine.calculate(records);
  }

  /// Only previously saved dates are uploaded. No historical missions invented.
  /// Empty dates in a rolling window are supplied by the server as zero progress
  /// for subscribers; the client never creates a fabricated completion.
  static List<Map<String, dynamic>> progressDays({DateTime? now}) {
    final today = now ?? DateTime.now();
    final monthStart = DateTime(today.year, today.month, 1);
    final weekStart = DateTime(today.year, today.month, today.day - today.weekday + 1);
    final start = monthStart.isBefore(weekStart) ? monthStart : weekStart;
    final days = <Map<String, dynamic>>[];
    for (var day = start; !day.isAfter(today); day = DateTime(day.year, day.month, day.day + 1)) {
      final date = dayKey(day);
      final saved = _read(date);
      if (saved.isNotEmpty) days.add(AcademicProgressEngine.uploadDay(date, saved));
    }
    return days;
  }
}
