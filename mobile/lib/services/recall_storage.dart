import 'package:hive_ce_flutter/hive_flutter.dart';
import 'account_scope.dart';

/// Account-isolated, offline recall and revision records.
/// Existing keys and fields remain compatible; new metadata is additive.
class RecallStorage {
  RecallStorage._();

  static const boxName = 'campus_recall_v1';
  static Box<dynamic>? _box;

  static Future<void> initialize() async {
    _box ??= await Hive.openBox<dynamic>(boxName);
  }

  static Box<dynamic> get _db {
    final box = _box;
    if (box == null || !box.isOpen) {
      throw StateError('Recall storage not initialized');
    }
    return box;
  }

  static String _key(String id) => AccountScope.key('recall::$id');

  static List<Map<String, dynamic>> all() {
    final results = <Map<String, dynamic>>[];
    for (final key in _db.keys) {
      if (!AccountScope.owns(key) || !key.toString().contains('::recall::')) {
        continue;
      }
      final value = _db.get(key);
      if (value is Map) results.add(Map<String, dynamic>.from(value));
    }
    results.sort((a, b) =>
        (b['created_at'] as String? ?? '').compareTo(a['created_at'] as String? ?? ''));
    return results;
  }

  static List<Map<String, dynamic>> due([DateTime? at]) {
    final today = (at ?? DateTime.now()).toUtc();
    return all().where((record) {
      final date = DateTime.tryParse(record['next_review_at'] as String? ?? '');
      return date != null && !date.isAfter(today);
    }).toList();
  }

  static int intervalDays(String rating) {
    switch (rating) {
      case 'Again':
        return 1;
      case 'Hard':
        return 2;
      case 'Good':
        return 4;
      case 'Easy':
        return 7;
      default:
        throw ArgumentError.value(rating, 'rating');
    }
  }

  static Future<void> save({
    required String missionId,
    required String topic,
    required String question,
    required String answer,
    required String rating,
    String referenceAnswer = '',
    String source = '',
    String questionType = '',
    List<String> keyConcepts = const [],
    List<String> acceptedAnswers = const [],
    String? recordId,
    String courseId = '',
    String courseName = '',
    String courseCode = '',
  }) async {
    if (question.trim().isEmpty) {
      throw ArgumentError('A question is required');
    }
    if (answer.trim().isEmpty && rating != 'Again') {
      throw ArgumentError('Enter an answer, or choose Again if you could not recall it');
    }
    final interval = intervalDays(rating);
    final now = DateTime.now().toUtc();
    final id = recordId?.trim().isNotEmpty == true
        ? recordId!.trim()
        : '${now.microsecondsSinceEpoch}';
    await _db.put(_key(id), <String, dynamic>{
      'id': id,
      'mission_id': missionId,
      'topic': topic.trim(),
      'course_id': courseId,
      'course_name': courseName,
      'course_code': courseCode,
      'question': question.trim(),
      'answer': answer.trim(),
      'rating': rating,
      'reference_answer': referenceAnswer,
      'source': source,
      'question_type': questionType,
      'key_concepts': keyConcepts,
      'accepted_answers': acceptedAnswers,
      'created_at': now.toIso8601String(),
      'next_review_at': now.add(Duration(days: interval)).toIso8601String(),
    });
  }

  static Future<void> reschedule(String id, String rating) async {
    final interval = intervalDays(rating);
    final key = _key(id);
    final raw = _db.get(key);
    if (raw is! Map) throw StateError('Recall record not found');
    final record = Map<String, dynamic>.from(raw);
    record['rating'] = rating;
    record['next_review_at'] = DateTime.now()
        .toUtc()
        .add(Duration(days: interval))
        .toIso8601String();
    await _db.put(key, record);
  }
}
