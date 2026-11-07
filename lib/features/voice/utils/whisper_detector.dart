import 'dart:math' as math;

/// Локальная оценка шёпота по уже снятым отсчётам.
///
/// Отсчёты ожидаются в диапазоне примерно от -1 до 1.
/// Микрофонный поток сюда не подключается: метод считает RMS и частоту
/// пересечения нуля. Высокий ZCR при тихом сигнале — признак шума трения
/// без голосовых связок. Тишина не считается шёпотом: у неё мало пересечений.
final class WhisperDetector {
  const WhisperDetector({
    this.quietThresholdDb = -30,
    this.frictionZcrThreshold = 0.2,
  });

  /// Шёпот тише этого уровня, в децибелах относительно полной шкалы.
  final double quietThresholdDb;

  /// Доля пересечений нуля, начиная с которой шум похож на трение.
  final double frictionZcrThreshold;

  bool analyzeAudioStream(List<double> samples) {
    if (samples.length < 2) return false;
    final levelDb = _rmsDb(samples);
    final zeroCrossingRate = _zeroCrossingRate(samples);
    return levelDb < quietThresholdDb &&
        zeroCrossingRate >= frictionZcrThreshold;
  }
}

double _rmsDb(List<double> samples) {
  var energy = 0.0;
  for (final sample in samples) {
    energy += sample * sample;
  }
  final rms = math.sqrt(energy / samples.length);
  if (rms < 1e-8) return -120;
  return 20 * math.log(rms) / math.ln10;
}

double _zeroCrossingRate(List<double> samples) {
  var crossings = 0;
  for (var index = 1; index < samples.length; index++) {
    final previous = samples[index - 1];
    final current = samples[index];
    final crossed =
        (previous >= 0 && current < 0) || (previous < 0 && current >= 0);
    if (crossed) crossings++;
  }
  return crossings / (samples.length - 1);
}
