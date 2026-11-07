import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:vilka_ai_assist/features/voice/utils/whisper_detector.dart';

void main() {
  const detector = WhisperDetector();

  test('silence and loud voice are not whispers', () {
    expect(detector.analyzeAudioStream(const []), isFalse);
    expect(detector.analyzeAudioStream(List<double>.filled(32, 0)), isFalse);
    expect(detector.analyzeAudioStream(List<double>.filled(32, 0.5)), isFalse);

    final loudSpeech = [
      for (var index = 0; index < 200; index++)
        0.6 * math.sin(2 * math.pi * index / 40),
    ];
    expect(detector.analyzeAudioStream(loudSpeech), isFalse);
  });

  test('quiet friction noise is a whisper', () {
    final whisper = [
      for (var index = 0; index < 64; index++) index.isEven ? 0.02 : -0.02,
    ];
    expect(detector.analyzeAudioStream(whisper), isTrue);
  });

  test('a quiet slow tone is not friction', () {
    final quietTone = [
      for (var index = 0; index < 200; index++)
        0.02 * math.sin(2 * math.pi * index / 100),
    ];
    expect(detector.analyzeAudioStream(quietTone), isFalse);
  });
}
