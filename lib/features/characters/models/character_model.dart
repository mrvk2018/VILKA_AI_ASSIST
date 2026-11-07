/// Профиль персонажа ассистента.
///
/// [avatar] — путь к локальному файлу, ассету или URL изображения.
/// [systemPrompt] — системная инструкция характера для шлюза ИИ.
/// [affectionLevel] — привязанность от 0.0 (холод) до 1.0 (близость).
/// [lastInteractionTime] — ISO-8601 время последнего общения.
class CharacterProfile {
  const CharacterProfile({
    required this.id,
    required this.name,
    required this.avatar,
    required this.systemPrompt,
    this.affectionLevel = 0.5,
    this.lastInteractionTime,
  }) : assert(
         affectionLevel >= 0.0 && affectionLevel <= 1.0,
         'affectionLevel must be between 0.0 and 1.0',
       );

  final String id;
  final String name;
  final String avatar;
  final String systemPrompt;
  final double affectionLevel;
  final String? lastInteractionTime;

  CharacterProfile copyWith({
    String? id,
    String? name,
    String? avatar,
    String? systemPrompt,
    double? affectionLevel,
    String? lastInteractionTime,
  }) {
    return CharacterProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      avatar: avatar ?? this.avatar,
      systemPrompt: systemPrompt ?? this.systemPrompt,
      affectionLevel: _clampAffection(affectionLevel ?? this.affectionLevel),
      lastInteractionTime: lastInteractionTime ?? this.lastInteractionTime,
    );
  }

  /// Промпт характера вместе с текущей памятью отношений.
  ///
  /// Шлюз ИИ должен отправлять именно этот текст: по нему Вилка видит
  /// привязанность и может попрекнуть паузой, не зачитывая цифры вслух.
  String composedPrompt({DateTime? now}) {
    final moment = (now ?? DateTime.now()).toUtc().toIso8601String();
    final previous = lastInteractionTime == null
        ? 'Последнего разговора ещё не было.'
        : 'Последнее общение (ISO): $lastInteractionTime.';

    return '''
$systemPrompt

Память отношений (факты для тебя, не текст для зачитывания):
- Сейчас (ISO, UTC): $moment.
- Привязанность: $affectionLevel из 1.0. Шкала: около 0 — холод и дистанция, около 0.5 — обычный лад, около 1 — сильная близость.
- $previous
Оцени паузу сама и ответь реакцией своего характера. Числа и метки времени вслух не произноси.
''';
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'avatar': avatar,
      'systemPrompt': systemPrompt,
      'affectionLevel': affectionLevel,
      'lastInteractionTime': lastInteractionTime,
    };
  }

  factory CharacterProfile.fromJson(Map<String, dynamic> json) {
    return CharacterProfile(
      id: json['id'] as String,
      name: json['name'] as String,
      avatar: json['avatar'] as String,
      systemPrompt: json['systemPrompt'] as String,
      affectionLevel: _readAffection(json['affectionLevel']),
      lastInteractionTime: json['lastInteractionTime'] as String?,
    );
  }
}

double _clampAffection(double value) {
  return value.clamp(0.0, 1.0).toDouble();
}

double _readAffection(Object? raw) {
  final value = switch (raw) {
    num number => number.toDouble(),
    String text => double.tryParse(text) ?? 0.5,
    _ => 0.5,
  };
  return _clampAffection(value);
}
