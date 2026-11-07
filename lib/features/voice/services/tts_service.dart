import 'package:flutter_tts/flutter_tts.dart';

/// Короткий звук перед репликой: вздох или цыканье.
enum EmotionCue { sigh, tut }

/// Параметры голоса, уже подготовленные для движка.
final class VoiceDelivery {
  const VoiceDelivery({
    required this.pitch,
    required this.rate,
    required this.volume,
    required this.phrasePause,
  });

  final double pitch;
  final double rate;
  final double volume;
  final Duration phrasePause;

  static const double whisperVolume = 0.18;
  static const double whisperRateFactor = 0.75;

  /// Громкость шёпота — внутри запрошенного коридора 0.15–0.2.
  factory VoiceDelivery.forCharacter(
    String characterId, {
    required bool isWhisper,
    bool fullVolume = false,
  }) {
    final base = switch (characterId) {
      'moody_wife' => (
        pitch: 1.0,
        rate: 0.45,
        volume: 1.0,
        pause: const Duration(milliseconds: 400),
      ),
      'street_wife' => (
        pitch: 1.2,
        rate: 0.55,
        volume: 1.0,
        pause: Duration.zero,
      ),
      'teacher_wife' => (
        pitch: 1.0,
        rate: 0.5,
        volume: 1.0,
        pause: Duration.zero,
      ),
      'shy_wife' => (pitch: 0.85, rate: 0.4, volume: 0.4, pause: Duration.zero),
      _ => (pitch: 1.0, rate: 0.5, volume: 1.0, pause: Duration.zero),
    };

    final whisper = isWhisper && !fullVolume;
    return VoiceDelivery(
      pitch: base.pitch,
      rate: whisper ? base.rate * whisperRateFactor : base.rate,
      volume: fullVolume
          ? 1
          : whisper
          ? whisperVolume
          : base.volume,
      phrasePause: base.pause,
    );
  }
}

/// Узкий контракт движка, чтобы озвучку можно было проверить без устройства.
abstract interface class SpeechEngine {
  Future<void> apply(VoiceDelivery delivery);
  Future<void> speak(String text);
  Future<void> stop();
}

/// Озвучка ответов и локальных эмоциональных вставок.
final class TtsService {
  TtsService({SpeechEngine? engine, this.wait = Future.delayed})
    : _engine = engine ?? FlutterTtsSpeechEngine();

  final SpeechEngine _engine;
  final Future<void> Function(Duration delay) wait;

  bool _interrupted = false;

  static final RegExp _interruptTriggers = RegExp(
    r'(?:^|[^а-я])(?:стоп|стой|подожди(?:те)?)(?![а-я])',
  );

  /// Озвучивает [text] голосом характера.
  ///
  /// При [isWhisper] громкость падает до шёпота, а темп становится медленнее
  /// настроек этого характера.
  Future<void> speak(
    String text,
    String characterId,
    bool isWhisper, {
    bool fullVolume = false,
  }) async {
    final phrases = _phrases(text, characterId: characterId);
    if (phrases.isEmpty) return;

    _interrupted = false;
    final delivery = VoiceDelivery.forCharacter(
      characterId,
      isWhisper: isWhisper,
      fullVolume: fullVolume,
    );
    await _engine.apply(delivery);

    for (var index = 0; index < phrases.length; index++) {
      if (_interrupted) return;
      await _engine.speak(phrases[index]);
      final hasNext = index < phrases.length - 1;
      if (!_interrupted && hasNext && delivery.phrasePause > Duration.zero) {
        await wait(delivery.phrasePause);
      }
    }
  }

  /// Вздох или цыканье тем же голосом, до основной реплики.
  ///
  /// Возвращает `false`, если вставку прервали словом «стоп», «стой»
  /// или «подожди».
  Future<bool> playEmotionCue(
    EmotionCue cue,
    String characterId, {
    bool isWhisper = false,
    bool fullVolume = false,
  }) async {
    _interrupted = false;
    final delivery = VoiceDelivery.forCharacter(
      characterId,
      isWhisper: isWhisper,
      fullVolume: fullVolume,
    );
    await _engine.apply(
      VoiceDelivery(
        pitch: delivery.pitch,
        rate: delivery.rate,
        volume: delivery.volume,
        phrasePause: Duration.zero,
      ),
    );
    await _engine.speak(cue == EmotionCue.sigh ? 'эх…' : 'ц-ц');
    return !_interrupted;
  }

  /// Мгновенно обрывает текущую озвучку.
  Future<void> stopSpeaking() async {
    _interrupted = true;
    await _engine.stop();
  }

  /// Офлайн-проверка barge-in по уже распознанному тексту.
  ///
  /// Микрофон сюда не входит: метод только смотрит на готовую строку.
  Future<bool> checkInterruptTrigger(String recognizedText) async {
    final normalized = recognizedText.toLowerCase().replaceAll('ё', 'е');
    if (!_interruptTriggers.hasMatch(normalized)) return false;
    await stopSpeaking();
    return true;
  }
}

List<String> _phrases(String text, {required String characterId}) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return const [];
  if (characterId != 'moody_wife') return [trimmed];

  final sentences = trimmed
      .split(RegExp(r'(?<=[.!?…])\s+'))
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty)
      .toList();
  if (sentences.length > 1) return sentences;

  final clauses = trimmed
      .split(RegExp(r'\s*,\s*'))
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty)
      .toList();
  return clauses.length > 1 ? clauses : [trimmed];
}

final class FlutterTtsSpeechEngine implements SpeechEngine {
  FlutterTtsSpeechEngine({FlutterTts? tts}) : _tts = tts ?? FlutterTts();

  final FlutterTts _tts;
  var _ready = false;

  @override
  Future<void> apply(VoiceDelivery delivery) async {
    await _prepare();
    await _tts.setPitch(delivery.pitch);
    await _tts.setSpeechRate(delivery.rate);
    await _tts.setVolume(delivery.volume);
  }

  @override
  Future<void> speak(String text) async {
    await _prepare();
    await _tts.speak(text);
  }

  @override
  Future<void> stop() => _tts.stop();

  Future<void> _prepare() async {
    if (_ready) return;
    await _tts.setLanguage('ru-RU');
    await _tts.awaitSpeakCompletion(true);
    _ready = true;
  }
}
