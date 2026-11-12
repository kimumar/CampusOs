/// Offline, deterministic recall generation. This service never calls a network
/// or paid AI API. Every generated answer is traceable to the supplied notes.
enum RecallQuestionType { theory, fillBlank }

class GeneratedRecallQuestion {
  const GeneratedRecallQuestion({
    required this.id,
    required this.type,
    required this.question,
    required this.answer,
    required this.source,
    this.keyConcepts = const [],
    this.acceptedAnswers = const [],
  });

  final String id;
  final RecallQuestionType type;
  final String question;
  final String answer;
  final String source;
  final List<String> keyConcepts;
  final List<String> acceptedAnswers;

  GeneratedRecallQuestion copyWith({
    String? question,
    String? answer,
    String? source,
    List<String>? keyConcepts,
    List<String>? acceptedAnswers,
  }) {
    return GeneratedRecallQuestion(
      id: id,
      type: type,
      question: question ?? this.question,
      answer: answer ?? this.answer,
      source: source ?? this.source,
      keyConcepts: keyConcepts ?? this.keyConcepts,
      acceptedAnswers: acceptedAnswers ?? this.acceptedAnswers,
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'id': id,
        'type': type.name,
        'question': question,
        'answer': answer,
        'source': source,
        'key_concepts': keyConcepts,
        'accepted_answers': acceptedAnswers,
      };

  factory GeneratedRecallQuestion.fromMap(Map<dynamic, dynamic> map) {
    final typeName = map['type']?.toString();
    final type = typeName == RecallQuestionType.fillBlank.name
        ? RecallQuestionType.fillBlank
        : RecallQuestionType.theory;
    return GeneratedRecallQuestion(
      id: map['id']?.toString() ?? 'restored_question',
      type: type,
      question: map['question']?.toString() ?? '',
      answer: map['answer']?.toString() ?? '',
      source: map['source']?.toString() ?? '',
      keyConcepts: _stringList(map['key_concepts']),
      acceptedAnswers: _stringList(map['accepted_answers']),
    );
  }

  static List<String> _stringList(dynamic value) {
    if (value is! List) return const [];
    return value.map((item) => item.toString()).where((item) => item.isNotEmpty).toList();
  }
}

class QuestionGenerationResult {
  const QuestionGenerationResult({
    required this.questions,
    required this.warnings,
    required this.factCount,
  });

  final List<GeneratedRecallQuestion> questions;
  final List<String> warnings;
  final int factCount;
}

class LocalQuestionGenerator {
  LocalQuestionGenerator._();

  /// Compatibility method retained for existing screens and tests.
  static List<GeneratedRecallQuestion> generate(
    String raw, {
    String topic = '',
    String objective = '',
  }) {
    return generateDetailed(raw, topic: topic, objective: objective).questions;
  }

  /// Generates as many reliable questions as the notes support. Short notes,
  /// headings and bullet lists are valid inputs; sentence count is not a gate.
  static QuestionGenerationResult generateDetailed(
    String raw, {
    String topic = '',
    String objective = '',
  }) {
    final warnings = <String>[];
    final parsed = _parseNotes(raw, topic: topic);
    warnings.addAll(parsed.warnings);

    final theory = <GeneratedRecallQuestion>[];
    final blanks = <GeneratedRecallQuestion>[];
    final seenTheory = <String>{};
    final seenBlanks = <String>{};
    var sequence = 0;
    var hasDefinition = false;

    void addTheory({
      required String prompt,
      required String answer,
      required String source,
      required List<String> concepts,
    }) {
      final key = _normalizeKey(prompt);
      if (key.isEmpty || answer.trim().isEmpty || !seenTheory.add(key)) return;
      sequence++;
      theory.add(GeneratedRecallQuestion(
        id: 'theory_$sequence',
        type: RecallQuestionType.theory,
        question: prompt,
        answer: answer,
        source: source,
        keyConcepts: concepts,
      ));
    }

    void addBlank({
      required String prompt,
      required String answer,
      required String source,
      required List<String> accepted,
    }) {
      final key = _normalizeKey(prompt);
      if (key.isEmpty || answer.trim().isEmpty || !seenBlanks.add(key)) return;
      sequence++;
      blanks.add(GeneratedRecallQuestion(
        id: 'blank_$sequence',
        type: RecallQuestionType.fillBlank,
        question: prompt,
        answer: answer,
        source: source,
        keyConcepts: [answer],
        acceptedAnswers: accepted.isEmpty ? [answer] : accepted,
      ));
    }

    for (final list in parsed.lists) {
      if (list.items.length < 2 || list.isAmbiguous) continue;
      final heading = list.heading.toLowerCase();
      final items = list.items;
      final answer = items.join(', ');
      final prompt = _listPrompt(list.heading);
      addTheory(
        prompt: prompt,
        answer: answer,
        source: list.source,
        concepts: items,
      );

      if (items.length >= 3) {
        final firstItems = items.take(items.length - 1).toList();
        final missing = items.last;
        final prefix = heading.contains('level') || heading.contains('tier')
            ? 'The levels of government listed include '
            : heading.contains('form') || _looksLikeGovernmentForms(items)
                ? 'The forms of government named include '
                : heading.contains('arm') || heading.contains('branch')
                    ? 'The arms of government listed include '
                    : 'One item listed under ${list.heading} is ';
        final blankPrompt = prefix.endsWith(' is ')
            ? '${prefix}______.'
            : '$prefix${firstItems.join(', ')} and ______.';
        addBlank(
          prompt: blankPrompt,
          answer: missing,
          source: list.source,
          accepted: _equivalentListAnswers(missing),
        );
      } else if (items.length == 2) {
        final missing = items.last;
        addBlank(
          prompt: 'One other item listed under ${list.heading} is ______.',
          answer: missing,
          source: list.source,
          accepted: _equivalentListAnswers(missing),
        );
      }
    }

    final enumeratedSources = parsed.lists.map((list) => _normalizeKey(list.source)).toSet();
    for (final fact in parsed.facts) {
      final sentence = fact.text;
      if (enumeratedSources.contains(_normalizeKey(sentence))) continue;
      if (_hasUnclearPronoun(sentence)) {
        warnings.add('One note contains an unclear reference such as "it". Clarify what it refers to before making a question from that sentence.');
        continue;
      }

      final definition = _definition.firstMatch(sentence);
      final passiveStart = definition != null &&
          _passiveOpeners.contains(definition.group(2)!.trim().split(' ').first.toLowerCase());
      String prompt;
      if (definition != null && !passiveStart) {
        hasDefinition = true;
        final subject = definition.group(1)!.trim();
        prompt = 'What is $subject?';
      } else if (RegExp(r'\bnation\s+is\s+(?:run|governed)\s+by\b', caseSensitive: false).hasMatch(sentence)) {
        prompt = 'What does this note say about how a nation is run?';
      } else {
        final focus = _focusPhrase(sentence);
        prompt = focus.isEmpty
            ? 'Explain the main idea in this note in your own words.'
            : 'Explain this point from your notes: "$focus..."';
      }
      addTheory(
        prompt: prompt,
        answer: sentence,
        source: sentence,
        concepts: _extractKeyConcepts(sentence),
      );

      final candidates = _meaningfulWords(sentence);
      if (candidates.isNotEmpty && sentence.length >= 24) {
        final term = candidates.first;
        final start = sentence.toLowerCase().indexOf(term.toLowerCase());
        if (start >= 0) {
          final blank = '${sentence.substring(0, start)}______${sentence.substring(start + term.length)}';
          addBlank(
            prompt: 'Complete: $blank',
            answer: term,
            source: sentence,
            accepted: _equivalentListAnswers(term),
          );
        }
      }
    }

    // If a learning objective asks for a definition but the notes do not
    // contain one, explain the gap instead of inventing a reference answer.
    if (objective.trim().isNotEmpty &&
        RegExp(r'\b(what is|define|meaning of|explain)\b', caseSensitive: false).hasMatch(objective) &&
        !hasDefinition) {
      warnings.add('Your learning objective asks for an explanation or definition, but the notes do not contain enough clear information to support one yet.');
    }

    if (theory.length + blanks.length > 100) {
      warnings.add('This note set supports more than 100 questions. The first 100 distinct questions are ready; split the remaining material into another topic session for full coverage.');
    }
    final questions = _balanceQuestions(theory, blanks);
    if (questions.isEmpty && warnings.isEmpty) {
      warnings.add('There are not enough distinct, readable facts to create a reliable question yet. Add a definition, explanation or a few clear bullet points and try again.');
    }

    return QuestionGenerationResult(
      questions: questions,
      warnings: _unique(warnings),
      factCount: parsed.facts.length + parsed.lists.length,
    );
  }

  /// Produces an alternate prompt while preserving the same source and answer.
  static GeneratedRecallQuestion rephrase(GeneratedRecallQuestion item) {
    if (item.type == RecallQuestionType.fillBlank) {
      return item.copyWith(
        question: item.question.startsWith('Complete: ')
            ? item.question.replaceFirst('Complete: ', 'Fill in the missing term: ')
            : 'Fill in the missing term: ${item.question}',
      );
    }
    final current = item.question;
    if (current.startsWith('What is ')) {
      final subject = current.substring(8).replaceFirst(RegExp(r'\?$'), '').trim();
      return item.copyWith(question: 'Explain $subject in your own words.');
    }
    if (current.startsWith('Explain what you understand by ')) {
      final subject = current.substring('Explain what you understand by '.length).replaceFirst(RegExp(r'\.$'), '').trim();
      return item.copyWith(question: 'Describe $subject in your own words.');
    }
    if (current.startsWith('Which forms of government')) {
      return item.copyWith(question: 'Name the forms of government included in your notes.');
    }
    if (current.startsWith('Name the levels of government')) {
      return item.copyWith(question: 'Which government levels are listed in your notes?');
    }
    if (current.startsWith('Name the arms or branches')) {
      return item.copyWith(question: 'Which arms or branches of government are named in your notes?');
    }
    if (current.startsWith('Which items are listed under ')) {
      final heading = current.substring('Which items are listed under '.length).replaceFirst(RegExp(r'\?$'), '').trim();
      return item.copyWith(question: 'Recall the items listed under $heading.');
    }
    return item.copyWith(question: 'Describe the main idea in this note in your own words.');
  }

  static List<GeneratedRecallQuestion> _balanceQuestions(
    List<GeneratedRecallQuestion> theory,
    List<GeneratedRecallQuestion> blanks,
  ) {
    final total = theory.length + blanks.length;
    if (total == 0) return const [];
    final limit = total > 100 ? 100 : total;
    final theoryTarget = (limit * 0.6).ceil();
    final selectedTheory = theory.take(theoryTarget).toList();
    final selectedBlanks = blanks.take(limit - selectedTheory.length).toList();
    final remaining = limit - selectedTheory.length - selectedBlanks.length;
    if (remaining > 0) {
      selectedTheory.addAll(theory.skip(selectedTheory.length).take(remaining));
    }
    final result = <GeneratedRecallQuestion>[];
    final maxLength = selectedTheory.length > selectedBlanks.length
        ? selectedTheory.length
        : selectedBlanks.length;
    for (var i = 0; i < maxLength; i++) {
      if (i < selectedTheory.length) result.add(selectedTheory[i]);
      if (i < selectedBlanks.length) result.add(selectedBlanks[i]);
    }
    return result;
  }

  static _ParsedNotes _parseNotes(String raw, {required String topic}) {
    final facts = <_NoteFact>[];
    final lists = <_NoteList>[];
    final warnings = <String>[];
    String? heading;
    final pendingItems = <String>[];
    final orphanItems = <String>[];

    void flushList() {
      if (heading != null && pendingItems.length >= 2) {
        final normalizedHeading = heading!.trim();
        final normalizedItems = _unique(pendingItems.map(_cleanItem).where((e) => e.isNotEmpty).toList());
        final mismatch = _headingMismatch(normalizedHeading, normalizedItems);
        if (mismatch != null) {
          warnings.add(mismatch);
          lists.add(_NoteList(
            heading: normalizedHeading,
            items: normalizedItems,
            source: '$normalizedHeading: ${normalizedItems.join('; ')}',
            isAmbiguous: true,
          ));
        } else {
          lists.add(_NoteList(
            heading: normalizedHeading,
            items: normalizedItems,
            source: '$normalizedHeading: ${normalizedItems.join('; ')}',
            isAmbiguous: false,
          ));
        }
      }
      heading = null;
      pendingItems.clear();
    }

    final lines = raw.replaceAll('\r', '').split('\n');
    for (final rawLine in lines) {
      var line = rawLine.trim();
      if (line.isEmpty) continue;
      line = line.replaceFirst(RegExp(r'^(?:[•▪◦‣*-]|\d+[.)])\s*'), '').trim();
      if (line.isEmpty) continue;

      if (_isHeading(line)) {
        flushList();
        heading = line.replaceFirst(RegExp(r':$'), '').trim();
        continue;
      }

      if (heading != null && _looksLikeListItem(line)) {
        pendingItems.add(line);
        continue;
      }

      if (heading == null && _looksLikeListItem(line)) {
        orphanItems.add(line);
        continue;
      }

      if (heading != null) flushList();

      final pieces = line.split(RegExp(r'(?<=[.!?;])\s+'));
      for (final piece in pieces) {
        final clean = piece.trim();
        if (clean.length < 12) continue;
        facts.add(_NoteFact(clean));
        final enumeration = _extractEnumeration(clean, topic);
        if (enumeration != null && enumeration.items.length >= 2) {
          final mismatch = _headingMismatch(enumeration.heading, enumeration.items);
          if (mismatch != null) {
            warnings.add(mismatch);
          } else {
            lists.add(enumeration);
          }
        }
      }
    }
    flushList();

    // Short standalone lines may form a compact list even without a heading.
    final distinctOrphans = _unique(orphanItems.map(_cleanItem));
    if (distinctOrphans.length >= 2) {
      lists.add(_NoteList(
        heading: topic.trim().isEmpty ? 'Items in your notes' : topic.trim(),
        items: distinctOrphans,
        source: distinctOrphans.join('; '),
        isAmbiguous: false,
      ));
    }

    final uniqueFacts = <String>{};
    final dedupedFacts = facts.where((fact) => uniqueFacts.add(_normalizeKey(fact.text))).toList();
    final uniqueLists = <String>{};
    final dedupedLists = lists.where((list) => uniqueLists.add(_normalizeKey('${list.heading}|${list.items.join('|')}'))).toList();
    return _ParsedNotes(dedupedFacts, dedupedLists, _unique(warnings));
  }

  static _NoteList? _extractEnumeration(String sentence, String topic) {
    final match = RegExp(
      r'\b(?:can\s+(?:be\s+)?|include(?:s|d)?\s+|such\s+as\s+|forms?\s+(?:of\s+government\s+)?(?:are|include)\s+|types?\s+(?:are|include)\s+)([^.!?]+)',
      caseSensitive: false,
    ).firstMatch(sentence);
    if (match == null) return null;
    final rawList = match.group(1)!
        .replaceAll(RegExp(r'\s*\band\s+so\s+on\b', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s*\betc\.?\b', caseSensitive: false), '')
        .trim();
    final items = rawList
        .split(RegExp(r',|\band\b', caseSensitive: false))
        .map(_cleanItem)
        .where((item) => item.length >= 3 && item.split(' ').length <= 5)
        .toList();
    final distinct = _unique(items);
    if (distinct.length < 2) return null;
    final governmentTerms = {'democratic', 'monarchical', 'theocratic', 'autocratic', 'oligarchic', 'republican'};
    final isGovernmentForms = topic.toLowerCase().contains('government') &&
        distinct.any((item) => governmentTerms.contains(item.toLowerCase()));
    final heading = isGovernmentForms ? 'Forms of government' : 'Items mentioned in your notes';
    return _NoteList(
      heading: heading,
      items: distinct,
      source: sentence,
      isAmbiguous: false,
    );
  }

  static String? _headingMismatch(String heading, List<String> items) {
    final lowerHeading = heading.toLowerCase();
    final lowerItems = items.map((item) => item.toLowerCase()).toSet();
    final hasFederalLevels = lowerItems.any((item) => item.contains('federal')) &&
        lowerItems.any((item) => item.contains('state')) &&
        lowerItems.any((item) => item.contains('local'));
    final hasThreeArms = lowerItems.any((item) => item.contains('legislative')) &&
        lowerItems.any((item) => item.contains('executive')) &&
        lowerItems.any((item) => item.contains('judicial'));
    if (lowerHeading.contains('arm') && hasFederalLevels) {
      return 'Check the heading "${heading.trim()}": Federal, State and Local government are commonly described as levels or tiers of government, not the three arms. Confirm the heading before practising this list.';
    }
    if ((lowerHeading.contains('level') || lowerHeading.contains('tier')) && hasThreeArms) {
      return 'Check the heading "${heading.trim()}": Legislative, Executive and Judicial are commonly described as the arms of government, not levels or tiers. Confirm the heading before practising this list.';
    }
    return null;
  }

  static bool _isHeading(String line) {
    final lower = line.toLowerCase().replaceFirst(RegExp(r':$'), '').trim();
    if (line.endsWith(':')) return true;
    if (line.length > 70 || RegExp(r'[.!?]').hasMatch(line)) return false;
    return RegExp(
      r'\b(arms?|branches|levels?|tiers?|forms?|types?|categories|components|parts|functions|features|characteristics|advantages|disadvantages|causes|effects|stages|steps|elements|examples|importance|principles|sources|roles|purposes)\b',
    ).hasMatch(lower);
  }

  static bool _looksLikeListItem(String line) {
    final candidate = line.replaceFirst(RegExp(r'[.!?;:]+$'), '').trim();
    if (candidate.length > 85 || candidate.isEmpty) return false;
    final words = candidate.split(RegExp(r'\s+'));
    if (words.length > 8) return false;
    return !RegExp(r'\b(is|are|was|were|means|because|when|causes|leads|results|explains)\b', caseSensitive: false).hasMatch(candidate);
  }

  static String _listPrompt(String heading) {
    final lower = heading.toLowerCase();
    if (lower.contains('level') || lower.contains('tier')) {
      return 'Name the levels of government listed in your notes.';
    }
    if (lower.contains('form')) {
      return 'Which forms of government are mentioned in your notes?';
    }
    if (lower.contains('arm') || lower.contains('branch')) {
      return 'Name the arms or branches listed under $heading.';
    }
    return 'Which items are listed under $heading?';
  }

  static bool _looksLikeGovernmentForms(List<String> items) {
    const forms = {'democratic', 'monarchical', 'theocratic', 'autocratic', 'oligarchic', 'republican'};
    return items.any((item) => forms.contains(item.toLowerCase()));
  }

  static String _cleanItem(String value) => value
      .replaceFirst(RegExp(r'^[,;:.!?\s]+'), '')
      .replaceFirst(RegExp(r'[,;:.!?\s]+$'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  static String _normalizeKey(String value) => value
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  static String _focusPhrase(String sentence) {
    final words = sentence.split(RegExp(r'\s+'));
    final filtered = words.where((word) => !_stopWords.contains(_cleanItem(word).toLowerCase())).toList();
    return filtered.take(6).join(' ').replaceAll(RegExp(r'[,;:.!?]+$'), '').trim();
  }

  static List<String> _extractKeyConcepts(String sentence) {
    final result = <String>[];
    final seen = <String>{};
    for (final match in RegExp(r'\b[A-Za-z][A-Za-z-]{3,}\b').allMatches(sentence)) {
      final word = match.group(0)!;
      final key = word.toLowerCase();
      if (_stopWords.contains(key) || !seen.add(key)) continue;
      result.add(word);
      if (result.length == 6) break;
    }
    return result;
  }

  static List<String> _meaningfulWords(String sentence) {
    final words = RegExp(r'\b[A-Za-z][A-Za-z-]{4,}\b')
        .allMatches(sentence)
        .map((match) => match.group(0)!)
        .where((word) => !_stopWords.contains(word.toLowerCase()))
        .toList();
    words.sort((a, b) => b.length.compareTo(a.length));
    return words;
  }

  static bool _hasUnclearPronoun(String sentence) {
    final lower = sentence.toLowerCase();
    return RegExp(r'\b(it|they|them)\s+(?:is|are|was|were|can|could|may|will|does|do|has|have)\b')
        .hasMatch(lower) && lower.length < 180;
  }

  static List<String> _equivalentListAnswers(String answer) {
    final cleaned = _cleanItem(answer);
    final result = <String>{cleaned};
    if (cleaned.toLowerCase().endsWith(' government')) {
      result.add(cleaned.substring(0, cleaned.length - ' government'.length).trim());
    }
    return result.where((item) => item.isNotEmpty).toList();
  }

  static List<String> _unique(Iterable<String> values) {
    final seen = <String>{};
    final result = <String>[];
    for (final value in values) {
      final clean = value.trim();
      final key = _normalizeKey(clean);
      if (clean.isNotEmpty && seen.add(key)) result.add(clean);
    }
    return result;
  }

  static final _definition = RegExp(
    r'^(.{1,70}?)\s+(?:is|are|means|refers to|is defined as)\s+(.{4,})$',
    caseSensitive: false,
  );

  static const _passiveOpeners = <String>{
    'run', 'governed', 'made', 'used', 'found', 'located', 'called', 'known', 'controlled',
  };

  static const _stopWords = <String>{
    'because', 'before', 'during', 'through', 'between', 'without', 'within',
    'which', 'where', 'these', 'those', 'therefore', 'another', 'different',
    'important', 'usually', 'example', 'including', 'however', 'process',
    'student', 'students', 'their', 'there', 'green', 'from', 'that', 'this',
    'with', 'into', 'when', 'what', 'than', 'then', 'also', 'such', 'about',
    'your', 'notes', 'note', 'under', 'among', 'have', 'has', 'were', 'will',
    'would', 'could', 'should', 'them', 'they', 'been', 'being', 'just',
  };
}

class _NoteFact {
  const _NoteFact(this.text);
  final String text;
}

class _NoteList {
  const _NoteList({
    required this.heading,
    required this.items,
    required this.source,
    required this.isAmbiguous,
  });
  final String heading;
  final List<String> items;
  final String source;
  final bool isAmbiguous;
}

class _ParsedNotes {
  const _ParsedNotes(this.facts, this.lists, this.warnings);
  final List<_NoteFact> facts;
  final List<_NoteList> lists;
  final List<String> warnings;
}
