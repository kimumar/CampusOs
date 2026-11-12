import 'package:flutter/material.dart';
import '../services/academic_task_storage.dart';
import '../services/course_storage.dart';
import '../services/study_mission_storage.dart';

/// Assignments, examinations and gentle next-day planning, all saved locally.
class AcademicPlannerScreen extends StatefulWidget {
  const AcademicPlannerScreen({super.key});
  @override
  State<AcademicPlannerScreen> createState() => _AcademicPlannerScreenState();
}

class _AcademicPlannerScreenState extends State<AcademicPlannerScreen> {
  List<Map<String, dynamic>> tasks = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    await AcademicTaskStorage.initialize();
    if (!mounted) return;
    setState(() { tasks = AcademicTaskStorage.all(); loading = false; });
  }

  Future<void> _edit([Map<String, dynamic>? existing]) async {
    final courses = CourseStorage.getCourses();
    final title = TextEditingController(text: (existing?['title'] ?? '').toString());
    final details = TextEditingController(text: (existing?['details'] ?? '').toString());
    var selectedCourse = (existing?['course_id'] ?? '').toString();
    if (!courses.any((course) => course.id == selectedCourse)) selectedCourse = '';
    var selectedKind = (existing?['kind'] ?? 'assignment').toString();
    var dueDate = DateTime.tryParse((existing?['due_at'] ?? '').toString())?.toLocal() ??
        DateTime.now().add(const Duration(days: 1));
    Map<String, dynamic>? result;
    try {
      if (!mounted) return;
      result = await showModalBottomSheet<Map<String, dynamic>>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (sheetContext) => StatefulBuilder(
          builder: (sheetContext, updateSheet) => SafeArea(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.9),
              child: ListView(
                shrinkWrap: true,
                padding: EdgeInsets.fromLTRB(20, 8, 20, MediaQuery.viewInsetsOf(sheetContext).bottom + 24),
                children: [
                  Text(existing == null ? 'Add academic deadline' : 'Edit academic deadline',
                      style: Theme.of(sheetContext).textTheme.titleLarge),
                  const SizedBox(height: 18),
                  TextField(controller: title, maxLength: 140, decoration: const InputDecoration(
                    labelText: 'What needs to be done?', border: OutlineInputBorder())),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: selectedKind,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Type', border: OutlineInputBorder()),
                    items: const [
                      DropdownMenuItem(value: 'assignment', child: Text('Assignment')),
                      DropdownMenuItem(value: 'test', child: Text('Test')),
                      DropdownMenuItem(value: 'exam', child: Text('Exam')),
                    ],
                    onChanged: (value) { if (value != null) updateSheet(() => selectedKind = value); },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: selectedCourse,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Course (optional)', border: OutlineInputBorder()),
                    items: [
                      const DropdownMenuItem(value: '', child: Text('General / independent')),
                      for (final course in courses)
                        DropdownMenuItem(value: course.id, child: Text('${course.code} · ${course.title}', overflow: TextOverflow.ellipsis)),
                    ],
                    onChanged: (value) { if (value != null) updateSheet(() => selectedCourse = value); },
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final day = await showDatePicker(
                        context: sheetContext, initialDate: dueDate,
                        firstDate: DateTime(2020), lastDate: DateTime(2100),
                      );
                      if (day != null) updateSheet(() => dueDate = day);
                    },
                    icon: const Icon(Icons.event_outlined),
                    label: Text('Due: ${dueDate.day}/${dueDate.month}/${dueDate.year}'),
                  ),
                  const SizedBox(height: 12),
                  TextField(controller: details, maxLines: 3,
                    decoration: const InputDecoration(labelText: 'Details (optional)', border: OutlineInputBorder())),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: () {
                      if (title.text.trim().isEmpty) {
                        ScaffoldMessenger.of(sheetContext).showSnackBar(
                          const SnackBar(content: Text('Enter an academic task title.')));
                        return;
                      }
                      Navigator.of(sheetContext).pop(<String, dynamic>{
                        'title': title.text.trim(), 'kind': selectedKind,
                        'course_id': selectedCourse, 'due_at': dueDate,
                        'details': details.text.trim(),
                      });
                    },
                    icon: const Icon(Icons.save_outlined), label: const Text('Save deadline'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    } finally {
      // The sheet's pop future can resolve while its reverse animation still
      // builds the TextFields. Let that route finish before disposing controllers.
      await Future<void>.delayed(const Duration(milliseconds: 400));
      title.dispose();
      details.dispose();
    }
    final data = result;
    if (data == null) return;
    final selected = courses.where((course) => course.id == data['course_id']);
    final course = selected.isNotEmpty ? selected.first : null;
    await AcademicTaskStorage.save(
      id: existing?['id']?.toString(),
      title: data['title'] as String,
      kind: data['kind'] as String,
      dueAt: data['due_at'] as DateTime,
      courseId: data['course_id'] as String,
      courseName: course?.title ?? '',
      courseCode: course?.code ?? '',
      details: data['details'] as String,
    );
    await StudyMissionStorage.ensureToday();
    if (mounted) await _refresh();
  }

  Future<void> _tomorrowPlan() async {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    final suggestions = StudyMissionStorage.suggestionsFor(tomorrow);
    if (!mounted) return;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Tomorrow at a glance'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
            children: suggestions.isEmpty
              ? [const Text('No recorded priorities yet. Add courses or deadlines to personalise your plan.')]
              : [for (final mission in suggestions)
                  Padding(padding: const EdgeInsets.only(bottom: 12), child: Text('• ${mission['title']}'))],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Close')),
          if (suggestions.isNotEmpty)
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Save tomorrow plan')),
        ],
      ),
    );
    if (accepted == true) {
      await StudyMissionStorage.ensureForDate(tomorrow);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tomorrow plan saved on this device. You can adjust it later.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final pending = tasks.where((task) => task['done'] != true).toList();
    final completed = tasks.where((task) => task['done'] == true).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Academic Planner')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(), icon: const Icon(Icons.add), label: const Text('Add task')),
      body: loading ? const Center(child: CircularProgressIndicator()) :
        ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 100), children: [
          Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Plan gently, act confidently', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              const Text('Add real deadlines. CampusOS will suggest meaningful, manageable daily missions.'),
              const SizedBox(height: 10),
              OutlinedButton.icon(onPressed: _tomorrowPlan,
                icon: const Icon(Icons.event_available_outlined), label: const Text('One-tap tomorrow plan')),
            ],
          ))),
          const SizedBox(height: 16),
          Text('Upcoming tasks', style: Theme.of(context).textTheme.titleLarge),
          if (pending.isEmpty) const Padding(padding: EdgeInsets.all(20),
            child: Text('No pending deadlines recorded. Add one whenever you are ready.')),
          for (final task in [...pending, ...completed])
            Card(child: ListTile(
              leading: Checkbox(value: task['done'] == true, onChanged: (checked) async {
                await AcademicTaskStorage.setCompleted(task['id'].toString(), checked == true);
                await StudyMissionStorage.ensureToday();
                if (mounted) await _refresh();
              }),
              title: Text(task['title']?.toString() ?? '',
                style: TextStyle(decoration: task['done'] == true ? TextDecoration.lineThrough : null)),
              subtitle: Text('${(task['kind'] ?? '').toString().toUpperCase()}  ·  '
                  '${(task['course_name'] ?? '').toString().isEmpty ? 'General' : task['course_name']}\n'
                  'Due ${(task['due_at'] ?? '').toString().split('T').first}'),
              isThreeLine: true,
              trailing: PopupMenuButton<String>(
                onSelected: (value) async {
                  if (value == 'edit') { await _edit(task); return; }
                  if (value == 'archive') { await AcademicTaskStorage.archive(task['id'].toString()); await _refresh(); }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('Edit')),
                  PopupMenuItem(value: 'archive', child: Text('Archive')),
                ],
              ),
              onTap: () => _edit(task),
            )),
        ]),
    );
  }
}
