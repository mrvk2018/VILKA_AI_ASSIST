import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vilka_ai_assist/app.dart';
import 'package:vilka_ai_assist/core/constants/app_constants.dart';
import 'package:vilka_ai_assist/features/characters/characters.dart';
import 'package:vilka_ai_assist/features/chat/domain/ai_gateway_service.dart';
import 'package:vilka_ai_assist/features/chat/domain/chat_domain.dart';
import 'package:vilka_ai_assist/features/scheduler/scheduler.dart';
import 'package:vilka_ai_assist/features/shell/vilka_controller.dart';
import 'package:vilka_ai_assist/features/voice/services/tts_service.dart';
import 'package:vilka_ai_assist/features/voice/utils/whisper_detector.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('shell shows the app name', (tester) async {
    await tester.pumpWidget(VilkaApp(controller: await _controller()));

    expect(find.text(AppConstants.appName), findsOneWidget);
    expect(find.text('Чат'), findsOneWidget);
    expect(find.text('Управление'), findsOneWidget);
  });

  testWidgets('selecting a wife updates the chat header', (tester) async {
    await tester.pumpWidget(VilkaApp(controller: await _controller()));
    await tester.tap(find.text('Управление'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Стеснительная'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Стеснительная'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Чат'));
    await tester.pumpAndSettle();

    expect(
      tester.widget<Text>(find.byKey(const Key('chat-title'))).data,
      'Стеснительная',
    );
    expect(find.text('Ровно'), findsWidgets);
  });

  testWidgets('alarm can be added and switched off', (tester) async {
    await tester.pumpWidget(VilkaApp(controller: await _controller()));
    await tester.tap(find.text('Управление'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('add-alarm')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('alarm-topic')), 'На работу');
    await tester.tap(find.byKey(const Key('save-alarm')));
    await tester.pumpAndSettle();

    expect(find.textContaining('На работу'), findsOneWidget);
    expect(find.text('07:30'), findsOneWidget);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
  });

  testWidgets('microphone overlay sends a whisper line', (tester) async {
    final controller = await _controller();
    await tester.pumpWidget(VilkaApp(controller: controller));
    await tester.tap(find.text('Управление'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Умная училка'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Чат'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('mic-button')));
    await tester.pump();
    expect(find.text('Слушаю…'), findsOneWidget);

    await tester.tap(find.byKey(const Key('listen-done')));
    await tester.pumpAndSettle();

    expect(find.text('Я говорю шёпотом'), findsOneWidget);
    expect(find.text('Слышу тебя'), findsOneWidget);
  });

  testWidgets('stop button interrupts speech', (tester) async {
    final engine = _HoldingEngine();
    await tester.pumpWidget(
      VilkaApp(controller: await _controller(engine: engine)),
    );
    await tester.tap(find.text('Управление'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Капризная и обидчивая'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Чат'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('chat-input')), 'Привет');
    await tester.tap(find.byKey(const Key('send-button')));
    await _until(tester, find.byKey(const Key('stop-button')));

    expect(find.text('СТОП / ПЕРЕБИТЬ'), findsOneWidget);
    await tester.tap(find.byKey(const Key('stop-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('stop-button')), findsNothing);
    expect(find.text('Привет'), findsOneWidget);
    expect(find.text('Слышу тебя'), findsOneWidget);
  });
}

Future<void> _until(WidgetTester tester, Finder finder) async {
  for (var attempt = 0; attempt < 20; attempt++) {
    await tester.pump(const Duration(milliseconds: 20));
    if (finder.evaluate().isNotEmpty) return;
  }
  fail('Не дождались $finder');
}

Future<VilkaController> _controller({SpeechEngine? engine}) async {
  SharedPreferences.setMockInitialValues({});
  final preferences = await SharedPreferences.getInstance();
  final characters = CharactersService(preferences);
  final voice = TtsService(
    engine: engine ?? _ImmediateEngine(),
    wait: (_) async {},
  );
  final gateway = _FakeGateway();
  late final VilkaController controller;
  final dialogue = ChatDialogueService(
    characters: characters,
    gateway: gateway,
    voice: voice,
    onLocalReaction: (_, _) => controller.markSpeaking(),
  );
  controller = VilkaController(
    characters: characters,
    dialogue: dialogue,
    scheduler: InitiativeSchedulerService(
      preferences: preferences,
      characters: characters,
      gateway: gateway,
      voice: voice,
    ),
    voice: voice,
    whisper: const WhisperDetector(),
  );
  return controller;
}

final class _FakeGateway implements AiGateway {
  @override
  Future<AiGatewayReply> requestCharacterReply({
    required String userText,
    required String systemPrompt,
  }) async {
    return const AiGatewayReply(
      factualAnswer: 'fact',
      characterAnswer: 'Слышу тебя',
      geminiModel: 'fake',
      openRouterModel: 'fake',
    );
  }

  @override
  Future<AiGatewayReply> requestInitiative({
    required String userText,
    required String systemPrompt,
  }) async {
    return const AiGatewayReply(
      factualAnswer: '',
      characterAnswer: 'Подъём',
      geminiModel: '',
      openRouterModel: 'fake',
    );
  }
}

final class _ImmediateEngine implements SpeechEngine {
  @override
  Future<void> apply(VoiceDelivery delivery) async {}

  @override
  Future<void> speak(String text) async {}

  @override
  Future<void> stop() async {}
}

final class _HoldingEngine implements SpeechEngine {
  Completer<void>? _gate;

  @override
  Future<void> apply(VoiceDelivery delivery) async {}

  @override
  Future<void> speak(String text) {
    final gate = Completer<void>();
    _gate = gate;
    return gate.future;
  }

  @override
  Future<void> stop() async {
    if (_gate != null && !_gate!.isCompleted) _gate!.complete();
  }
}
