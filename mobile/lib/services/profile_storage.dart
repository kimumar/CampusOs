import 'cloud_sync.dart';
import 'account_scope.dart';
import 'dart:typed_data';
import 'package:hive_ce_flutter/hive_flutter.dart';

class StudentProfile {
  const StudentProfile({this.name = '', this.institutionType = '', this.institution = '', this.department = '', this.level = '', this.photo});
  final String name;
  final String institutionType;
  final String institution;
  final String department;
  final String level;
  final Uint8List? photo;
  bool get complete => institution.trim().isNotEmpty && department.trim().isNotEmpty && level.trim().isNotEmpty;
}

class ProfileStorage {
  ProfileStorage._();
  static Box<dynamic>? _box;
  static Future<void> initialize() async {
    _box = await Hive.openBox<dynamic>('campus_profile_v1');
  }
  static Box<dynamic> get _db {
    final box = _box;
    if (box == null || !box.isOpen) throw StateError('Profile storage is not initialized');
    return box;
  }
  static StudentProfile load() {
    final raw = _db.get(AccountScope.key('student'));
    if (raw is! Map) return const StudentProfile();
    final photo = raw['photo'];
    return StudentProfile(
      name: (raw['name'] ?? '').toString(),
      institutionType: (raw['institutionType'] ?? '').toString(),
      institution: (raw['institution'] ?? '').toString(),
      department: (raw['department'] ?? '').toString(),
      level: (raw['level'] ?? '').toString(),
      photo: photo is Uint8List ? photo : photo is List ? Uint8List.fromList(photo.cast<int>()) : null,
    );
  }
  static bool get cloudPending => _db.get(AccountScope.key('profile_cloud_pending'), defaultValue: false) == true;
  static Future<void> markCloudSynced() => _db.put(AccountScope.key('profile_cloud_pending'), false);
  static Future<void> save(StudentProfile profile, {bool fromCloud = false}) async {
    await _db.put(AccountScope.key('student'), {
      'name': profile.name, 'institutionType': profile.institutionType, 'institution': profile.institution,
      'department': profile.department, 'level': profile.level, 'photo': profile.photo,
    });
    if (!fromCloud) {
      await _db.put(AccountScope.key('profile_cloud_pending'), true);
      CloudSync.queueSync();
    }
  }
}
