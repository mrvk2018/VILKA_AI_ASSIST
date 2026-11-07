/// Общие константы приложения.
abstract final class AppConstants {
  static const String appName = 'VILKA AI ASSIST';

  static const Duration connectTimeout = Duration(seconds: 20);
  static const Duration receiveTimeout = Duration(seconds: 60);

  /// Ключ shared_preferences для пользовательских настроек.
  static const String settingsPrefsKey = 'settings';

  /// Ключ shared_preferences для локальной памяти эмоций.
  ///
  /// Значение — JSON с привязанностью и временем последнего общения
  /// по каждому характеру.
  static const String emotionMemoryPrefsKey = 'emotion_memory';

  /// Ключ shared_preferences с id выбранного характера.
  static const String selectedCharacterIdKey = 'selected_character_id';

  /// Подкаталог файлов конфигурации внутри каталога приложения.
  static const String configDirectoryName = 'config';
}
