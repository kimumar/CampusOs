import 'package:hive_ce_flutter/hive_flutter.dart';
import 'account_scope.dart';

/// An account-scoped consistency measure, deliberately separate from learning.
/// Opening CampusOS counts as checking in; no daily study requirement.
class CheckInStorage {
  CheckInStorage._();
  static const boxName = 'campus_check_ins_v1';
  static Box<dynamic>? _box;

  static Future<void> initialize() async {
    _box ??= await Hive.openBox<dynamic>(boxName);
  }

  static String dayKey(DateTime day) =>
      '${day.year.toString().padLeft(4, '0')}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';

  static String get _key => AccountScope.key('check_in_days');

  static Set<String> days() {
    final raw = _box?.get(_key);
    return raw is List ? raw.whereType<String>().toSet() : <String>{};
  }

  static Future<void> recordCheckIn({DateTime? now}) async {
    final box = _box;
    if (box == null || !box.isOpen) return;
    final today = dayKey(now ?? DateTime.now());
    final recorded = days();
    if (recorded.add(today)) await box.put(_key, recorded.toList()..sort());
  }

  /// One missed calendar day may bridge a streak; it never adds an earned day.
  static int streakFromDays(Set<String> checkIns, DateTime now) {
    var cursor = DateTime(now.year, now.month, now.day);
    var earned = 0;
    var graceUsed = false;
    for (var i = 0; i < 366; i++) {
      if (checkIns.contains(dayKey(cursor))) {
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

  static int streak({DateTime? now}) => streakFromDays(days(), now ?? DateTime.now());
  static bool checkedInToday({DateTime? now}) => days().contains(dayKey(now ?? DateTime.now()));
}
