/// Pure local progress calculation. Never represents one device as a community.
class CampusPulseSnapshot {
  const CampusPulseSnapshot({required this.assigned, required this.completed, required this.daysWithGoals});

  final int assigned;
  final int completed;
  final int daysWithGoals;

  bool get hasGoals => assigned > 0;
  double get fraction => assigned == 0 ? 0 : completed / assigned;
  int get percentage => (fraction * 100).round();
  bool get reached100 => hasGoals && fraction >= 1;
  bool get reached90 => hasGoals && fraction >= .9;
  bool get reached50 => hasGoals && fraction >= .5;

  static CampusPulseSnapshot fromSavedDays(Iterable<List<Map<String, dynamic>>> days) {
    var total = 0;
    var done = 0;
    var daysWithGoals = 0;
    for (final missions in days) {
      if (missions.isEmpty) continue;
      daysWithGoals++;
      total += missions.length;
      done += missions.where((m) => m['done'] == true).length;
    }
    return CampusPulseSnapshot(assigned: total, completed: done, daysWithGoals: daysWithGoals);
  }
}
