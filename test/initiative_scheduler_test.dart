import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vilka_ai_assist/core/constants/app_constants.dart';
import 'package:vilka_ai_assist/features/characters/characters.dart';
import 'package:vilka_ai_assist/features/chat/domain/ai_gateway_service.dart';
import 'package:vilka_ai_assist/features/scheduler/scheduler.dart';
import 'package:vilka_ai_assist/features/voice/services/tts_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const alarm = InitiativeAlarm(
    id: 'work',
    hour: 7,
    minute: 5,
    topic: 'Разбуди меня на работу',
    isEnabled: true,
    daysOfWeek: [1, 2, 3, 4, 5],
  );

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('alarm survives json and a new preferences instance', () async {
    final restored = InitiativeAlarm.fromJson(alarm.toJson());
    expect(restored.topic, alarm.topic);
    expect(restored.copyWith(isEnabled: false).isEnabled, isFalse);
    expect(restored.daysOfWeek, [1, 2, 3, 4, 5]);

    final preferences = await SharedPreferences.getInstance();
    final scheduler = _scheduler(
      preferences: preferences,
      characters: CharactersService(preferences),
    );
    await scheduler.saveAlarms([
      alarm,
      alarm.copyWith(id: 'weekend', hour: 11),
    ]);

    final again = InitiativeSchedulerService(
      preferences: preferences,
      characters: CharactersService(preferences),
      gateway: InitiativeGateway(),
      voice: TtsService(engine: RecordingEngine(), wait: (_) async {}),
    );
    final loaded = again.loadAlarms();
    expect(loaded, hasLength(2));
    expect(loaded.last.hour, 11);
    expect(
      preferences.getString(AppConstants.initiativeAlarmsKey),
      isNot(contains('systemPrompt')),
    );
  });

  test('silence longer than twelve hours creates a wife notice', () async {
    final preferences = await SharedPreferences.getInstance();
    final characters = CharactersService(preferences);
    final now = DateTime.utc(2026, 11, 7, 18);
    final scheduler = _scheduler(
      preferences: preferences,
      characters: characters,
      now: () => now,
    );

    expect(scheduler.checkSpontaneousInitiative(), isNull);

    await characters.selectCharacter('moody_wife');
    expect(scheduler.checkSpontaneousInitiative(), isNull);

    await characters.updateRelationship(
      characterId: 'moody_wife',
      lastInteractionTime: now.subtract(const Duration(hours: 12)),
    );
    expect(scheduler.checkSpontaneousInitiative(), isNull);

    await characters.updateRelationship(
      characterId: 'moody_wife',
      lastInteractionTime: now.subtract(const Duration(hours: 12, minutes: 1)),
    );
    final moody = scheduler.checkSpontaneousInitiative();
    expect(moody?.body, 'Ну и ладно, молчи дальше...');

    await characters.selectCharacter('street_wife');
    await characters.updateRelationship(
      characterId: 'street_wife',
      lastInteractionTime: now.subtract(const Duration(hours: 13)),
    );
    expect(
      scheduler.checkSpontaneousInitiative()?.body,
      'Эй, ты там живой вообще?',
    );
  });

  test('enabled alarm speaks at full volume after the emotion cue', () async {
    final preferences = await SharedPreferences.getInstance();
    final characters = CharactersService(preferences);
    await characters.selectCharacter('shy_wife');
    final moment = DateTime.utc(2026, 11, 7, 7, 5);
    final gateway = InitiativeGateway();
    final engine = RecordingEngine();
    final scheduler = _scheduler(
      preferences: preferences,
      characters: characters,
      gateway: gateway,
      voice: TtsService(engine: engine, wait: (_) async {}),
      now: () => moment,
    );

    final speech = await scheduler.triggerAlarmNow(alarm);
    final profile = characters.profile('shy_wife');

    expect(speech.characterId, 'shy_wife');
    expect(speech.text, 'Подъём.');
    expect(speech.model, AiModels.openRouterFallback);
    expect(gateway.systemPrompt, profile.composedPrompt(now: moment));
    expect(gateway.userText, contains("темой: 'Разбуди меня на работу'"));
    expect(gateway.userText, contains('Время 07:05'));
    expect(gateway.userText, contains('Не используй фразы ассистента'));
    expect(gateway.userText, contains(profile.name));
    expect(engine.spoken, ['эх…', 'Подъём.']);
    expect(engine.deliveries.every((delivery) => delivery.volume == 1), isTrue);
  });

  test('disabled alarm does not call the model', () async {
    final preferences = await SharedPreferences.getInstance();
    final characters = CharactersService(preferences);
    await characters.selectCharacter('teacher_wife');
    final gateway = InitiativeGateway();
    final scheduler = _scheduler(
      preferences: preferences,
      characters: characters,
      gateway: gateway,
    );

    await expectLater(
      scheduler.triggerAlarmNow(alarm.copyWith(isEnabled: false)),
      throwsStateError,
    );
    expect(gateway.calls, 0);
  });
}

InitiativeSchedulerService _scheduler({
  required SharedPreferences preferences,
  required CharactersService characters,
  AiGateway? gateway,
  TtsService? voice,
  DateTime Function()? now,
}) {
  return InitiativeSchedulerService(
    preferences: preferences,
    characters: characters,
    gateway: gateway ?? InitiativeGateway(),
    voice: voice ?? TtsService(engine: RecordingEngine(), wait: (_) async {}),
    now: now,
  );
}

final class InitiativeGateway implements AiGateway {
  int calls = 0;
  String? systemPrompt;
  String? userText;

  @override
  Future<AiGatewayReply> requestCharacterReply({
    required String userText,
    required String systemPrompt,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<AiGatewayReply> requestInitiative({
    required String userText,
    required String systemPrompt,
  }) async {
    calls++;
    this.userText = userText;
    this.systemPrompt = systemPrompt;
    return const AiGatewayReply(
      factualAnswer: '',
      characterAnswer: 'Подъём.',
      geminiModel: '',
      openRouterModel: AiModels.openRouterFallback,
    );
  }
}

final class RecordingEngine implements SpeechEngine {
  final deliveries = <VoiceDelivery>[];
  final spoken = <String>[];

  @override
  Future<void> apply(VoiceDelivery delivery) async {
    deliveries.add(delivery);
  }

  @override
  Future<void> speak(String text) async {
    spoken.add(text);
  }

  @override
  Future<void> stop() async {}
}
