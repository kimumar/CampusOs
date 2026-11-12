import 'package:flutter_test/flutter_test.dart';
import 'package:campusos_mobile/services/community_pulse.dart';
import 'package:campusos_mobile/services/academic_progress_engine.dart';

void main() {
  test('accepts server-wide percentages and does not expose student counts', () {
    final result = CommunityPulse.fromJson({
      'period': 'today', 'percent_100': 60, 'percent_90': 75,
      'percent_50': 90, 'as_of': '2026-11-10T12:00:00Z',
    }, 'today');
    expect(result.percent100, 60);
    expect(result.percent90, 75);
    expect(result.percent50, 90);
  });

  test('rejects impossible community percentages', () {
    expect(() => CommunityPulse.fromJson({
      'period': 'today', 'percent_100': 95, 'percent_90': 40,
      'percent_50': 60, 'as_of': '2026-11-10T12:00:00Z',
    }, 'today'), throwsFormatException);
  });

  test('shared dashboard calculation and upload agree', () {
    final missions = <Map<String,dynamic>>[
      {'id': '1', 'done': true},
      {'id': '2', 'done': true},
      {'id': '3', 'done': false},
    ];
    final snapshot = AcademicProgressEngine.calculate([missions]);
    final upload = AcademicProgressEngine.uploadDay('2026-11-10', missions);
    expect(snapshot.percentage, 67);
    expect(upload['assigned'], snapshot.assigned);
    expect(upload['completed'], snapshot.completed);
  });

  test('no goals is zero rather than completion', () {
    final snapshot = AcademicProgressEngine.calculate([<Map<String,dynamic>>[]]);
    expect(snapshot.fraction, 0);
    expect(snapshot.reached100, false);
  });
}
