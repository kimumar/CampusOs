import 'package:flutter_test/flutter_test.dart';
// ignore: avoid_relative_lib_imports
import '../lib/services/local_question_generator.dart';

void main() {
  test('generates adaptive questions from detailed paragraph notes', () {
    const notes = 'Photosynthesis is the process by which green plants convert sunlight into chemical energy. '
        'Chlorophyll is a green pigment found in plant cells that absorbs light during photosynthesis. '
        'Respiration is the chemical process through which living cells release stored energy from nutrients. '
        'Evaporation causes liquid water molecules to change into gas when sufficient heat is supplied.';

    final result = LocalQuestionGenerator.generateDetailed(notes, topic: 'Biology');
    expect(result.questions.length, greaterThan(5));
    expect(result.questions.length, lessThanOrEqualTo(100));
    expect(result.questions.any((q) => q.type == RecallQuestionType.theory), isTrue);
    expect(result.questions.any((q) => q.type == RecallQuestionType.fillBlank), isTrue);
    expect(result.questions.every((q) => q.source.isNotEmpty && q.answer.isNotEmpty), isTrue);
    expect(result.questions.where((q) => q.type == RecallQuestionType.theory)
        .every((q) => q.keyConcepts.isNotEmpty), isTrue);
    expect(result.questions.where((q) => q.type == RecallQuestionType.fillBlank)
        .every((q) => q.acceptedAnswers.isNotEmpty), isTrue);
  });

  test('generates from short bullet lists without requiring three sentences', () {
    const notes = '''
Forms of government
- Democratic
- Monarchical
- Theocratic
''';
    final result = LocalQuestionGenerator.generateDetailed(notes, topic: 'Government');
    expect(result.questions.length, 2);
    expect(result.questions.any((q) => q.type == RecallQuestionType.theory), isTrue);
    expect(result.questions.any((q) => q.type == RecallQuestionType.fillBlank), isTrue);
    expect(result.questions.every((q) => q.source.isNotEmpty), isTrue);
  });

  test('supports numbered lists and list items ending with punctuation', () {
    const notes = '''
Levels of government:
1. Federal government.
2. State government.
3. Local government.
''';
    final result = LocalQuestionGenerator.generateDetailed(notes, topic: 'Government');
    expect(result.questions.length, 2);
    expect(result.questions.first.question.toLowerCase(), contains('levels of government'));
    expect(result.questions.any((q) => q.type == RecallQuestionType.fillBlank), isTrue);
  });

  test('adapts question quantity to the number of reliable facts', () {
    const oneFact = 'Photosynthesis is the process by which plants convert light into chemical energy.';
    const manyFacts = 'Photosynthesis is the process by which plants convert light into chemical energy. '
        'Chlorophyll is the green pigment that absorbs light energy. '
        'Respiration is the process by which cells release energy from food. '
        'Evaporation changes liquid water into water vapour. '
        'Condensation changes water vapour into liquid droplets.';

    final small = LocalQuestionGenerator.generateDetailed(oneFact);
    final larger = LocalQuestionGenerator.generateDetailed(manyFacts);
    expect(small.questions.length, greaterThan(0));
    expect(small.questions.length, lessThan(5));
    expect(larger.questions.length, greaterThan(small.questions.length));
  });

  test('flags a likely government heading mismatch instead of reinforcing it', () {
    const notes = '''
A nation is run by it, it can democratic, monarchical, theocratic and so on.

Arms of government
Federal government
State government
Local government
''';
    final result = LocalQuestionGenerator.generateDetailed(
      notes,
      topic: 'Government',
      objective: 'What is government?',
    );

    expect(result.questions.length, 2);
    expect(result.questions.every((q) => !q.source.contains('Federal government:')), isTrue);
    expect(result.warnings.any((warning) => warning.contains('levels or tiers')), isTrue);
    expect(result.warnings.any((warning) => warning.contains('learning objective')), isTrue);
  });

  test('does not invent questions from an empty or vague note', () {
    expect(LocalQuestionGenerator.generateDetailed('Short note.').questions, isEmpty);
    expect(LocalQuestionGenerator.generateDetailed('Government').questions, isEmpty);
  });

  test('does not create duplicate questions from repeated facts', () {
    const notes = 'Photosynthesis is the process by which plants convert sunlight into chemical energy. '
        'Photosynthesis is the process by which plants convert sunlight into chemical energy.';
    final result = LocalQuestionGenerator.generateDetailed(notes);
    final prompts = result.questions.map((q) => q.question.toLowerCase()).toSet();
    expect(prompts.length, result.questions.length);
  });

  test('serializes generated questions for safe recall-session resume', () {
    const original = GeneratedRecallQuestion(
      id: 'q1',
      type: RecallQuestionType.theory,
      question: 'What is photosynthesis?',
      answer: 'Plants convert light into chemical energy.',
      source: 'Photosynthesis is the process by which plants convert light into chemical energy.',
      keyConcepts: ['plants', 'light', 'energy'],
    );
    final restored = GeneratedRecallQuestion.fromMap(original.toMap());
    expect(restored.id, original.id);
    expect(restored.type, original.type);
    expect(restored.question, original.question);
    expect(restored.answer, original.answer);
    expect(restored.keyConcepts, original.keyConcepts);
  });
}
