import 'package:flutter/material.dart';
import '../services/recall_session_storage.dart';
import '../services/recall_storage.dart';
import '../services/course_storage.dart';
import 'recall_practice_screen.dart';

class RecallHistoryScreen extends StatefulWidget {
  const RecallHistoryScreen({super.key});

  @override
  State<RecallHistoryScreen> createState() => _RecallHistoryScreenState();
}

class _RecallHistoryScreenState extends State<RecallHistoryScreen> {
  bool loading = true;
  List<Map<String, dynamic>> entries = [];
  List<Map<String, dynamic>> activeSessions = [];
  String courseFilter = '';

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    try {
      await RecallStorage.initialize();
      await RecallSessionStorage.initialize();
      if (!mounted) return;
      setState(() {
        entries = RecallStorage.all();
        activeSessions = RecallSessionStorage.all();
        loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => loading = false);
    }
  }

  String _courseDisplay(Map<String, dynamic> record) {
    final id = (record['course_id'] ?? '').toString();
    if (id.isEmpty) return 'Independent study';
    final matches = CourseStorage.allForSync().where((course) => course.id == id);
    if (matches.isNotEmpty) return matches.first.title;
    final snapshot = (record['course_name'] ?? '').toString();
    return snapshot.isEmpty ? 'Archived course' : snapshot;
  }

  String _answerLabel(Map<String, dynamic> entry) {
    final answer = (entry['answer'] ?? '').toString().trim();
    if (answer.isEmpty && entry['rating'] == 'Again') {
      return 'Could not recall yet';
    }
    return answer;
  }

  Future<void> _resume(Map<String, dynamic> session) async {
    final sessionId = session['session_id']?.toString() ?? '';
    if (sessionId.isEmpty) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => RecallPracticeScreen(
          missionId: session['mission_id']?.toString() ?? '',
          topic: session['topic']?.toString() ?? '',
          notes: session['notes']?.toString() ?? '',
          sessionId: sessionId,
          courseId: (session['course_id'] ?? '').toString(),
          courseName: (session['course_name'] ?? '').toString(),
          courseCode: (session['course_code'] ?? '').toString(),
        ),
      ),
    );
    if (mounted) await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now().toUtc();
    final courseNames = <String, String>{};
    for (final course in CourseStorage.getCourses()) {
      courseNames[course.id] = '${course.code} · ${course.title}';
    }
    for (final record in [...entries, ...activeSessions]) {
      final id = (record['course_id'] ?? '').toString();
      if (id.isEmpty) continue;
      final snapshotName = (record['course_name'] ?? '').toString();
      courseNames.putIfAbsent(id, () => snapshotName.isEmpty ? id : snapshotName);
    }
    final filteredEntries = entries.where((entry) {
      final id = (entry['course_id'] ?? '').toString();
      return courseFilter.isEmpty || (courseFilter == '__standalone__' ? id.isEmpty : id == courseFilter);
    }).toList();
    final filteredSessions = activeSessions.where((session) {
      final id = (session['course_id'] ?? '').toString();
      return courseFilter.isEmpty || (courseFilter == '__standalone__' ? id.isEmpty : id == courseFilter);
    }).toList();
    final due = filteredEntries.where((entry) {
      final date = DateTime.tryParse(entry['next_review_at'] as String? ?? '');
      return date != null && !date.isAfter(now);
    }).length;

    return Scaffold(
      appBar: AppBar(title: const Text('Recall & Revision')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: courseFilter,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Filter by course', border: OutlineInputBorder()),
                    items: [
                      const DropdownMenuItem(value: '', child: Text('All courses')),
                      const DropdownMenuItem(value: '__standalone__', child: Text('Independent / older sessions')),
                      for (final entry in courseNames.entries)
                        DropdownMenuItem(value: entry.key, child: Text(entry.value, overflow: TextOverflow.ellipsis)),
                    ],
                    onChanged: (value) => setState(() => courseFilter = value ?? ''),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: ListTile(
                      title: Text('$due review${due == 1 ? '' : 's'} due'),
                      subtitle: const Text('Small steps count. Review when you are ready.'),
                    ),
                  ),
                  if (filteredSessions.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text('Continue a recall session', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 6),
                    for (final session in filteredSessions)
                      Builder(builder: (context) {
                        final rawQuestions = session['questions'];
                        final total = rawQuestions is List ? rawQuestions.length : 0;
                        final rawCompleted = session['completed_indices'];
                        final completed = rawCompleted is List ? rawCompleted.length : 0;
                        final rawSkipped = session['skipped_indices'];
                        final skipped = rawSkipped is List ? rawSkipped.length : 0;
                        final sessionTopic = (session['topic'] ?? '').toString().trim();
                        return Card(
                          child: ListTile(
                            title: Text(_courseDisplay(session)),
                            subtitle: Text('${session['course_code'] ?? ''}${sessionTopic.isEmpty ? '' : ' · $sessionTopic'}\n'
                              '$completed of $total reviewed${skipped > 0 ? ' · $skipped skipped' : ''}'),
                            isThreeLine: true,
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => _resume(session),
                          ),
                        );
                      }),
                  ],
                  const SizedBox(height: 12),
                  Text('Recall history', style: Theme.of(context).textTheme.titleMedium),
                  if (filteredEntries.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('No recall attempts yet. Complete a study session and try Smart Recall.'),
                    ),
                  for (final entry in filteredEntries)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_courseDisplay(entry), style: Theme.of(context).textTheme.titleMedium),
                            Text((entry['topic'] ?? 'Topic').toString()),
                            const SizedBox(height: 6),
                            Text(entry['question'] as String? ?? ''),
                            const SizedBox(height: 6),
                            Text('Your answer: ${_answerLabel(entry)}'),
                            const SizedBox(height: 8),
                            Text('Last rating: ${entry['rating']}  ·  Next review: ${(entry['next_review_at'] as String? ?? '').split('T').first}'),
                            if (() {
                              final date = DateTime.tryParse(entry['next_review_at'] as String? ?? '');
                              return date != null && !date.isAfter(now);
                            }())
                              Wrap(
                                spacing: 4,
                                children: [
                                  for (final rating in ['Again', 'Hard', 'Good', 'Easy'])
                                    TextButton(
                                      onPressed: () async {
                                        await RecallStorage.reschedule(entry['id'] as String, rating);
                                        if (mounted) await _refresh();
                                      },
                                      child: Text(rating),
                                    ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}
