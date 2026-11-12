import 'package:flutter_test/flutter_test.dart';
import 'package:campusos_mobile/services/campus_pulse_calculator.dart';

void main() {
  test('zero goals does not imply a zero-achievement participant', () {
    final snapshot = CampusPulseSnapshot.fromSavedDays([<Map<String,dynamic>>[]]);
    expect(snapshot.hasGoals, false);
    expect(snapshot.reached50, false);
  });
  test('counts historical saved missions without inventing participation', () {
    final snapshot = CampusPulseSnapshot.fromSavedDays([
      [{'done':true},{'done':false},{'done':true}],
      [{'done':true}],
    ]);
    expect(snapshot.assigned, 4);
    expect(snapshot.completed, 3);
    expect(snapshot.daysWithGoals, 2);
    expect(snapshot.percentage, 75);
    expect(snapshot.reached50, true);
    expect(snapshot.reached90, false);
  });
}
