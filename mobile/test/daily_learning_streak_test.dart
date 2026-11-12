import 'package:flutter_test/flutter_test.dart';
import 'package:campusos_mobile/services/study_mission_storage.dart';

void main() {
  final today = DateTime(2026, 11, 10, 12);
  test('logging in without activity earns no streak', () {
    expect(StudyMissionStorage.streakFromDays(<String>{}, today), 0);
  });
  test('one genuine activity earns one day, not multiple', () {
    expect(StudyMissionStorage.streakFromDays({'2026-11-10'}, today), 1);
  });
  test('continuous learning days count normally', () {
    expect(StudyMissionStorage.streakFromDays({'2026-11-10','2026-11-09','2026-11-08'}, today), 3);
  });
  test('single missed day does not erase earlier learning', () {
    expect(StudyMissionStorage.streakFromDays({'2026-11-10','2026-11-08'}, today), 2);
  });
  test('grace day does not fabricate a study day', () {
    expect(StudyMissionStorage.streakFromDays({'2026-11-09','2026-11-08'}, today), 2);
  });
  test('two missed days stop the run', () {
    expect(StudyMissionStorage.streakFromDays({'2026-11-10','2026-11-07'}, today), 1);
  });
  test('date changes at local midnight', () {
    expect(StudyMissionStorage.dayKey(DateTime(2026,11,10,23,59)), '2026-11-10');
    expect(StudyMissionStorage.dayKey(DateTime(2026,11,11,0,0)), '2026-11-11');
  });
  test('year rollover is based on the calendar', () {
    expect(StudyMissionStorage.dayKey(DateTime(2027,1,1)), '2027-01-01');
    expect(StudyMissionStorage.streakFromDays({'2027-01-01','2026-12-31'}, DateTime(2027,1,1)), 2);
  });
}
