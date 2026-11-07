import 'package:dio/dio.dart';

import '../../../core/constants/api_secrets.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/network/api_client.dart';

/// Модели двухэтапного шлюза.
abstract final class AiModels {
  static const String gemini = 'gemini-2.0-flash';
  static const String openRouter = 'openrouter/free';
  static const String openRouterFallback =
      'cognitivecomputations/dolphin-mistral-24b-venice-edition:free';
}

/// Ответ шлюза: сухая справка и реплика, уже окрашенная характером.
final class AiGatewayReply {
  const AiGatewayReply({
    required this.factualAnswer,
    required this.characterAnswer,
    required this.geminiModel,
    required this.openRouterModel,
  });

  final String factualAnswer;
  final String characterAnswer;
  final String geminiModel;
  final String openRouterModel;
}

abstract interface class AiGateway {
  /// Шаг 1 — Gemini. Шаг 2 — OpenRouter с [systemPrompt] в роли system.
  Future<AiGatewayReply> requestCharacterReply({
    required String userText,
    required String systemPrompt,
  });
}

final class AiGatewayException implements Exception {
  const AiGatewayException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Двойной запрос: сухой ответ Gemini, затем пересказ характером через OpenRouter.
final class AiGatewayService implements AiGateway {
  AiGatewayService({Dio? dio, String? geminiApiKey, String? openRouterApiKey})
    : _dio = dio ?? ApiClient().dio,
      _geminiApiKey = geminiApiKey ?? ApiSecrets.geminiApiKey,
      _openRouterApiKey = openRouterApiKey ?? ApiSecrets.openRouterApiKey;

  final Dio _dio;
  final String _geminiApiKey;
  final String _openRouterApiKey;

  static const String _geminiBase =
      'https://generativelanguage.googleapis.com/v1beta/models';
  static const String _openRouterUrl =
      'https://openrouter.ai/api/v1/chat/completions';

  @override
  Future<AiGatewayReply> requestCharacterReply({
    required String userText,
    required String systemPrompt,
  }) async {
    _ensureKeys();
    final factualAnswer = await _requestGemini(userText);
    final character = await _requestOpenRouter(
      userText: userText,
      factualAnswer: factualAnswer,
      systemPrompt: systemPrompt,
    );
    return AiGatewayReply(
      factualAnswer: factualAnswer,
      characterAnswer: character.$1,
      geminiModel: AiModels.gemini,
      openRouterModel: character.$2,
    );
  }

  void _ensureKeys() {
    if (ApiSecrets.isPlaceholder(_geminiApiKey) ||
        ApiSecrets.isPlaceholder(_openRouterApiKey)) {
      throw const AiGatewayException(
        'Укажите ключи Gemini и OpenRouter в lib/core/constants/api_secrets.dart.',
      );
    }
  }

  Future<String> _requestGemini(String userText) async {
    try {
      final response = await _dio.post<Object>(
        '$_geminiBase/${AiModels.gemini}:generateContent',
        queryParameters: {'key': _geminiApiKey},
        data: {
          'systemInstruction': {
            'parts': [
              {
                'text':
                    'Ответь сухо, кратко и по существу. '
                    'Без ролевой игры, без обращений и без вступлений.',
              },
            ],
          },
          'contents': [
            {
              'role': 'user',
              'parts': [
                {'text': userText},
              ],
            },
          ],
          'generationConfig': {'temperature': 0.2},
        },
      );
      final text = _geminiText(response.data);
      if (text == null) {
        throw const AiGatewayException('Gemini не вернул текст.');
      }
      return text;
    } on DioException catch (error) {
      throw AiGatewayException(_networkMessage('Gemini', error));
    }
  }

  Future<(String, String)> _requestOpenRouter({
    required String userText,
    required String factualAnswer,
    required String systemPrompt,
  }) async {
    try {
      final text = await _completeOpenRouter(
        model: AiModels.openRouter,
        userText: userText,
        factualAnswer: factualAnswer,
        systemPrompt: systemPrompt,
      );
      return (text, AiModels.openRouter);
    } on AiGatewayException {
      final text = await _completeOpenRouter(
        model: AiModels.openRouterFallback,
        userText: userText,
        factualAnswer: factualAnswer,
        systemPrompt: systemPrompt,
      );
      return (text, AiModels.openRouterFallback);
    }
  }

  Future<String> _completeOpenRouter({
    required String model,
    required String userText,
    required String factualAnswer,
    required String systemPrompt,
  }) async {
    try {
      final response = await _dio.post<Object>(
        _openRouterUrl,
        options: Options(
          headers: {
            'Authorization': 'Bearer $_openRouterApiKey',
            'X-Title': AppConstants.appName,
          },
        ),
        data: {
          'model': model,
          'messages': [
            {'role': 'system', 'content': systemPrompt},
            {
              'role': 'user',
              'content': _characterUserMessage(
                userText: userText,
                factualAnswer: factualAnswer,
              ),
            },
          ],
        },
      );
      final text = _openRouterText(response.data);
      if (text == null) {
        throw AiGatewayException('OpenRouter ($model) вернул пустой ответ.');
      }
      return text;
    } on DioException catch (error) {
      throw AiGatewayException(_networkMessage('OpenRouter', error));
    }
  }
}

String _characterUserMessage({
  required String userText,
  required String factualAnswer,
}) {
  return '''
Вопрос пользователя:
$userText

Сухая справка (только факты, не образец речи):
$factualAnswer
''';
}

String _networkMessage(String service, DioException error) {
  final code = error.response?.statusCode;
  final suffix = code == null ? '' : ' (HTTP $code)';
  return '$service не ответил$suffix.';
}

String? _geminiText(Object? data) {
  if (data is! Map) return null;
  if (data['error'] != null) return null;
  final candidates = data['candidates'];
  if (candidates is! List || candidates.isEmpty) return null;
  final candidate = candidates.first;
  if (candidate is! Map) return null;
  final content = candidate['content'];
  if (content is! Map) return null;
  final parts = content['parts'];
  if (parts is! List) return null;

  final buffer = StringBuffer();
  for (final part in parts) {
    if (part is Map && part['text'] is String) {
      buffer.write(part['text']);
    }
  }
  final text = buffer.toString().trim();
  return text.isEmpty ? null : text;
}

String? _openRouterText(Object? data) {
  if (data is! Map) return null;
  final choices = data['choices'];
  if (choices is! List || choices.isEmpty) return null;
  final choice = choices.first;
  if (choice is! Map) return null;
  final message = choice['message'];
  if (message is! Map) return null;
  final content = message['content'];
  if (content is String) {
    final text = content.trim();
    return text.isEmpty ? null : text;
  }
  if (content is! List) return null;

  final buffer = StringBuffer();
  for (final part in content) {
    if (part is Map && part['text'] is String) {
      buffer.write(part['text']);
    }
  }
  final text = buffer.toString().trim();
  return text.isEmpty ? null : text;
}
