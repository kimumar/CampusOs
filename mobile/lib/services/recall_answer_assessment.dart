/// Conservative, offline answer matching for fill-in-the-blank questions.
/// This is not a semantic grader. Theory answers are always self-assessed.
class RecallAnswerAssessment {
  RecallAnswerAssessment._();

  static String normalize(String value) {
    var normalized = value.toLowerCase();
    const punctuation = <String>[
      '.', ',', ';', ':', '!', '?', '(', ')', '[', ']', '{', '}',
      '"', "'", '“', '”', '‘', '’', '-', '–', '—', '/',
    ];
    for (final mark in punctuation) {
      normalized = normalized.replaceAll(mark, ' ');
    }
    return normalized.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static bool matchesAcceptedAnswer(
    String response,
    Iterable<String> acceptedAnswers,
  ) {
    final candidate = normalize(response);
    if (candidate.isEmpty) return false;
    return acceptedAnswers.any((accepted) {
      final expected = normalize(accepted);
      return expected.isNotEmpty && candidate == expected;
    });
  }
}
