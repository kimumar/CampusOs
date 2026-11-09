import 'dart:async';
import 'profile_storage.dart';
import 'auth_api.dart';
import 'course_storage.dart';
import 'lecture_storage.dart';
import '../models/campus_course.dart';
import '../models/lecture_session.dart';

class CloudSync {
  CloudSync._();

  static Timer? _debounce;
  static Timer? _retry;
  static Future<void>? _inFlight;
  static void start() {
    _retry ??= Timer.periodic(const Duration(seconds: 30), (_) => queueSync());
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
  static Future<void> _synchronizeInternal() async {
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
    final records = <Map<String,dynamic>>[
      for (final c in courses.values) {'kind':'course','id':c.id,'payload':c.toMap()},
      for (final l in lectures.values) {'kind':'lecture','id':l.id,'payload':l.toMap()},
    ];
    // Upload local changes in bounded batches, including deletion tombstones.
    for (var i=0; i<records.length; i+=100) {
      final end = i+100 < records.length ? i+100 : records.length;
      await AuthApi.syncRecords(records.sublist(i,end));
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
        }
      } catch (_) { /* Preserve unreadable local and remote data. */ }
    }
  }
}


