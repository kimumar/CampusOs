import 'package:flutter/material.dart';
import '../services/local_question_generator.dart';
import 'recall_practice_screen.dart';

/// Compatibility route. Questions are practised directly in Active Recall;
/// there is no separate question-preview screen in the student flow.
class GeneratedQuestionsScreen extends StatelessWidget {
  const GeneratedQuestionsScreen({
    super.key,
    required this.missionId,
    required this.topic,
    required this.notes,
  });

  final String missionId;
  final String topic;
  final String notes;

  @override
  Widget build(BuildContext context) {
    final result = LocalQuestionGenerator.generateDetailed(notes, topic: topic);
    return RecallPracticeScreen(
      missionId: missionId,
      topic: topic,
      notes: notes,
      questions: result.questions,
      generationWarnings: result.warnings,
    );
  }
}
