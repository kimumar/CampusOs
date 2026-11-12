/// Pure weighted-grade calculations. Results are projections, not real grades.
class GradeCalculator {
  GradeCalculator._();
  static const fivePoint = <String, int>{'A': 5, 'B': 4, 'C': 3, 'D': 2, 'E': 1, 'F': 0};
  static const fourPoint = <String, int>{'A': 4, 'B': 3, 'C': 2, 'D': 1, 'F': 0};

  static double? weightedAverage(Iterable<(int, int)> entries) {
    var units = 0;
    var points = 0;
    for (final entry in entries) {
      if (entry.$1 <= 0 || entry.$2 < 0) continue;
      units += entry.$1;
      points += entry.$1 * entry.$2;
    }
    return units == 0 ? null : points / units;
  }

  static double? projectedCgpa({
    required double previousCgpa,
    required int previousUnits,
    required int currentUnits,
    required double currentGradePoints,
  }) {
    if (previousUnits < 0 || currentUnits < 0 || previousCgpa < 0 || currentGradePoints < 0) return null;
    final total = previousUnits + currentUnits;
    return total == 0 ? null : (previousCgpa * previousUnits + currentGradePoints) / total;
  }
}
