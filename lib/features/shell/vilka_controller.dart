import 'package:flutter/foundation.dart';

import '../characters/domain/characters_service.dart';
import '../characters/models/character_model.dart';
import '../chat/domain/ai_gateway_service.dart';
import '../chat/domain/chat_domain.dart';
import '../scheduler/models/initiative_alarm_model.dart';
import '../scheduler/services/initiative_scheduler_service.dart';
import '../voice/services/tts_service.dart';
import '../voice/utils/whisper_detector.dart';

/// Сообщение текущей сессии чата.
final class ChatEntry {
  ChatEntry({required this.text, required this.fromUser, DateTime? sentAt})
    : sentAt = sentAt ?? DateTime.now();

  final String text;
  final bool fromUser;
  final DateTime sentAt;
}

/// Короткое сообщение для SnackBar.
final class UiNotice {
  const UiNotice(this.message, {this.isError = false});

  final String message;
  final bool isError;
}

/// Общее состояние панели, чата и голоса.
final class VilkaController extends ChangeNotifier {
  VilkaController({
    required this.characters,
    required this.dialogue,
    required this.scheduler,
    required this.voice,
    required this.whisper,
  }) {
    alarms = scheduler.loadAlarms();
  }

  final CharactersService characters;
  final ChatDialogueService dialogue;
  final InitiativeSchedulerService scheduler;
  final TtsService voice;
  final WhisperDetector whisper;

  final List<ChatEntry> messages = [];
  late List<InitiativeAlarm> alarms;

  bool busy = false;
  bool speaking = false;
  bool recording = false;

  UiNotice? _notice;
  bool _disposed = false;

  static Future<VilkaController> open() async {
    final characters = await CharactersService.open();
    final voice = TtsService();
    final gateway = AiGatewayService();
    late final VilkaController controller;
    final dialogue = ChatDialogueService(
      characters: characters,
      gateway: gateway,
      voice: voice,
      onLocalReaction: (_, _) => controller.markSpeaking(),
    );
    final scheduler = await InitiativeSchedulerService.open(
      characters: characters,
      gateway: gateway,
      voice: voice,
    );
    controller = VilkaController(
      characters: characters,
      dialogue: dialogue,
      scheduler: scheduler,
      voice: voice,
      whisper: const WhisperDetector(),
    );
    return controller;
  }

  CharacterProfile? get selected {
    final id = characters.selectedCharacterId;
    if (id == null) return null;
    return characters.profile(id);
  }

  List<CharacterProfile> get profiles => characters.loadAll();

  UiNotice? consumeNotice() {
    final notice = _notice;
    _notice = null;
    return notice;
  }

  void markSpeaking() {
    if (speaking) return;
    speaking = true;
    _touch();
  }

  Future<void> selectCharacter(String characterId) async {
    await characters.selectCharacter(characterId);
    _touch();
  }

  Future<void> sendMessage(
    String text, {
    List<double>? microphoneSamples,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || busy) return;
    final character = selected;
    if (character == null) {
      _report('Сначала выберите характер на панели управления', isError: true);
      return;
    }

    messages.add(ChatEntry(text: trimmed, fromUser: true));
    busy = true;
    _touch();

    try {
      final result = await dialogue.send(
        characterId: character.id,
        userText: trimmed,
        microphoneSamples: microphoneSamples,
      );
      messages.add(
        ChatEntry(text: result.reply.characterAnswer, fromUser: false),
      );
    } catch (error) {
      messages.add(
        ChatEntry(text: 'Не получилось ответить. $error', fromUser: false),
      );
      _notice = UiNotice('Не получилось ответить', isError: true);
    } finally {
      busy = false;
      speaking = false;
      _touch();
    }
  }

  void beginListening() {
    if (busy || speaking || recording) return;
    if (selected == null) {
      _report('Сначала выберите характер на панели управления', isError: true);
      return;
    }
    recording = true;
    _touch();
  }

  Future<void> endListening() async {
    if (!recording) return;
    recording = false;
    final samples = whisperProbe();
    final whispered = whisper.analyzeAudioStream(samples);
    _touch();
    await sendMessage(
      whispered ? 'Я говорю шёпотом' : 'Я говорю вслух',
      microphoneSamples: samples,
    );
    if (whispered && _notice == null) {
      _report('Обнаружен шёпот: ответ будет тише');
    }
  }

  Future<void> interrupt() async {
    await voice.stopSpeaking();
    speaking = false;
    _touch();
  }

  Future<void> addAlarm(InitiativeAlarm alarm) async {
    alarms = [...alarms, alarm];
    await scheduler.saveAlarms(alarms);
    _touch();
  }

  Future<void> setAlarmEnabled(InitiativeAlarm alarm, bool enabled) async {
    alarms = [
      for (final item in alarms)
        if (item.id == alarm.id) item.copyWith(isEnabled: enabled) else item,
    ];
    await scheduler.saveAlarms(alarms);
    _touch();
  }

  Future<void> testAlarm(InitiativeAlarm alarm) async {
    if (busy) return;
    busy = true;
    speaking = true;
    _touch();
    try {
      final speech = await scheduler.triggerAlarmNow(alarm);
      messages.add(ChatEntry(text: speech.text, fromUser: false));
      _notice = UiNotice('Вилка заговорила по будильнику');
    } catch (error) {
      _notice = UiNotice('$error', isError: true);
    } finally {
      busy = false;
      speaking = false;
      _touch();
    }
  }

  void _report(String message, {bool isError = false}) {
    _notice = UiNotice(message, isError: isError);
    _touch();
  }

  void _touch() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

/// Тихие отсчёты с частой сменой знака: локальная проверка детектора шёпота.
List<double> whisperProbe() {
  return [for (var index = 0; index < 64; index++) index.isEven ? 0.02 : -0.02];
}
