import 'dart:async';
import 'dart:convert';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'account_scope.dart';
import 'profile_storage.dart';
import 'auth_api.dart';
import 'course_storage.dart';
import 'lecture_storage.dart';
import '../models/campus_course.dart';
import '../models/lecture_session.dart';
import 'study_mission_storage.dart';
import 'lesson_notes_storage.dart';
import 'recall_session_storage.dart';

class CloudSync {
  CloudSync._();

  static Timer? _debounce;
  static Timer? _retry;
  static Future<void>? _inFlight;
  static void start() {
    // Avoid needless network traffic at scale; edits still queue near-immediate sync.
    _retry ??= Timer.periodic(const Duration(minutes: 30), (_) => queueSync());
    queueSync();
  }
  static void stop() {
    _retry?.cancel(); _retry = null;
    _debounce?.cancel(); _debounce = null;
  }
  static void queueSync() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 2), () {
      if (AuthApi.account == null) return;
      synchronize().catchError((Object _) { /* Local data stays pending. */ });
    });
  }
  static Future<void> synchronize() {
    if (AuthApi.account == null) return Future.value();
    if (_inFlight != null) return _inFlight!;
    final task = _synchronizeInternal();
    _inFlight = task;
    return task.whenComplete(() { _inFlight = null; });
  }
  // Compact per-account fingerprints avoid uploading the same unchanged note
  // and timetable on every sync. The server remains timestamp authoritative.
  static String _fingerprint(Map<String, dynamic> record) {
    final data = utf8.encode(jsonEncode(record));
    var a = 2166136261;
    var b = 5381;
    for (final byte in data) {
      a = ((a ^ byte) * 16777619) & 0xffffffff;
      b = ((b * 33) ^ byte) & 0xffffffff;
    }
    return '${a.toRadixString(16)}:${b.toRadixString(16)}:${data.length}';
  }

  static Future<void> _synchronizeInternal() async {
    // Idempotent daily snapshots, keyed by authenticated user and date on the
    // server. Upload before reading community results; failed uploads remain
    // in existing local Hive storage for the next retry.
    // Every academically eligible student contributes aggregate progress.
    // Pulse contains completion totals only, never notes or student names.
    final progress = AuthApi.hasUsableAccess
        ? StudyMissionStorage.progressDays() : <Map<String, dynamic>>[];
    try {
      for (var i = 0; i < progress.length; i += 30) {
        final end = i + 30 < progress.length ? i + 30 : progress.length;
        await AuthApi.uploadAcademicProgress(progress.sublist(i, end));
      }
    } catch (_) {
      // Older servers may not yet expose the new progress endpoint. Do not
      // disrupt previously working courses/profile/timetable synchronization.
      // The locally saved mission snapshots remain available for future sync.
    }
    if (ProfileStorage.cloudPending) {
      final profile = ProfileStorage.load();
      await AuthApi.saveProfile({'preferred_name': profile.name,
        'institution': profile.institution, 'department': profile.department,
        'level': profile.level});
      await ProfileStorage.markCloudSynced();
    } else {
      final local = ProfileStorage.load();
      if (!local.complete) {
        final remote = await AuthApi.fetchProfile();
        if ((remote['institution'] ?? '').toString().trim().isNotEmpty) {
          await ProfileStorage.save(StudentProfile(
            name: (remote['preferred_name'] ?? '').toString(),
            institution: (remote['institution'] ?? '').toString(),
            department: (remote['department'] ?? '').toString(),
            level: (remote['level'] ?? '').toString(), photo: local.photo), fromCloud: true);
        }
      }
    }

    // Profile is only uploaded automatically when the remote fields are empty.
    // Existing nonempty remote profile data is never overwritten on login.
    final localProfile = ProfileStorage.load();
    final remoteProfile = await AuthApi.fetchProfile();
    final remoteInstitution = (remoteProfile['institution'] ?? '').toString().trim();
    if (localProfile.complete && remoteInstitution.isEmpty) {
      await AuthApi.saveProfile({'preferred_name': localProfile.name,
        'institution': localProfile.institution, 'department': localProfile.department,
        'level': localProfile.level});
    } else if (!localProfile.complete && remoteInstitution.isNotEmpty) {
      await ProfileStorage.save(StudentProfile(
        name: (remoteProfile['preferred_name'] ?? '').toString(),
        institution: remoteInstitution,
        department: (remoteProfile['department'] ?? '').toString(),
        level: (remoteProfile['level'] ?? '').toString(), photo: localProfile.photo));
    }

    final courses = {for (final c in CourseStorage.allForSync()) c.id: c};
    final lectures = {for (final l in LectureStorage.allForSync()) l.id: l};
    final notes = LessonNotesStorage.all();
    final recalls = RecallSessionStorage.allForSync();
    final records = <Map<String,dynamic>>[
      for (final c in courses.values) {'kind':'course','id':c.id,'payload':c.toMap()},
      for (final l in lectures.values) {'kind':'lecture','id':l.id,'payload':l.toMap()},
      for (final n in notes) {'kind':'lesson_note','id':n['id'],'payload':n},
      for (final r in recalls) {'kind':'recall_session','id':r['session_id'],
        'payload': {...r, 'id': r['session_id']}},
    ];
    // The cache is scoped by account, not by device alone. Persist each
    // fingerprint *after* its upload completes. An interrupted upload is retried.
    final syncMarks = await Hive.openBox<dynamic>('campus_sync_marks_015');
    final pending = <Map<String,dynamic>>[];
    final keys = <String>[];
    final hashes = <String>[];
    for (final record in records) {
      // Never transfer original images or PDFs; preserve the local record.
      final content = jsonEncode(record).toLowerCase();
      if (content.contains('data:image/') || content.contains('data:application/pdf;') ||
          content.contains('"image_bytes"') || content.contains('"pdf_bytes"') ||
          content.contains('"file_data"') || content.contains('"attachment"')) {
        continue;
      }
      final key = AccountScope.key('sync015::${record['kind']}::${record['id']}');
      final fingerprint = _fingerprint(record);
      if (syncMarks.get(key) == fingerprint) continue;
      pending.add(record);
      keys.add(key);
      hashes.add(fingerprint);
    }
    // Upload only changed records in bounded batches, including tombstones.
    for (var i=0; i<pending.length; i+=100) {
      final end = i+100 < pending.length ? i+100 : pending.length;
      await AuthApi.syncRecords(pending.sublist(i,end));
      for (var j=i; j<end; j++) {
        await syncMarks.put(keys[j], hashes[j]);
      }
    }
    // Always retrieve the full server state, including when local storage is empty.
    final remote = await AuthApi.syncRecords([]);
    for (final item in remote) {
      if (item is! Map) continue;
      final kind = item['kind'];
      final payload = item['payload'];
      if (payload is! Map) continue;
      final data = Map<String,dynamic>.from(payload);
      try {
        if (kind == 'course') {
          final value = CampusCourse.fromMap(data);
          final local = courses[value.id];
          if (local == null || value.updatedAt.isAfter(local.updatedAt)) await CourseStorage.saveCourse(value);
        } else if (kind == 'lecture') {
          final value = LectureSession.fromMap(data);
          final local = lectures[value.id];
          if (local == null || value.updatedAt.isAfter(local.updatedAt)) await LectureStorage.saveLecture(value);
        } else if (kind == 'lesson_note') {
          await LessonNotesStorage.mergeFromCloud(data);
        } else if (kind == 'recall_session') {
          await RecallSessionStorage.mergeFromCloud(data);
        }
      } catch (_) { /* Preserve unreadable local and remote data. */ }
    }
  }
}


