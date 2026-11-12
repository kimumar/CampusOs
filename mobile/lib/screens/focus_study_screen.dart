import 'dart:async';
import 'package:flutter/material.dart';
import '../services/study_draft_storage.dart';
import '../services/study_mission_storage.dart';
import 'recall_practice_screen.dart';
import 'recall_history_screen.dart';
import '../services/local_question_generator.dart';
import '../services/course_storage.dart';
import '../services/study_session_storage.dart';

/// M04-B1 workspace: offline draft, optional focus timer, explicit finish.
/// Existing dashboard route and mission ID contract remain unchanged.
class FocusStudyScreen extends StatefulWidget {
  const FocusStudyScreen({
    super.key, required this.missionId, required this.title,
    this.courseId = '', this.initialNotes = '', this.initialTopic = '',
  });
  final String missionId;
  final String title;
  final String courseId;
  final String initialNotes;
  final String initialTopic;

  @override
  State<FocusStudyScreen> createState() => _FocusStudyScreenState();
}

class _FocusStudyScreenState extends State<FocusStudyScreen> {
  static const List<int> durationOptions = [15, 25, 45, 60];
  bool useTimer = false;
  String selectedCourseId = '';
  String get selectedCourseName {
    final active = CourseStorage.allForSync().where((course) => course.id == selectedCourseId);
    return active.isNotEmpty ? active.first.title : '';
  }
  String get selectedCourseCode {
    final active = CourseStorage.allForSync().where((course) => course.id == selectedCourseId);
    return active.isNotEmpty ? active.first.code : '';
  }
  int targetMinutes = 25;
  int get targetSeconds => targetMinutes * 60;
  final topicController = TextEditingController();
  final objectiveController = TextEditingController();
  final notesController = TextEditingController();
  Timer? ticker;
  Timer? autosave;
  DateTime? lastTick;
  int elapsedSeconds = 0;
  bool loading = true;
  bool saving = false;
  bool dirty = false;
  String? error;

  @override
  void initState() {
    super.initState();
    for (final controller in [topicController, objectiveController, notesController]) {
      controller.addListener(_changed);
    }
    _load();
  }

  Future<void> _load() async {
    try {
      await StudyDraftStorage.initialize();
      final draft = StudyDraftStorage.read(widget.missionId);
      selectedCourseId = (draft?['course_id'] ?? widget.courseId).toString();
      if (!CourseStorage.allForSync().any((course) => course.id == selectedCourseId)) {
        selectedCourseId = '';
      }
      if (!mounted) return;
      if (draft != null) {
        topicController.text = draft['topic'] as String? ?? '';
        objectiveController.text = draft['objective'] as String? ?? '';
        notesController.text = draft['notes'] as String? ?? '';
        useTimer = draft['use_timer'] == true;
        targetMinutes = durationOptions.contains(draft['target_minutes']) ? draft['target_minutes'] as int : 25;
        elapsedSeconds = ((draft['elapsed_seconds'] as num?)?.toInt() ?? 0).clamp(0, targetSeconds);
      } else {
        topicController.text = widget.initialTopic;
        notesController.text = widget.initialNotes;
      }
      setState(() { loading = false; dirty = false; });
    } catch (_) {
      if (mounted) setState(() { loading = false; error = 'Could not open saved study draft.'; });
    }
  }

  void _changed() {
    if (loading || saving) return;
    dirty = true;
    autosave?.cancel();
    autosave = Timer(const Duration(milliseconds: 700), _saveDraft);
  }

  Future<void> _saveDraft() async {
    if (loading || saving || error != null) return;
    try {
      await StudyDraftStorage.save(
        missionId: widget.missionId,
        topic: topicController.text,
        objective: objectiveController.text,
        notes: notesController.text,
        elapsedSeconds: elapsedSeconds,
        useTimer: useTimer,
        targetMinutes: targetMinutes,
        courseId: selectedCourseId,
      );
      dirty = false;
    } catch (_) {
      if (mounted) setState(() => error = 'Autosave failed. Keep this screen open and retry.');
    }
  }

  void _toggleTimer() {
    if (ticker != null) {
      _stopTimer();
      _saveDraft();
      setState(() {});
      return;
    }
    lastTick = DateTime.now();
    ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      final now = DateTime.now();
      final seconds = now.difference(lastTick!).inSeconds;
      if (seconds < 1) return;
      lastTick = now;
      if (!mounted) return;
      setState(() => elapsedSeconds = (elapsedSeconds + seconds).clamp(0, targetSeconds));
      dirty = true;
      if (elapsedSeconds % 10 == 0) { _saveDraft(); }
      if (elapsedSeconds >= targetSeconds) {
        _stopTimer();
        _saveDraft();
      }
    });
    setState(() {});
  }

  void _stopTimer() {
    ticker?.cancel();
    ticker = null;
    lastTick = null;
  }

  Future<void> _finish() async {
    if (saving) return;
    _stopTimer();
    autosave?.cancel();
    setState(() => saving = true);
    try {
      // Persist the notes before marking the activity complete or opening recall.
      await StudyDraftStorage.save(
        missionId: widget.missionId,
        topic: topicController.text,
        objective: objectiveController.text,
        notes: notesController.text,
        elapsedSeconds: elapsedSeconds,
        useTimer: useTimer,
        targetMinutes: targetMinutes,
        courseId: selectedCourseId,
      );
      if (useTimer && elapsedSeconds >= 60) {
        await StudyMissionStorage.recordFocus(widget.missionId, elapsedSeconds ~/ 60);
      }
      await StudySessionStorage.initialize();
      await StudySessionStorage.record(
        id: '${widget.missionId}_${DateTime.now().microsecondsSinceEpoch}',
        missionId: widget.missionId,
        topic: topicController.text.trim().isEmpty ? 'Untitled topic' : topicController.text.trim(),
        courseId: selectedCourseId,
        courseName: selectedCourseName,
        courseCode: selectedCourseCode,
        timedMinutes: useTimer ? elapsedSeconds ~/ 60 : 0,
        hasLearningWork: notesController.text.trim().length >= 20 ||
            objectiveController.text.trim().length >= 20 || elapsedSeconds >= 60,
      );
      // Completing a study activity never depends on using the optional timer.
      await StudyMissionStorage.setCompleted(widget.missionId, true);
      // Reset the active timer after recording so a second tap cannot double-count it.
      elapsedSeconds = 0;
      await StudyDraftStorage.save(
        missionId: widget.missionId,
        topic: topicController.text,
        objective: objectiveController.text,
        notes: notesController.text,
        elapsedSeconds: 0,
        useTimer: useTimer,
        targetMinutes: targetMinutes,
        courseId: selectedCourseId,
      );
      if (!mounted) return;

      final startRecall = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Study session saved'),
          content: const Text(
            'Your notes are saved. Would you like CampusOS to create recall questions from what you studied?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Maybe later'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Start Smart Recall'),
            ),
          ],
        ),
      );
      if (!mounted) return;

      if (startRecall == true) {
        final result = LocalQuestionGenerator.generateDetailed(
          notesController.text,
          topic: topicController.text.trim().isEmpty
              ? widget.title
              : topicController.text.trim(),
          objective: objectiveController.text,
        );

        if (result.questions.isEmpty) {
          final warningText = result.warnings.isEmpty
              ? 'There are not enough clear facts for reliable questions yet. Add a definition, explanation or clear bullet points, then try again.'
              : result.warnings.join('\n\n');
          final addMoreNotes = await showDialog<bool>(
            context: context,
            builder: (dialogContext) => AlertDialog(
              title: const Text('A little more detail is needed'),
              content: Text('Your notes are saved.\n\n$warningText'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Finish for now'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: const Text('Add more notes'),
                ),
              ],
            ),
          );
          if (!mounted) return;
          if (addMoreNotes == true) return;
        } else {
          final recallTopic = topicController.text.trim().isEmpty
              ? widget.title
              : topicController.text.trim();
          await Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => RecallPracticeScreen(
                missionId: widget.missionId,
                topic: recallTopic,
                notes: notesController.text,
                courseId: selectedCourseId,
                courseName: selectedCourseName,
                courseCode: selectedCourseCode,
                questions: result.questions,
                generationWarnings: result.warnings,
                sessionId: '${widget.missionId}_${DateTime.now().microsecondsSinceEpoch}',
              ),
            ),
          );
        }
      }

      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not finish the session. Your saved study draft remains on this device.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> _leave() async {
    _stopTimer();
    autosave?.cancel();
    await _saveDraft();
    if (!mounted) return;
    if (error == null) {
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    _stopTimer();
    autosave?.cancel();
    topicController.dispose();
    objectiveController.dispose();
    notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final remaining = (targetSeconds - elapsedSeconds).clamp(0, targetSeconds);
    final timerLabel = '${(remaining ~/ 60).toString().padLeft(2, '0')}:${(remaining % 60).toString().padLeft(2, '0')}';
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) { if (!didPop && !saving) _leave(); },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Study Workspace'),
          leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: saving ? null : _leave),
        ),
        body: SafeArea(child: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
            ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [Text(error!, textAlign: TextAlign.center), const SizedBox(height: 12),
                  OutlinedButton(onPressed: () { setState(() => error = null); _saveDraft(); }, child: const Text('Retry save'))],
              )))
            : Center(child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: ListView(padding: const EdgeInsets.fromLTRB(20, 16, 20, 40), children: [
                  Text(selectedCourseName.isNotEmpty ? selectedCourseName : 'Independent study',
                    style: Theme.of(context).textTheme.titleLarge),
                  if (selectedCourseCode.isNotEmpty)
                    Text(selectedCourseCode, style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: selectedCourseId,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Selected course', border: OutlineInputBorder()),
                    items: [
                      const DropdownMenuItem(value: '', child: Text('Independent study')),
                      for (final course in CourseStorage.allForSync())
                        DropdownMenuItem(value: course.id, child: Text(
                          '${course.code} · ${course.title}${course.isDeleted ? ' (archived)' : ''}',
                          overflow: TextOverflow.ellipsis)),
                    ],
                    onChanged: saving ? null : (value) {
                      setState(() => selectedCourseId = value ?? '');
                      _changed();
                    },
                  ),
                  const SizedBox(height: 8),
                  const Text('Study freely. When you finish, you can turn these notes into recall questions.'),
                  const SizedBox(height: 22),
                  TextField(controller: topicController, maxLength: 120,
                    decoration: const InputDecoration(labelText: 'Topic', hintText: 'e.g. Database normalization', border: OutlineInputBorder())),
                  const SizedBox(height: 12),
                  TextField(controller: objectiveController, maxLength: 300, maxLines: 2,
                    decoration: const InputDecoration(labelText: 'Learning objective', hintText: 'What should you understand today?', border: OutlineInputBorder())),
                  const SizedBox(height: 12),
                  TextField(controller: notesController, maxLines: 9, minLines: 5,
                    decoration: const InputDecoration(labelText: 'My study notes', hintText: 'Write definitions, examples and key ideas...', alignLabelWithHint: true, border: OutlineInputBorder())),
                  const SizedBox(height: 18),
                  Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Text('Study at your own pace', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment(value: false, label: Text('Free study'), icon: Icon(Icons.menu_book_outlined)),
                        ButtonSegment(value: true, label: Text('Set timer'), icon: Icon(Icons.timer_outlined)),
                      ],
                      selected: {useTimer},
                      onSelectionChanged: saving ? null : (values) {
                        _stopTimer();
                        setState(() { useTimer = values.first; elapsedSeconds = 0; });
                        _changed();
                      },
                    ),
                    const SizedBox(height: 12),
                    if (!useTimer) ...[
                      const Text('No countdown or minimum duration. Study as long as you like.'),
                      const SizedBox(height: 6),
                      const Text('Untimed study records no study minutes.'),
                    ] else ...[
                      DropdownButtonFormField<int>(
                        initialValue: targetMinutes,
                        decoration: const InputDecoration(labelText: 'Focus duration', border: OutlineInputBorder()),
                        items: [for (final m in durationOptions) DropdownMenuItem(value: m, child: Text('$m minutes'))],
                        onChanged: ticker != null || saving ? null : (value) {
                          if (value == null) return;
                          setState(() { targetMinutes = value; elapsedSeconds = 0; });
                          _changed();
                        },
                      ),
                      const SizedBox(height: 12),
                      Center(child: Text(timerLabel, style: Theme.of(context).textTheme.headlineLarge)),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: elapsedSeconds >= targetSeconds ? null : _toggleTimer,
                        icon: Icon(ticker == null ? Icons.play_arrow : Icons.pause),
                        label: Text(ticker == null ? 'Start / resume' : 'Pause'),
                      ),
                      const SizedBox(height: 6),
                      const Text('Only elapsed time while the timer runs is recorded.'),
                    ],
                  ]))),
                  const SizedBox(height: 14),
                  TextButton.icon(
                    onPressed: saving ? null : () => Navigator.of(context).push(
                      MaterialPageRoute<void>(builder: (_) => const RecallHistoryScreen())),
                    icon: const Icon(Icons.history), label: const Text('Recall history & upcoming reviews')),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(onPressed: saving ? null : () async { await _saveDraft(); if (!context.mounted) return; if (error == null) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Draft saved on this device.'))); } },
                    icon: const Icon(Icons.save_outlined), label: const Text('Save draft')),
                  const SizedBox(height: 8),
                  FilledButton.icon(onPressed: saving ? null : _finish,
                    icon: const Icon(Icons.check_circle_outline), label: Text(saving ? 'Saving...' : 'Finish study session')),
                  const SizedBox(height: 12),
                  const Text('Finishing marks this study activity complete. Timer minutes are optional, and your notes stay saved.', textAlign: TextAlign.center),
                ]),
              ))),
      ),
    );
  }
}
