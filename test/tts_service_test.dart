import 'package:flutter_test/flutter_test.dart';
import 'package:vilka_ai_assist/features/voice/services/tts_service.dart';

void main() {
  test('character voices use the requested pitch, rate and volume', () async {
    final engine = RecordingEngine();
    final service = TtsService(engine: engine, wait: (_) async {});

    await service.speak('Коротко.', 'street_wife', false);
    await service.speak('Слушай внимательно.', 'teacher_wife', false);
    await service.speak('Я тут.', 'shy_wife', false);
    await service.speak('Ну и ладно.', 'moody_wife', false);

    expect(engine.deliveries[0].pitch, 1.2);
    expect(engine.deliveries[0].rate, 0.55);
    expect(engine.deliveries[0].volume, 1);
    expect(engine.deliveries[1].pitch, 1);
    expect(engine.deliveries[1].rate, 0.5);
    expect(engine.deliveries[2].pitch, 0.85);
    expect(engine.deliveries[2].rate, 0.4);
    expect(engine.deliveries[2].volume, 0.4);
    expect(engine.deliveries[3].pitch, 1);
    expect(engine.deliveries[3].rate, 0.45);
    expect(engine.deliveries[3].volume, 1);
  });

  test('whisper lowers volume and slows every character', () async {
    final engine = RecordingEngine();
    final service = TtsService(engine: engine, wait: (_) async {});

    await service.speak('Тихо.', 'street_wife', true);

    expect(engine.deliveries.single.volume, VoiceDelivery.whisperVolume);
    expect(engine.deliveries.single.rate, closeTo(0.55 * 0.75, 0.0001));
    expect(engine.deliveries.single.pitch, 1.2);
  });

  test('moody speech pauses between sentences', () async {
    final engine = RecordingEngine();
    final pauses = <Duration>[];
    final service = TtsService(
      engine: engine,
      wait: (delay) async => pauses.add(delay),
    );

    await service.speak('Ты опять. Я заметила.', 'moody_wife', false);

    expect(engine.spoken, ['Ты опять.', 'Я заметила.']);
    expect(pauses, [const Duration(milliseconds: 400)]);
  });

  test('stop words cut the speech and harmless words do not', () async {
    final engine = RecordingEngine();
    final service = TtsService(engine: engine, wait: (_) async {});

    expect(await service.checkInterruptTrigger('достойный стопка'), isFalse);
    expect(engine.stops, 0);

    expect(await service.checkInterruptTrigger('Стой, подожди'), isTrue);
    expect(engine.stops, 1);

    engine.onSpeak = () => service.checkInterruptTrigger('стоп');
    final finished = await service.playEmotionCue(EmotionCue.sigh, 'shy_wife');
    expect(finished, isFalse);
    expect(engine.spoken.single, 'эх…');
  });
}

final class RecordingEngine implements SpeechEngine {
  final deliveries = <VoiceDelivery>[];
  final spoken = <String>[];
  var stops = 0;
  Future<void> Function()? onSpeak;

  @override
  Future<void> apply(VoiceDelivery delivery) async {
    deliveries.add(delivery);
  }

  @override
  Future<void> speak(String text) async {
    spoken.add(text);
    await onSpeak?.call();
  }

  @override
  Future<void> stop() async {
    stops++;
  }
}
