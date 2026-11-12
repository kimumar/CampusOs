import 'package:flutter_test/flutter_test.dart';
// ignore: avoid_relative_lib_imports
import '../lib/services/recall_answer_assessment.dart';

void main() {
  test('normalizes case, punctuation, and repeated whitespace', () {
    expect(
      RecallAnswerAssessment.normalize('  Chemical,   ENERGY! '),
      'chemical energy',
    );
  });

  test('accepts an explicitly listed alternative answer', () {
    expect(
      RecallAnswerAssessment.matchesAcceptedAnswer(
        'CHEMICAL energy.',
        ['chemical energy', 'stored energy'],
      ),
      isTrue,
    );
  });

  test('does not treat an unlisted paraphrase as an exact fill-blank match', () {
    expect(
      RecallAnswerAssessment.matchesAcceptedAnswer(
        'energy stored in chemical bonds',
        ['chemical energy'],
      ),
      isFalse,
    );
  });

  test('does not match an empty response', () {
    expect(
      RecallAnswerAssessment.matchesAcceptedAnswer('   ', ['photosynthesis']),
      isFalse,
    );
  });
}
