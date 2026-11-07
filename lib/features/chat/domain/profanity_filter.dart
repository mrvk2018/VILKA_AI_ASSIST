/// Локальный разбор реплики пользователя.
///
/// [hasProfanity] и [isAggressive] независимы: мат без наезда и крик без мата
/// возможны одновременно. [isNeutral] — это отсутствие обоих признаков.
final class ChatTone {
  const ChatTone({required this.hasProfanity, required this.isAggressive});

  final bool hasProfanity;
  final bool isAggressive;

  bool get isNeutral => !hasProfanity && !isAggressive;

  @override
  bool operator ==(Object other) {
    return other is ChatTone &&
        other.hasProfanity == hasProfanity &&
        other.isAggressive == isAggressive;
  }

  @override
  int get hashCode => Object.hash(hasProfanity, isAggressive);

  @override
  String toString() {
    return 'ChatTone(hasProfanity: $hasProfanity, isAggressive: $isAggressive)';
  }
}

/// Быстрый локальный фильтр мата и агрессивного тона.
///
/// Это эвристика по корням и отдельным словам, не полный словарь.
final class ProfanityFilter {
  const ProfanityFilter();

  ChatTone analyze(String text) {
    final shouting = _isShouting(text);
    final normalized = _deobfuscate(_normalize(text));
    return ChatTone(
      hasProfanity: _profanity.hasMatch(normalized),
      isAggressive: shouting || _aggressive.hasMatch(normalized),
    );
  }
}

String _normalize(String text) {
  return text.toLowerCase().replaceAll('ё', 'е');
}

/// Склеивает только нарочно разбитые буквы: «х.у.й», но не соседние слова.
String _deobfuscate(String normalized) {
  return normalized.replaceAllMapped(_splitLetters, (match) {
    return match.group(0)!.replaceAll(_separators, '');
  });
}

bool _isShouting(String text) {
  var letters = 0;
  var uppercase = 0;
  for (final rune in text.runes) {
    final char = String.fromCharCode(rune);
    final lower = char.toLowerCase();
    final upper = char.toUpperCase();
    if (lower == upper) continue;
    letters++;
    if (char == upper) uppercase++;
  }
  if (letters < 5) return false;
  return uppercase / letters >= 0.65;
}

final RegExp _splitLetters = RegExp(
  r'(?<![а-я])(?:[а-я][\s.\-_*]+){2,}[а-я](?![а-я])',
);
final RegExp _separators = RegExp(r'[\s.\-_*]+');

final RegExp _profanity = RegExp(
  '(?:^|[^а-я])(?:${_profanityStems.join('|')})',
);

const List<String> _profanityStems = [
  r'(?:на|по|от|за|про|при|под|раз|вы|до|о|а|не)?ху(?:й|я|ю|е|и|ли(?!ган))',
  r'(?:за|от|рас|раз|вы|по|на|при|про|пере|о|у|с)?пизд',
  r'(?:долбо|за|вы|на|про|по|до|пере|раз|под|от|об|о|у|вз)?[ъь]?еб(?:а|л|н|у|ы|е|т|с|о)?',
  r'бля(?!х)(?:д|т)?',
  r'сук(?:а|и|у|е|о)',
  r'пид(?:ор|ар|р|ас)',
  r'муд(?:ак|ач|ил|о|а)',
  r'залуп',
  r'манда(?!рин|т)',
  r'(?:за|на|по|у|вы)?дроч',
  r'жоп',
  r'гондон',
  r'шлюх',
  r'хер(?!сон|уви)',
];

final RegExp _aggressive = RegExp(
  '(?:^|[^а-я])(?:${_aggressiveStems.join('|')})',
);

const List<String> _aggressiveStems = [
  r'слыш(?:ь)?(?![а-я])',
  r'заткни',
  r'задолбал',
  r'бесишь',
  r'урод',
  r'твар[ьие]',
  r'дебил',
  r'идиот',
  r'дурак',
  r'дура(?![а-я])',
  r'туп(?:ой|ая|ые|ое)',
  r'мраз[ьи]',
  r'чмо(?![а-я])',
  r'скотин',
  r'сволоч',
  r'оборзел',
  r'офигел',
  r'охренел',
  r'пошел(?:а|и)?\s+отсюда',
  r'иди\s+отсюда',
  r'ты\s+(?:че|чо|кто|вообще|оборзел|офигел|охренел)',
];
