/// Заглушки ключей. Настоящие значения сюда не записываются.
abstract final class ApiSecrets {
  static const String geminiApiKey = 'YOUR_GEMINI_API_KEY';
  static const String openRouterApiKey = 'YOUR_OPENROUTER_API_KEY';

  static bool isPlaceholder(String value) {
    final normalized = value.trim();
    return normalized.isEmpty || normalized.startsWith('YOUR_');
  }
}
