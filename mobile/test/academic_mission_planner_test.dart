import 'package:flutter_test/flutter_test.dart';
import 'package:campusos_mobile/services/academic_mission_planner.dart';
import 'package:campusos_mobile/services/grade_calculator.dart';

void main() {
  test('urgency is driven by genuine deadlines', () {
    final today = DateTime(2026, 11, 10);
    expect(AcademicMissionPlanner.urgency(today, today), 95);
    expect(AcademicMissionPlanner.urgency(today.add(const Duration(days: 2)), today), 75);
    expect(AcademicMissionPlanner.urgency(today.add(const Duration(days: 21)), today), 0);
  });
  test('mission selection is unique and prioritised', () {
    final result = AcademicMissionPlanner.select([
      {'id': 'a', 'priority': 1},
      {'id': 'b', 'priority': 20},
      {'id': 'b', 'priority': 30},
      {'id': 'c', 'priority': 9},
    ], max: 2);
    expect(result.map((e) => e['id']).toList(), ['b', 'c']);
  });
  test('CGPA is unit-weighted, not course-count weighted', () {
    expect(GradeCalculator.weightedAverage([(3, 5), (1, 3)]), 4.5);
    expect(GradeCalculator.projectedCgpa(previousCgpa: 4, previousUnits: 10, currentUnits: 4, currentGradePoints: 18), closeTo(58 / 14, 0.00001));
  });
}
