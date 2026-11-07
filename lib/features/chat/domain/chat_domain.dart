import '../../characters/domain/characters_service.dart';
import '../../characters/models/character_model.dart';
import '../../voice/services/tts_service.dart';
import '../../voice/utils/whisper_detector.dart';
import 'ai_gateway_service.dart';
import 'profanity_filter.dart';

/// Результат одного хода: тон реплики, новая привязанность и ответ шлюза.
final class ChatTurnResult {
  const ChatTurnResult({
    required this.tone,
    required this.affectionLevel,
    required this.reply,
  });

  final ChatTone tone;
  final double affectionLevel;
  final AiGatewayReply reply;
}

/// Ход диалога: фильтр тона, память отношений, затем двойной запрос к ИИ.
final class ChatDialogueService {
  ChatDialogueService({
    required this.characters,
    required this.gateway,
    ProfanityFilter? profanityFilter,
    WhisperDetector? whisperDetector,
    this.voice,
    this.onLocalReaction,
  }) : _profanityFilter = profanityFilter ?? const ProfanityFilter(),
       _whisperDetector = whisperDetector ?? const WhisperDetector();

  final CharactersService characters;
  final AiGateway gateway;
  final TtsService? voice;
  final ProfanityFilter _profanityFilter;
  final WhisperDetector _whisperDetector;

  /// Вызывается сразу перед речью, когда ответ модели уже получен.
  ///
  /// Следом сервис проигрывает вздох или цыканье и только потом озвучивает текст.
  final void Function(ChatTone tone, String characterId)? onLocalReaction;

  Future<ChatTurnResult> send({
    required String characterId,
    required String userText,
    bool isWhisper = false,
    List<double>? microphoneSamples,
  }) async {
    final trimmed = userText.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError.value(userText, 'userText', 'Пустая реплика');
    }

    var profile = characters.profile(characterId);
    final tone = _profanityFilter.analyze(trimmed);
    final whisper =
        isWhisper ||
        (microphoneSamples != null &&
            _whisperDetector.analyzeAudioStream(microphoneSamples));

    final reaction = _reactionFor(characterId, tone);
    if (reaction.delta != 0) {
      profile = await characters.updateRelationship(
        characterId: characterId,
        affectionLevel: profile.affectionLevel + reaction.delta,
      );
    }

    final reply = await gateway.requestCharacterReply(
      userText: trimmed,
      systemPrompt: _systemPrompt(profile, reaction.instruction),
    );
    await _speakReply(
      tone: tone,
      characterId: characterId,
      text: reply.characterAnswer,
      isWhisper: whisper,
    );
    return ChatTurnResult(
      tone: tone,
      affectionLevel: profile.affectionLevel,
      reply: reply,
    );
  }

  Future<void> _speakReply({
    required ChatTone tone,
    required String characterId,
    required String text,
    required bool isWhisper,
  }) async {
    onLocalReaction?.call(tone, characterId);
    final speaker = voice;
    if (speaker == null) return;

    final cue = _emotionCue(tone, characterId);
    final cueFinished =
        cue == null ||
        await speaker.playEmotionCue(cue, characterId, isWhisper: isWhisper);
    if (!cueFinished) return;
    await speaker.speak(text, characterId, isWhisper);
  }
}

EmotionCue? _emotionCue(ChatTone tone, String characterId) {
  if (tone.isNeutral) return null;
  return switch (characterId) {
    'teacher_wife' || 'street_wife' => EmotionCue.tut,
    _ => EmotionCue.sigh,
  };
}

String _systemPrompt(CharacterProfile profile, String? instruction) {
  final base = profile.composedPrompt();
  if (instruction == null) return base;
  return '$base\n\nСкрытая инструкция на этот ответ:\n$instruction';
}

({double delta, String? instruction}) _reactionFor(
  String characterId,
  ChatTone tone,
) {
  if (tone.isNeutral) {
    return (delta: 0, instruction: null);
  }

  final swore = tone.hasProfanity;
  return switch (characterId) {
    'teacher_wife' => (
      delta: -0.15,
      instruction: swore ? _teacherProfanity : _teacherPressure,
    ),
    'moody_wife' => (delta: -0.1, instruction: _moodyOffense),
    'street_wife' => (
      delta: 0,
      instruction: swore ? _streetProfanity : _streetPressure,
    ),
    'shy_wife' => (delta: -0.05, instruction: _shyWithdrawal),
    _ => (delta: 0, instruction: null),
  };
}

const String _teacherProfanity =
    'Пользователь только что сматерился. Проигнорируй его вопрос и строго отчитай его за культуру речи';

const String _teacherPressure =
    'Пользователь только что наехал: капс, давление или оскорбление. Проигнорируй его вопрос и строго отчитай его за тон.';

const String _moodyOffense =
    'Пользователь нагрубил. Включи режим обиды: отвечай холоднее, короче и с уколом, будто эта грубость тебя задела.';

const String _streetProfanity =
    'Пользователь общается матом. Поддержи этот тон, ответь еще более дерзко и бесцензурно в своем стиле';

const String _streetPressure =
    'Пользователь наезжает без мата. Ответь дерзко и в своем стиле. Не делай вид, что он выругался, и не включай канцелярит.';

const String _shyWithdrawal =
    'Пользователь матерится или давит. Смиксуй ответ так, чтобы говорить еще тише, испуганнее и закрыться в себе';
