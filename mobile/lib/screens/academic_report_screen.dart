import 'package:flutter/material.dart';
import '../services/academic_task_storage.dart';
import '../services/recall_storage.dart';
import '../services/study_mission_storage.dart';
import '../services/study_session_storage.dart';

class AcademicReportScreen extends StatefulWidget {
  const AcademicReportScreen({super.key});
  @override
  State<AcademicReportScreen> createState() => _AcademicReportScreenState();
}

class _AcademicReportScreenState extends State<AcademicReportScreen> {
  bool loading = true;
  List<Map<String, dynamic>> sessions = [];
  List<Map<String, dynamic>> reviews = [];
  List<Map<String, dynamic>> tasks = [];

  @override
  void initState() { super.initState(); _refresh(); }

  Future<void> _refresh() async {
    await StudySessionStorage.initialize();
    await RecallStorage.initialize();
    await AcademicTaskStorage.initialize();
    if (!mounted) return;
    setState(() {
      sessions = StudySessionStorage.all();
      reviews = RecallStorage.all();
      tasks = AcademicTaskStorage.all();
      loading = false;
    });
  }

  bool _withinWeek(String? raw, DateTime cutoff) {
    final date = DateTime.tryParse(raw ?? '')?.toLocal();
    return date != null && !date.isBefore(cutoff);
  }

  Widget _metric(String title, String value, String description) => Card(
    child: Padding(padding: const EdgeInsets.all(14), child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [Text(value, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 3), Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 4), Text(description, style: Theme.of(context).textTheme.bodySmall)],
    )),
  );

  @override
  Widget build(BuildContext context) {
    final cutoff = DateTime.now().subtract(const Duration(days: 7));
    final currentSessions = sessions.where((session) => _withinWeek(session['finished_at']?.toString(), cutoff)).toList();
    final currentReviews = reviews.where((review) => _withinWeek(review['created_at']?.toString(), cutoff)).toList();
    final currentCompleted = tasks.where((task) => task['done'] == true &&
      _withinWeek(task['completed_at']?.toString(), cutoff)).toList();
    final minutes = currentSessions.fold<int>(0, (total, session) =>
      total + ((session['timed_minutes'] as num?)?.toInt() ?? 0));
    final topics = currentSessions.map((session) => session['topic']?.toString() ?? '')
      .where((topic) => topic.trim().isNotEmpty).toSet();
    final due = reviews.where((review) {
      final deadline = DateTime.tryParse(review['next_review_at']?.toString() ?? '');
      return deadline != null && !deadline.isAfter(DateTime.now().toUtc());
    }).length;
    return Scaffold(
      appBar: AppBar(title: const Text('Weekly Academic Report')),
      body: loading ? const Center(child: CircularProgressIndicator()) :
        RefreshIndicator(onRefresh: _refresh, child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32), children: [
            Text('Your last 7 days', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            const Text('Activity and self-assessments, never invented mastery scores.'),
            const SizedBox(height: 14),
            _metric('Study sessions', '${currentSessions.length}', 'Completed study activities'),
            _metric('Recorded study time', '$minutes minutes', 'Only time actually tracked with the optional timer'),
            _metric('Recall attempts', '${currentReviews.length}', 'Answers you rated during recall'),
            _metric('Completed academic tasks', '${currentCompleted.length}', 'Assignments, tests and exams marked completed'),
            _metric('Revisions due', '$due', 'Available when you are ready — no penalty for delays'),
            const SizedBox(height: 18),
            Text('Topics you studied', style: Theme.of(context).textTheme.titleMedium),
            if (topics.isEmpty) const Padding(padding: EdgeInsets.all(12), child: Text('No finished topics recorded this week.')),
            for (final topic in topics) ListTile(dense: true, leading: const Icon(Icons.menu_book_outlined), title: Text(topic)),
            const SizedBox(height: 12),
            Text('Next gentle priorities', style: Theme.of(context).textTheme.titleMedium),
            for (final mission in StudyMissionStorage.today())
              ListTile(dense: true, leading: const Icon(Icons.checklist_outlined), title: Text(mission['title']?.toString() ?? '')),
            const SizedBox(height: 16),
            const Text('Consistency, confidence and retention are distinct. A Good rating is self-reported understanding, not a university grade.'),
          ],
        )),
    );
  }
}
