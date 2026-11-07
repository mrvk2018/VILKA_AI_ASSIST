import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vilka_ai_assist/core/constants/app_constants.dart';
import 'package:vilka_ai_assist/features/characters/characters.dart';
import 'package:vilka_ai_assist/features/chat/domain/ai_gateway_service.dart';
import 'package:vilka_ai_assist/features/chat/domain/chat_domain.dart';
import 'package:vilka_ai_assist/features/chat/domain/profanity_filter.dart';
import 'package:vilka_ai_assist/features/voice/services/tts_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late RecordingGateway gateway;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    gateway = RecordingGateway();
  });

  Future<ChatDialogueService> dialogue({
    void Function(ChatTone tone, String characterId)? onLocalReaction,
  }) async {
    return ChatDialogueService(
      characters: CharactersService(await SharedPreferences.getInstance()),
      gateway: gateway,
      onLocalReaction: onLocalReaction,
    );
  }

  test(
    'neutral speech does not touch affection or add an instruction',
    () async {
      final heard = <ChatTone>[];
      final service = await dialogue(
        onLocalReaction: (tone, characterId) {
          expect(characterId, 'moody_wife');
          heard.add(tone);
        },
      );

      final result = await service.send(
        characterId: 'moody_wife',
        userText: 'привет, как дела?',
      );

      expect(result.tone.isNeutral, isTrue);
      expect(result.affectionLevel, 0.5);
      expect(heard, [result.tone]);
      expect(gateway.systemPrompt, isNot(contains('Скрытая инструкция')));
      expect(
        (await SharedPreferences.getInstance()).getString(
          AppConstants.emotionMemoryPrefsKey,
        ),
        isNull,
      );
    },
  );

  test('teacher and moody lose affection, street keeps it', () async {
    final service = await dialogue();

    final teacher = await service.send(
      characterId: 'teacher_wife',
      userText: 'бля, ответь уже',
    );
    expect(teacher.tone.hasProfanity, isTrue);
    expect(teacher.affectionLevel, closeTo(0.35, 0.0001));
    expect(gateway.systemPrompt, contains('Мат запрещён полностью'));
    expect(
      gateway.systemPrompt,
      contains('Проигнорируй его вопрос и строго отчитай его за культуру речи'),
    );
    expect(
      gateway.systemPrompt,
      contains('Привязанность: ${teacher.affectionLevel}'),
    );

    final moody = await service.send(
      characterId: 'moody_wife',
      userText: 'ты дурак',
    );
    expect(moody.tone.isAggressive, isTrue);
    expect(moody.tone.hasProfanity, isFalse);
    expect(moody.affectionLevel, closeTo(0.4, 0.0001));
    expect(gateway.systemPrompt, contains('режим обиды'));

    final street = await service.send(
      characterId: 'street_wife',
      userText: 'ну и пиздец',
    );
    expect(street.affectionLevel, 0.5);
    expect(gateway.systemPrompt, contains('еще более дерзко и бесцензурно'));

    final stored = (await SharedPreferences.getInstance()).getString(
      AppConstants.emotionMemoryPrefsKey,
    );
    expect(stored, isNot(contains('street_wife')));
  });

  test('shy wife withdraws from pressure and caps', () async {
    final service = await dialogue();
    final result = await service.send(
      characterId: 'shy_wife',
      userText: 'ХВАТИТ ОРАТЬ НА МЕНЯ',
    );

    expect(result.tone.hasProfanity, isFalse);
    expect(result.tone.isAggressive, isTrue);
    expect(result.affectionLevel, closeTo(0.45, 0.0001));
    expect(gateway.systemPrompt, contains('еще тише, испуганнее'));
  });

  test('affection is saved before a failed model request', () async {
    gateway.fail = true;
    final heard = <String>[];
    final service = await dialogue(
      onLocalReaction: (tone, characterId) => heard.add(characterId),
    );

    await expectLater(
      service.send(characterId: 'teacher_wife', userText: 'бля'),
      throwsA(isA<AiGatewayException>()),
    );

    expect(heard, isEmpty);
    expect(gateway.calls, 1);
    final profile = CharactersService(await SharedPreferences.getInstance())
        .profile('teacher_wife');
    expect(profile.affectionLevel, closeTo(0.35, 0.0001));
  });

  test('reaction cue plays after the callback and before the reply', () async {
    final engine = RecordingEngine();
    final events = <String>[];
    final service = ChatDialogueService(
      characters: CharactersService(await SharedPreferences.getInstance()),
      gateway: gateway,
      voice: TtsService(engine: engine, wait: (_) async {}),
      onLocalReaction: (tone, characterId) {
        expect(characterId, 'teacher_wife');
        expect(tone.hasProfanity, isTrue);
        events.add('reaction');
      },
    );

    await service.send(
      characterId: 'teacher_wife',
      userText: 'бля',
      microphoneSamples: [
        for (var index = 0; index < 32; index++) index.isEven ? 0.02 : -0.02,
      ],
    );

    expect(events, ['reaction']);
    expect(engine.spoken, ['ц-ц', 'voice']);
    expect(engine.deliveries.last.volume, VoiceDelivery.whisperVolume);
  });
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

final class RecordingGateway implements AiGateway {
  bool fail = false;
  int calls = 0;
  String? systemPrompt;
  String? userText;

  @override
  Future<AiGatewayReply> requestCharacterReply({
    required String userText,
    required String systemPrompt,
  }) async {
    calls++;
    this.userText = userText;
    this.systemPrompt = systemPrompt;
    if (fail) {
      throw const AiGatewayException('сеть');
    }
    return const AiGatewayReply(
      factualAnswer: 'fact',
      characterAnswer: 'voice',
      geminiModel: AiModels.gemini,
      openRouterModel: AiModels.openRouter,
    );
  }

  @override
  Future<AiGatewayReply> requestInitiative({
    required String userText,
    required String systemPrompt,
  }) {
    throw UnimplementedError();
  }
}
