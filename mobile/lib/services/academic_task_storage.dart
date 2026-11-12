import 'package:hive_ce_flutter/hive_flutter.dart';
import 'account_scope.dart';

/// Offline task and exam records, isolated to the authenticated account.
/// New records use stable IDs; deleting a task retains a tombstone.
class AcademicTaskStorage {
  AcademicTaskStorage._();
  static const boxName = 'campus_academic_tasks_v1';
  static Box<dynamic>? _box;

  static Future<void> initialize() async {
    if (_box == null || !_box!.isOpen) {
      _box = await Hive.openBox<dynamic>(boxName);
    }
  }

  static Box<dynamic> get _db {
    final box = _box;
    if (box == null || !box.isOpen) {
      throw StateError('Academic tasks storage not initialized');
    }
    return box;
  }

  static String _key(String id) => AccountScope.key('academic_task::$id');

  static List<Map<String, dynamic>> all({bool includeDone = true}) {
    final records = <Map<String, dynamic>>[];
    for (final key in _db.keys) {
      if (!AccountScope.owns(key) || !key.toString().contains('::academic_task::')) continue;
      final raw = _db.get(key);
      if (raw is! Map) continue;
      final item = Map<String, dynamic>.from(raw);
      if (item['deleted'] == true || (!includeDone && item['done'] == true)) continue;
      records.add(item);
    }
    records.sort((a, b) => (a['due_at'] ?? '').toString().compareTo((b['due_at'] ?? '').toString()));
    return records;
  }

  static Future<String> save({
    String? id,
    required String title,
    required String kind,
    required DateTime dueAt,
    String courseId = '',
    String courseName = '',
    String courseCode = '',
    String details = '',
  }) async {
    if (title.trim().isEmpty) throw ArgumentError('Task title is required');
    if (!{'assignment', 'exam', 'test'}.contains(kind)) throw ArgumentError('Invalid task type');
    final now = DateTime.now().toUtc();
    final uid = (id != null && id.isNotEmpty) ? id : '${now.microsecondsSinceEpoch}_${title.hashCode.abs()}';
    final prior = _db.get(_key(uid));
    await _db.put(_key(uid), <String, dynamic>{
      'id': uid,
      'title': title.trim(),
      'kind': kind,
      'due_at': dueAt.toUtc().toIso8601String(),
      'course_id': courseId,
      'course_name': courseName,
      'course_code': courseCode,
      'details': details.trim(),
      'done': prior is Map && prior['done'] == true,
      'completed_at': prior is Map ? (prior['completed_at'] ?? '') : '',
      'deleted': false,
      'created_at': prior is Map ? (prior['created_at'] ?? now.toIso8601String()) : now.toIso8601String(),
      'updated_at': now.toIso8601String(),
    });
    return uid;
  }

  static Future<void> setCompleted(String id, bool done) async {
    final raw = _db.get(_key(id));
    if (raw is! Map) return;
    final item = Map<String, dynamic>.from(raw);
    item['done'] = done;
    item['completed_at'] = done ? DateTime.now().toUtc().toIso8601String() : '';
    item['updated_at'] = DateTime.now().toUtc().toIso8601String();
    await _db.put(_key(id), item);
  }

  static Future<void> archive(String id) async {
    final raw = _db.get(_key(id));
    if (raw is! Map) return;
    final item = Map<String, dynamic>.from(raw);
    item['deleted'] = true;
    item['updated_at'] = DateTime.now().toUtc().toIso8601String();
    await _db.put(_key(id), item);
  }
}
