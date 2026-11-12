import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

import 'academic_task_storage.dart';
import 'auth_api.dart';
import 'lecture_storage.dart';
import 'profile_storage.dart';

/// Opt-in Android alarms. Works without connectivity after scheduling.
/// Never schedules academic details after the verified offline window expires.
class AcademicNotifications {
  AcademicNotifications._();
  static const _channel = MethodChannel('campusos/reminders');
  static Box<dynamic>? _prefs;

  static Future<void> initialize() async {
    _prefs ??= await Hive.openBox<dynamic>('campus_notification_preferences_v1');
  }

  static bool get enabled => _prefs?.get('enabled', defaultValue: false) == true;

  static Future<void> setEnabled(bool value) async {
    await _prefs?.put('enabled', value);
    if (!value) {
      await cancel();
    } else {
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        final granted = await _channel.invokeMethod<bool>('requestPermission') ?? false;
        if (!granted) { await _prefs?.put('enabled', false); return; }
      }
      await reschedule();
    }
  }

  static Future<bool> permissionGranted() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return false;
    try { return await _channel.invokeMethod<bool>('permissionStatus') ?? false; }
    on PlatformException { return false; }
    on MissingPluginException { return false; }
  }

  static Future<List<Map<String, dynamic>>> recentDelivered() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return [];
    try {
      final data = await _channel.invokeMethod<List<dynamic>>('recentDelivered');
      return (data ?? []).whereType<Map>().map((e) => Map<String,dynamic>.from(e)).take(3).toList();
    } on PlatformException { return []; }
      on MissingPluginException { return []; }
  }

  static Future<void> clearHistory() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try { await _channel.invokeMethod<void>('clearHistory'); }
    on PlatformException { /* No history on unsupported device. */ }
    on MissingPluginException { /* No Android platform implementation. */ }
  }

  static int _stableId(String input) {
    var hash = 2166136261;
    for (final unit in input.codeUnits) {
      hash = ((hash ^ unit) * 16777619) & 0x7fffffff;
    }
    return hash;
  }

  static bool _suitable(DateTime at, DateTime now, DateTime accessUntil) =>
      at.isAfter(now) && at.isBefore(accessUntil) && at.hour >= 7 && at.hour < 22;

  static Future<void> reschedule() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android || !enabled) return;
    final account = AuthApi.account;
    final now = DateTime.now();
    final accessUntil = AuthApi.offlineAccessUntil;
    if (account == null || accessUntil == null || !accessUntil.isAfter(now) ||
        !AuthApi.hasUsableAccess) {
      await cancel();
      return;
    }
    final name = ProfileStorage.load().name.trim().split(' ').first;
    final greeting = name.isEmpty ? 'scholar' : name;
    final records = <Map<String, Object>>[];
    void add(String key, DateTime at, String title, String body) {
      if (!_suitable(at, now, accessUntil)) return;
      records.add({'id': _stableId(key), 'epochMillis': at.millisecondsSinceEpoch,
        'title': title, 'body': body});
    }

    final days = accessUntil.difference(now).inDays + 2;
    for (var offset = 0; offset < days && offset < 3; offset++) {
      final day = DateTime(now.year, now.month, now.day + offset);
      final morning = DateTime(day.year, day.month, day.day, 8, 0);
      add('hello:${day.toIso8601String()}', morning, 'Good morning, $greeting! 💜',
          'Your CampusOS study plan is waiting whenever you are ready.');
      for (final lecture in LectureStorage.getLectures()) {
        if (lecture.day != day.weekday) continue;
        final start = DateTime(day.year, day.month, day.day)
            .add(Duration(minutes: lecture.startMinute - 30));
        add('lecture:${lecture.id}:${day.toIso8601String()}', start,
          'Lecture reminder 🎓', 'Your scheduled lecture begins in 30 minutes.');
      }
    }
    for (final task in AcademicTaskStorage.all(includeDone: false)) {
      final due = DateTime.tryParse((task['due_at'] ?? '').toString())?.toLocal();
      if (due == null) continue;
      final before = DateTime(due.year, due.month, due.day - 1, 18);
      add('deadline:${task['id']}', before, 'Upcoming academic deadline 💜',
          'Your ${task['title']} is due tomorrow. A little progress today helps.');
    }
    // Only one pleasant access reminder is queued. Refreshing the entitlement
    // replaces this schedule, so active returning students stop receiving it.
    final accountExpiry = [account['trial_ends_at'], account['paid_until']]
      .map((value) => DateTime.tryParse((value ?? '').toString())?.toLocal())
      .whereType<DateTime>().toList();
    final paidOrTrialEnd = accountExpiry.isEmpty ? accessUntil
        : accountExpiry.reduce((a, b) => a.isAfter(b) ? a : b);
    final renewalNeeded = !paidOrTrialEnd.isAfter(accessUntil);
    var reminderAt = accessUntil.add(const Duration(minutes: 15));
    if (reminderAt.hour < 9 || reminderAt.hour >= 21) {
      reminderAt = DateTime(reminderAt.year, reminderAt.month,
        reminderAt.hour >= 21 ? reminderAt.day + 1 : reminderAt.day, 9);
    }
    if (reminderAt.isAfter(now)) {
      records.add({'id': _stableId('access-reminder'),
        'epochMillis': reminderAt.millisecondsSinceEpoch,
        'title': renewalNeeded ? 'Your study journey is waiting 💜' : 'Reconnect to CampusOS 💜',
        'body': renewalNeeded
          ? '$greeting, your saved academic work is safe. Renew when you are ready to continue.'
          : '$greeting, reconnect to verify your subscription and continue your studies.'});
    }
    try {
      await _channel.invokeMethod<void>('replaceSchedule', records);
    } on PlatformException catch (error) {
      debugPrint('Reminder scheduling unavailable: ${error.code}');
    } on MissingPluginException {
      debugPrint('Local reminders are unavailable on this platform.');
    }
  }

  static Future<void> cancel() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try { await _channel.invokeMethod<void>('cancelAll'); }
    on PlatformException catch (error) { debugPrint('Reminder cancel failed: ${error.code}'); }
    on MissingPluginException { debugPrint('Local reminders are unavailable on this platform.'); }
  }
}
