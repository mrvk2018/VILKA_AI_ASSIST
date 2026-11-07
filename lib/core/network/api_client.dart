import 'package:dio/dio.dart';

import '../constants/app_constants.dart';

/// Общий HTTP-клиент приложения.
///
/// Базовый адрес пустой: Gemini и OpenRouter находятся на разных хостах.
/// Двойной запрос собирает AiGatewayService и передаёт сюда полный URL.
class ApiClient {
  ApiClient({Dio? dio})
    : dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: AppConstants.connectTimeout,
              receiveTimeout: AppConstants.receiveTimeout,
              headers: const {
                'Content-Type': 'application/json',
                'Accept': 'application/json',
              },
            ),
          );

  final Dio dio;
}
