import 'dart:async';
import 'package:flutter/material.dart';
import '../services/local_question_generator.dart';
import '../services/recall_answer_assessment.dart';
import '../services/recall_session_storage.dart';
import '../services/cloud_sync.dart';
import '../services/recall_storage.dart';
import '../services/course_storage.dart';

/// One-question-at-a-time recall. Theory answers are self-assessed; no exact
/// wording score is applied. Progress is saved locally so students can leave
/// and resume without losing their place.
class RecallPracticeScreen extends StatefulWidget {
  const RecallPracticeScreen({
    super.key,
    required this.missionId,
    required this.topic,
    required this.notes,
    this.questions = const [],
    this.sessionId,
    this.generationWarnings = const [],
    // Legacy fields are retained so older routes continue to compile.
    this.initialQuestion = '',
    this.referenceAnswer = '',
    this.questionType,
    this.keyConcepts = const [],
    this.acceptedAnswers = const [],
    this.courseId = '',
    this.courseName = '',
    this.courseCode = '',
  });

  final String missionId;
  final String topic;
  final String notes;
  final List<GeneratedRecallQuestion> questions;
  final String? sessionId;
  final List<String> generationWarnings;
  final String initialQuestion;
  final String referenceAnswer;
  final RecallQuestionType? questionType;
  final List<String> keyConcepts;
  final List<String> acceptedAnswers;
  final String courseId;
  final String courseName;
  final String courseCode;

  @override
  State<RecallPracticeScreen> createState() => _RecallPracticeScreenState();
}

class _RecallPracticeScreenState extends State<RecallPracticeScreen> {
  final questionController = TextEditingController();
  final answerController = TextEditingController();
  final Map<int, String> answers = <int, String>{};
  final Set<int> completedIndices = <int>{};
  final Set<int> skippedIndices = <int>{};
  final List<GeneratedRecallQuestion> questions = <GeneratedRecallQuestion>[];
  final List<String> warnings = <String>[];

  late final String sessionId;
  Timer? saveDebounce;
  int currentIndex = 0;
  bool loading = true;
  bool busy = false;
  bool revealed = false;
  bool checked = false;
  bool? exactMatch;
  bool editingQuestion = false;
  bool showSummary = false;
  String? loadError;

  String get displayedCourseName {
    final matches = CourseStorage.allForSync().where((course) => course.id == widget.courseId);
    return matches.isNotEmpty ? matches.first.title : widget.courseName;
  }

  String get displayedCourseCode {
    final matches = CourseStorage.allForSync().where((course) => course.id == widget.courseId);
    return matches.isNotEmpty ? matches.first.code : widget.courseCode;
  }

  GeneratedRecallQuestion? get currentQuestion =>
      currentIndex >= 0 && currentIndex < questions.length
          ? questions[currentIndex]
          : null;

  bool get isFillBlank =>
      currentQuestion?.type == RecallQuestionType.fillBlank;

  @override
  void initState() {
    super.initState();
    sessionId = widget.sessionId ??
        '${widget.missionId}_${DateTime.now().microsecondsSinceEpoch}';
    answerController.addListener(_answerChanged);
    questionController.addListener(_questionChanged);
    _loadSession();
  }

  Future<void> _loadSession() async {
    try {
      await RecallStorage.initialize();
      await RecallSessionStorage.initialize();
      final saved = RecallSessionStorage.read(sessionId);
      if (saved != null) {
        final rawQuestions = saved['questions'];
        if (rawQuestions is List) {
          questions.addAll(rawQuestions
              .whereType<Map>()
              .map(GeneratedRecallQuestion.fromMap));
        }
        final rawAnswers = saved['answers'];
        if (rawAnswers is Map) {
          for (final entry in rawAnswers.entries) {
            final index = int.tryParse(entry.key.toString());
            if (index != null) answers[index] = entry.value.toString();
          }
        }
        _addIndices(completedIndices, saved['completed_indices']);
        _addIndices(skippedIndices, saved['skipped_indices']);
        final rawWarnings = saved['warnings'];
        if (rawWarnings is List) {
          warnings.addAll(rawWarnings.map((value) => value.toString()));
        }
        currentIndex = (saved['current_index'] as num?)?.toInt() ?? 0;
      } else {
        if (widget.questions.isNotEmpty) {
          questions.addAll(widget.questions);
        } else if (widget.initialQuestion.trim().isNotEmpty) {
          questions.add(GeneratedRecallQuestion(
            id: 'legacy_${DateTime.now().microsecondsSinceEpoch}',
            type: widget.questionType ?? RecallQuestionType.theory,
            question: widget.initialQuestion,
            answer: widget.referenceAnswer.isEmpty
                ? widget.notes
                : widget.referenceAnswer,
            source: widget.notes,
            keyConcepts: widget.keyConcepts,
            acceptedAnswers: widget.acceptedAnswers,
          ));
        } else {
          final result = LocalQuestionGenerator.generateDetailed(
            widget.notes,
            topic: widget.topic,
          );
          questions.addAll(result.questions);
          warnings.addAll(result.warnings);
        }
        warnings.addAll(widget.generationWarnings);
        currentIndex = 0;
        if (questions.isNotEmpty) await _persistProgress();
      }

      if (questions.isNotEmpty) {
        currentIndex = _findNextPending(start: currentIndex);
        if (currentIndex < 0) {
          showSummary = true;
        } else {
          _loadCurrentFields();
        }
      }
      if (mounted) setState(() => loading = false);
    } catch (_) {
      if (mounted) {
        setState(() {
          loading = false;
          loadError = 'Could not open your saved recall session. Your study notes remain safe.';
        });
      }
    }
  }

  void _addIndices(Set<int> target, dynamic raw) {
    if (raw is! List) return;
    for (final value in raw) {
      final index = (value as num?)?.toInt();
      if (index != null && index >= 0 && index < questions.length) {
        target.add(index);
      }
    }
  }

  void _loadCurrentFields() {
    final item = currentQuestion;
    if (item == null) return;
    questionController.text = item.question;
    answerController.text = answers[currentIndex] ?? '';
    revealed = false;
    checked = false;
    exactMatch = null;
    editingQuestion = false;
  }

  int _findNextPending({int start = 0}) {
    if (questions.isEmpty) return -1;
    final safeStart = start.clamp(0, questions.length - 1).toInt();
    for (var index = safeStart; index < questions.length; index++) {
      if (!completedIndices.contains(index) && !skippedIndices.contains(index)) {
        return index;
      }
    }
    for (var index = 0; index < safeStart; index++) {
      if (!completedIndices.contains(index) && !skippedIndices.contains(index)) {
        return index;
      }
    }
    return -1;
  }

  void _answerChanged() {
    if (loading || currentQuestion == null) return;
    answers[currentIndex] = answerController.text;
    if (checked) {
      setState(() {
        checked = false;
        exactMatch = null;
      });
    }
    _scheduleSave();
  }

  void _questionChanged() {
    if (loading || !editingQuestion || currentQuestion == null) return;
    questions[currentIndex] = currentQuestion!.copyWith(
      question: questionController.text,
    );
    _scheduleSave();
  }

  void _scheduleSave() {
    saveDebounce?.cancel();
    saveDebounce = Timer(const Duration(milliseconds: 350), () {
      unawaited(_persistProgress());
    });
  }

  Future<void> _persistProgress() async {
    if (questions.isEmpty) return;
    try {
      await RecallSessionStorage.initialize();
      await RecallSessionStorage.save(
        sessionId: sessionId,
        missionId: widget.missionId,
        topic: widget.topic,
        notes: widget.notes,
        questions: questions.map((item) => item.toMap()).toList(),
        currentIndex: currentIndex < 0 ? 0 : currentIndex,
        answers: answers.map((key, value) => MapEntry(key.toString(), value)),
        completedIndices: completedIndices.toList()..sort(),
        skippedIndices: skippedIndices.toList()..sort(),
        warnings: warnings,
        courseId: widget.courseId,
        courseName: widget.courseName,
        courseCode: widget.courseCode,
      );
      CloudSync.queueSync();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Recall progress could not be saved. Keep this screen open and try again.')),
        );
      }
    }
  }

  Future<void> _checkFillBlank() async {
    final item = currentQuestion;
    if (item == null) return;
    if (answerController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add your answer first, or choose Again if you could not remember it.')),
      );
      return;
    }
    setState(() {
      checked = true;
      exactMatch = RecallAnswerAssessment.matchesAcceptedAnswer(
        answerController.text,
        item.acceptedAnswers.isEmpty ? [item.answer] : item.acceptedAnswers,
      );
    });
  }

  Future<void> _rate(String rating) async {
    final item = currentQuestion;
    if (item == null || busy) return;
    final response = answerController.text.trim();
    if (response.isEmpty && rating != 'Again') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Write what you remember, or choose Again if you could not recall it.')),
      );
      return;
    }

    saveDebounce?.cancel();
    setState(() => busy = true);
    try {
      await RecallStorage.initialize();
      await RecallStorage.save(
        missionId: widget.missionId,
        topic: widget.topic,
        question: questionController.text.trim(),
        answer: response,
        rating: rating,
        referenceAnswer: item.answer,
        source: item.source,
        questionType: item.type.name,
        keyConcepts: item.keyConcepts,
        acceptedAnswers: item.acceptedAnswers,
        recordId: '${sessionId}_${item.id}',
        courseId: widget.courseId,
        courseName: widget.courseName,
        courseCode: widget.courseCode,
      );
      answers[currentIndex] = response;
      completedIndices.add(currentIndex);
      skippedIndices.remove(currentIndex);
      final next = _findNextPending(start: currentIndex + 1);
      if (next >= 0) {
        currentIndex = next;
        _loadCurrentFields();
      } else {
        showSummary = true;
      }
      await _persistProgress();
      if (mounted) setState(() {});
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save this recall answer. Your current answer has been kept on this device; please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _skipQuestion() async {
    if (currentQuestion == null || busy) return;
    saveDebounce?.cancel();
    answers[currentIndex] = answerController.text;
    skippedIndices.add(currentIndex);
    final next = _findNextPending(start: currentIndex + 1);
    if (next >= 0) {
      currentIndex = next;
      _loadCurrentFields();
    } else {
      showSummary = true;
    }
    await _persistProgress();
    if (mounted) setState(() {});
  }

  Future<void> _reviewSkipped() async {
    if (skippedIndices.isEmpty) return;
    final next = skippedIndices.toList()..sort();
    final index = next.first;
    skippedIndices.remove(index);
    currentIndex = index;
    showSummary = false;
    _loadCurrentFields();
    await _persistProgress();
    if (mounted) setState(() {});
  }

  Future<void> _finishRecall() async {
    saveDebounce?.cancel();
    if (skippedIndices.isEmpty) {
      await RecallSessionStorage.initialize();
      await RecallSessionStorage.delete(sessionId);
      CloudSync.queueSync();
    } else {
      await _persistProgress();
    }
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _leaveForLater() async {
    saveDebounce?.cancel();
    await _persistProgress();
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _rephraseCurrent() async {
    final item = currentQuestion;
    if (item == null) return;
    final updated = LocalQuestionGenerator.rephrase(item);
    questions[currentIndex] = updated;
    questionController.text = updated.question;
    await _persistProgress();
    if (mounted) setState(() {});
  }

  Widget _warningCards() {
    if (warnings.isEmpty) return const SizedBox.shrink();
    return Column(
      children: [
        for (final warning in warnings)
          Card(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline),
                  const SizedBox(width: 8),
                  Expanded(child: Text(warning)),
                ],
              ),
            ),
          ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _referenceCard() {
    final item = currentQuestion;
    if (item == null) return const SizedBox.shrink();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Reference explanation from your notes',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            SelectableText(item.answer.isNotEmpty ? item.answer : item.source),
            if (item.keyConcepts.isNotEmpty) ...[
              const SizedBox(height: 14),
              const Text('Key ideas to compare', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [for (final concept in item.keyConcepts) Chip(label: Text(concept))],
              ),
              const SizedBox(height: 8),
              const Text('These are helpful prompts, not a rigid marking scheme. Different wording is welcome when the meaning is correct.'),
            ],
            if (item.type == RecallQuestionType.fillBlank) ...[
              const SizedBox(height: 8),
              const Text('This reference term is not a judgement of your overall understanding.'),
            ],
          ],
        ),
      ),
    );
  }

  Widget _fillBlankFeedback() {
    if (!checked) return const SizedBox.shrink();
    return Card(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(exactMatch == true ? Icons.check_circle_outline : Icons.info_outline),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                exactMatch == true
                    ? 'Your response matches an accepted term. Choose the rating that reflects how confident you felt.'
                    : 'This is not an exact match to the saved term. Compare it with your notes; an equivalent expression may still be correct. This is not an automatic wrong mark.',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryView() {
    final skipped = skippedIndices.length;
    final completed = completedIndices.length;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const SizedBox(height: 24),
        const Icon(Icons.auto_awesome, size: 48),
        const SizedBox(height: 16),
        Text('Good work. You have reached the end.', style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
        const SizedBox(height: 10),
        Text('$completed of ${questions.length} questions reviewed${skipped > 0 ? ' · $skipped skipped for later' : ''}.', textAlign: TextAlign.center),
        const SizedBox(height: 20),
        const Text('Your progress is saved. There are no grades or penalties for questions you chose to skip.', textAlign: TextAlign.center),
        const SizedBox(height: 24),
        if (skipped > 0) ...[
          FilledButton.icon(
            onPressed: busy ? null : _reviewSkipped,
            icon: const Icon(Icons.replay),
            label: Text('Review $skipped skipped question${skipped == 1 ? '' : 's'}'),
          ),
          const SizedBox(height: 8),
        ],
        OutlinedButton(
          onPressed: busy ? null : _finishRecall,
          child: Text(skipped > 0 ? 'Finish for now' : 'Finish recall'),
        ),
      ],
    );
  }

  Widget _emptyView() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _warningCards(),
        const SizedBox(height: 12),
        const Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Text('CampusOS could not find enough clear facts to create reliable questions. Your study notes are still saved. Add a definition, explanation or clear bullet points and try again.'),
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton(onPressed: _leaveForLater, child: const Text('Back to study workspace')),
      ],
    );
  }

  @override
  void dispose() {
    saveDebounce?.cancel();
    questionController.removeListener(_questionChanged);
    answerController.removeListener(_answerChanged);
    questionController.dispose();
    answerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && !busy && !loading) unawaited(_leaveForLater());
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Active Recall'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: busy || loading ? null : _leaveForLater,
          ),
          actions: [
            if (!loading && questions.isNotEmpty && !showSummary)
              TextButton(onPressed: busy ? null : _skipQuestion, child: const Text('Skip')),
          ],
        ),
        body: SafeArea(
          child: loading
              ? const Center(child: CircularProgressIndicator())
              : loadError != null
                  ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(loadError!, textAlign: TextAlign.center)))
                  : questions.isEmpty
                      ? _emptyView()
                      : showSummary
                          ? _summaryView()
                          : ListView(
                              padding: const EdgeInsets.all(20),
                              children: [
                                if (displayedCourseName.trim().isNotEmpty)
                                  Text('$displayedCourseName · $displayedCourseCode', style: Theme.of(context).textTheme.titleMedium),
                                Text(widget.topic.isEmpty ? 'Recall what you learned' : widget.topic, style: Theme.of(context).textTheme.titleLarge),
                                const SizedBox(height: 8),
                                const Text('No grades or pressure. Try remembering first, then compare with your notes.'),
                                const SizedBox(height: 16),
                                _warningCards(),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('Part ${(currentIndex ~/ 10) + 1} of ${(questions.length / 10).ceil()} · Question ${currentIndex + 1} of ${questions.length}', style: Theme.of(context).textTheme.labelLarge),
                                    Text('${completedIndices.length} reviewed', style: Theme.of(context).textTheme.labelMedium),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                LinearProgressIndicator(value: completedIndices.length / questions.length),
                                const SizedBox(height: 18),
                                Card(
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(isFillBlank ? 'FILL IN THE BLANK' : 'THEORY QUESTION', style: Theme.of(context).textTheme.labelLarge),
                                        const SizedBox(height: 10),
                                        TextField(
                                          controller: questionController,
                                          readOnly: !editingQuestion,
                                          minLines: 2,
                                          maxLines: 5,
                                          decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Recall question'),
                                        ),
                                        Align(
                                          alignment: Alignment.centerRight,
                                          child: Wrap(
                                            spacing: 4,
                                            children: [
                                              TextButton.icon(
                                                onPressed: busy ? null : () {
                                                  setState(() => editingQuestion = !editingQuestion);
                                                  if (!editingQuestion) unawaited(_persistProgress());
                                                },
                                                icon: Icon(editingQuestion ? Icons.check : Icons.edit_outlined),
                                                label: Text(editingQuestion ? 'Save wording' : 'Edit question'),
                                              ),
                                              TextButton.icon(
                                                onPressed: busy ? null : _rephraseCurrent,
                                                icon: const Icon(Icons.refresh),
                                                label: const Text('Try another wording'),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 14),
                                TextField(
                                  controller: answerController,
                                  minLines: 3,
                                  maxLines: 7,
                                  decoration: const InputDecoration(
                                    labelText: 'Your answer from memory',
                                    hintText: 'Write what you remember. Exact wording is not required.',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                                if (isFillBlank) ...[
                                  const SizedBox(height: 10),
                                  OutlinedButton.icon(
                                    onPressed: busy ? null : _checkFillBlank,
                                    icon: const Icon(Icons.fact_check_outlined),
                                    label: const Text('Compare with reference term'),
                                  ),
                                  _fillBlankFeedback(),
                                ],
                                const SizedBox(height: 10),
                                OutlinedButton.icon(
                                  onPressed: busy ? null : () => setState(() => revealed = !revealed),
                                  icon: Icon(revealed ? Icons.visibility_off : Icons.visibility),
                                  label: Text(revealed ? 'Hide reference notes' : 'Reveal reference notes'),
                                ),
                                if (revealed) _referenceCard(),
                                const SizedBox(height: 18),
                                Text('How did remembering feel?', style: Theme.of(context).textTheme.titleMedium),
                                const SizedBox(height: 6),
                                const Text('Choose what honestly describes your understanding. This guides your revision plan; it is not a grade.'),
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    for (final rating in ['Again', 'Hard', 'Good', 'Easy'])
                                      OutlinedButton(
                                        onPressed: busy ? null : () => _rate(rating),
                                        child: Text(rating),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                const Text('Again: I could not recall it yet. Hard: I remembered some of it. Good: I remembered most of it. Easy: I can explain it confidently.'),
                                const SizedBox(height: 12),
                                TextButton(onPressed: busy ? null : _leaveForLater, child: const Text('Maybe later')),
                              ],
                            ),
        ),
      ),
    );
  }
}
