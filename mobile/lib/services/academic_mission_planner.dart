/// Pure, deterministic priority rules. Never invent a deadline or a topic.
class AcademicMissionPlanner {
  AcademicMissionPlanner._();

  static int urgency(DateTime deadline, DateTime now) {
    final days = DateTime(deadline.year, deadline.month, deadline.day)
        .difference(DateTime(now.year, now.month, now.day)).inDays;
    if (days < 0) return 100;
    if (days == 0) return 95;
    if (days == 1) return 90;
    if (days <= 3) return 75;
    if (days <= 7) return 55;
    return 0;
  }

  static List<Map<String, dynamic>> select(List<Map<String, dynamic>> candidates, {int max = 3}) {
    final sorted = candidates.map((item) => Map<String, dynamic>.from(item)).toList()
      ..sort((a, b) {
        final score = ((b['priority'] as num?)?.toInt() ?? 0)
            .compareTo((a['priority'] as num?)?.toInt() ?? 0);
        if (score != 0) return score;
        return (a['id'] ?? '').toString().compareTo((b['id'] ?? '').toString());
      });
    final selected = <Map<String, dynamic>>[];
    final used = <String>{};
    for (final candidate in sorted) {
      final id = (candidate['id'] ?? '').toString();
      if (id.isEmpty || !used.add(id)) continue;
      selected.add(candidate);
      if (selected.length >= max) break;
    }
    return selected;
  }
}
