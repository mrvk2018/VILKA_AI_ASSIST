import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/app_constants.dart';
import '../../characters/domain/characters_service.dart';
import '../../characters/models/character_model.dart';
import '../../chat/domain/ai_gateway_service.dart';
import '../../voice/services/tts_service.dart';
import '../models/initiative_alarm_model.dart';

/// Текстовая симуляция локального push-уведомления.
final class InitiativeNotice {
  const InitiativeNotice({
    required this.characterId,
    required this.title,
    required this.body,
  });

  final String characterId;
  final String title;
  final String body;
}

/// Результат сработавшего будильника: реплика уже передана в озвучку.
final class InitiativeSpeech {
  const InitiativeSpeech({
    required this.alarm,
    required this.characterId,
    required this.text,
    required this.model,
  });

  final InitiativeAlarm alarm;
  final String characterId;
  final String text;
  final String model;
}

/// Будильники инициативы и проверка долгого молчания.
///
/// Фонового изолята здесь нет: [triggerAlarmNow] имитирует срабатывание,
/// которое позже вызовет системный планировщик.
final class InitiativeSchedulerService {
  InitiativeSchedulerService({
    required this.preferences,
    required this.characters,
    required this.gateway,
    required this.voice,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final SharedPreferences preferences;
  final CharactersService characters;
  final AiGateway gateway;
  final TtsService voice;
  final DateTime Function() _now;

  static const Duration silenceLimit = Duration(hours: 12);

  static Future<InitiativeSchedulerService> open({
    required CharactersService characters,
    required AiGateway gateway,
    required TtsService voice,
    DateTime Function()? now,
  }) async {
    final preferences = await SharedPreferences.getInstance();
    return InitiativeSchedulerService(
      preferences: preferences,
      characters: characters,
      gateway: gateway,
      voice: voice,
      now: now,
    );
  }

  List<InitiativeAlarm> loadAlarms() {
    final raw = preferences.getString(AppConstants.initiativeAlarmsKey);
    if (raw == null || raw.isEmpty) return const [];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      final alarms = <InitiativeAlarm>[];
      for (final item in decoded) {
        if (item is! Map) continue;
        try {
          alarms.add(InitiativeAlarm.fromJson(Map<String, dynamic>.from(item)));
        } on FormatException {
          continue;
        }
      }
      return alarms;
    } on FormatException {
      return const [];
    }
  }

  Future<void> saveAlarms(List<InitiativeAlarm> alarms) {
    final payload = [for (final alarm in alarms) alarm.toJson()];
    return preferences.setString(
      AppConstants.initiativeAlarmsKey,
      jsonEncode(payload),
    );
  }

  /// Имитирует фоновое срабатывание: OpenRouter без Gemini, затем речь.
  ///
  /// Выключенный будильник не запускает модель. Если характер не выбран,
  /// метод бросает [StateError].
  Future<InitiativeSpeech> triggerAlarmNow(InitiativeAlarm alarm) async {
    if (!alarm.isEnabled) {
      throw StateError('Будильник ${alarm.id} выключен');
    }

    final characterId = characters.selectedCharacterId;
    if (characterId == null) {
      throw StateError('Характер не выбран');
    }

    final profile = characters.profile(characterId);
    final moment = _now();
    final reply = await gateway.requestInitiative(
      systemPrompt: profile.composedPrompt(now: moment),
      userText: _alarmInstruction(profile, alarm),
    );

    final cue = _cueFor(characterId);
    final cueFinished = await voice.playEmotionCue(
      cue,
      characterId,
      fullVolume: true,
    );
    if (cueFinished) {
      await voice.speak(
        reply.characterAnswer,
        characterId,
        false,
        fullVolume: true,
      );
    }

    return InitiativeSpeech(
      alarm: alarm,
      characterId: characterId,
      text: reply.characterAnswer,
      model: reply.openRouterModel,
    );
  }

  /// Локальный push, если выбранная жена молчит дольше 12 часов.
  ///
  /// Без выбранного характера или без отметки последнего разговора
  /// уведомление не создаётся.
  InitiativeNotice? checkSpontaneousInitiative() {
    final characterId = characters.selectedCharacterId;
    if (characterId == null) return null;

    final profile = characters.profile(characterId);
    final lastRaw = profile.lastInteractionTime;
    if (lastRaw == null) return null;
    final last = DateTime.tryParse(lastRaw);
    if (last == null) return null;

    final gap = _now().toUtc().difference(last.toUtc());
    if (gap <= silenceLimit) return null;

    return InitiativeNotice(
      characterId: characterId,
      title: profile.name,
      body: _spontaneousBody(characterId),
    );
  }
}

String _alarmInstruction(CharacterProfile profile, InitiativeAlarm alarm) {
  final hour = alarm.hour.toString().padLeft(2, '0');
  final minute = alarm.minute.toString().padLeft(2, '0');
  return 'Ты — ${profile.name}. Время $hour:$minute. '
      "Сработал твой личный будильник для пользователя с темой: '${alarm.topic}'. "
      'Начни разговор сама, жестко отыгрывая свой характер, эмоции и текущий '
      'уровень привязанности. Не используй фразы ассистента';
}

EmotionCue _cueFor(String characterId) {
  return switch (characterId) {
    'teacher_wife' || 'street_wife' => EmotionCue.tut,
    _ => EmotionCue.sigh,
  };
}

String _spontaneousBody(String characterId) {
  return switch (characterId) {
    'moody_wife' => 'Ну и ладно, молчи дальше...',
    'street_wife' => 'Эй, ты там живой вообще?',
    'teacher_wife' => 'Прошло больше двенадцати часов. Я всё ещё жду, когда ты вспомнишь, что я здесь.',
    'shy_wife' => 'Я... просто хотела узнать, ты ещё здесь?..',
    _ => 'Давно тебя не слышно.',
  };
}
