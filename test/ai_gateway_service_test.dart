import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vilka_ai_assist/features/chat/domain/ai_gateway_service.dart';

void main() {
  const geminiKey = 'test-gemini-key';
  const openRouterKey = 'test-openrouter-key';
  const systemPrompt = 'СИСТЕМНЫЙ-ХАРАКТЕР';

  test('placeholder keys fail before any request', () async {
    var calls = 0;
    final dio = Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            calls++;
            handler.reject(
              DioException(requestOptions: options, message: 'should not send'),
            );
          },
        ),
      );

    final gateway = AiGatewayService(dio: dio);
    await expectLater(
      gateway.requestCharacterReply(userText: 'привет', systemPrompt: 'sys'),
      throwsA(
        isA<AiGatewayException>().having(
          (error) => error.message,
          'message',
          contains('api_secrets.dart'),
        ),
      ),
    );
    expect(calls, 0);
  });

  test('double request keeps the character prompt out of Gemini', () async {
    final requests = <RequestOptions>[];
    final gateway = AiGatewayService(
      dio: _scriptedDio(requests: requests),
      geminiApiKey: geminiKey,
      openRouterApiKey: openRouterKey,
    );

    final reply = await gateway.requestCharacterReply(
      userText: 'Сколько будет два плюс два?',
      systemPrompt: systemPrompt,
    );

    expect(reply.factualAnswer, 'Сухой факт.');
    expect(reply.characterAnswer, 'Ответ характером.');
    expect(reply.geminiModel, AiModels.gemini);
    expect(reply.openRouterModel, AiModels.openRouter);
    expect(requests, hasLength(2));

    final gemini = requests.first;
    expect(gemini.uri.path, contains('${AiModels.gemini}:generateContent'));
    expect(gemini.uri.queryParameters['key'], geminiKey);
    final geminiBody = gemini.data as Map<String, dynamic>;
    expect(geminiBody['generationConfig'], {'temperature': 0.2});
    expect(geminiBody.toString(), isNot(contains(systemPrompt)));
    expect(geminiBody.toString(), contains('два плюс два'));

    final openRouter = requests.last;
    expect(openRouter.uri.path, '/api/v1/chat/completions');
    expect(openRouter.headers['Authorization'], 'Bearer $openRouterKey');
    final body = openRouter.data as Map<String, dynamic>;
    expect(body['model'], AiModels.openRouter);
    final messages = body['messages'] as List<dynamic>;
    expect(messages.first, {'role': 'system', 'content': systemPrompt});
    final userMessage = messages.last as Map<String, dynamic>;
    expect(userMessage['role'], 'user');
    expect(userMessage['content'], contains('Вопрос пользователя:'));
    expect(userMessage['content'], contains('два плюс два'));
    expect(userMessage['content'], contains('Сухой факт.'));
  });

  test('OpenRouter failure falls back to the reserve model', () async {
    final models = <String>[];
    final gateway = AiGatewayService(
      dio: _scriptedDio(
        requests: [],
        openRouterModels: models,
        failFirst: true,
      ),
      geminiApiKey: geminiKey,
      openRouterApiKey: openRouterKey,
    );

    final reply = await gateway.requestCharacterReply(
      userText: 'привет',
      systemPrompt: systemPrompt,
    );

    expect(models, [AiModels.openRouter, AiModels.openRouterFallback]);
    expect(reply.openRouterModel, AiModels.openRouterFallback);
    expect(reply.characterAnswer, 'Ответ характером.');
  });

  test('upstream errors do not echo the API key', () async {
    final dio = Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            handler.reject(
              DioException(
                requestOptions: options,
                type: DioExceptionType.badResponse,
                response: Response(
                  requestOptions: options,
                  statusCode: 401,
                  data: {'error': 'bad key $geminiKey'},
                ),
              ),
            );
          },
        ),
      );
    final gateway = AiGatewayService(
      dio: dio,
      geminiApiKey: geminiKey,
      openRouterApiKey: openRouterKey,
    );

    await expectLater(
      gateway.requestCharacterReply(userText: 'привет', systemPrompt: 'sys'),
      throwsA(
        isA<AiGatewayException>().having(
          (error) => error.toString(),
          'text',
          allOf(contains('HTTP 401'), isNot(contains(geminiKey))),
        ),
      ),
    );
  });
}

Dio _scriptedDio({
  required List<RequestOptions> requests,
  List<String>? openRouterModels,
  bool failFirst = false,
}) {
  var openRouterCalls = 0;
  return Dio()
    ..interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          requests.add(options);
          final url = options.uri.toString();
          if (url.contains('generativelanguage.googleapis.com')) {
            handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 200,
                data: {
                  'candidates': [
                    {
                      'content': {
                        'parts': [
                          {'text': 'Сухой факт.'},
                        ],
                      },
                    },
                  ],
                },
              ),
            );
            return;
          }

          openRouterCalls++;
          final model = (options.data as Map)['model'] as String;
          openRouterModels?.add(model);
          if (failFirst && openRouterCalls == 1) {
            handler.reject(
              DioException(
                requestOptions: options,
                type: DioExceptionType.badResponse,
                response: Response(
                  requestOptions: options,
                  statusCode: 503,
                  data: {'error': 'busy'},
                ),
              ),
            );
            return;
          }

          handler.resolve(
            Response(
              requestOptions: options,
              statusCode: 200,
              data: {
                'choices': [
                  {
                    'message': {'content': 'Ответ характером.'},
                  },
                ],
              },
            ),
          );
        },
      ),
    );
}
