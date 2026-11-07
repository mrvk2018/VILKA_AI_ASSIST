/// Локальный будильник инициативы.
///
/// [daysOfWeek] использует нумерацию [DateTime.weekday]:
/// 1 — понедельник, 7 — воскресенье.
final class InitiativeAlarm {
  const InitiativeAlarm({
    required this.id,
    required this.hour,
    required this.minute,
    required this.topic,
    required this.isEnabled,
    required this.daysOfWeek,
  });

  final String id;
  final int hour;
  final int minute;
  final String topic;
  final bool isEnabled;
  final List<int> daysOfWeek;

  InitiativeAlarm copyWith({
    String? id,
    int? hour,
    int? minute,
    String? topic,
    bool? isEnabled,
    List<int>? daysOfWeek,
  }) {
    return InitiativeAlarm(
      id: id ?? this.id,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
      topic: topic ?? this.topic,
      isEnabled: isEnabled ?? this.isEnabled,
      daysOfWeek: List<int>.from(daysOfWeek ?? this.daysOfWeek),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'hour': hour,
      'minute': minute,
      'topic': topic,
      'isEnabled': isEnabled,
      'daysOfWeek': daysOfWeek,
    };
  }

  factory InitiativeAlarm.fromJson(Map<String, dynamic> json) {
    final hour = _readInt(json['hour'], 'hour');
    final minute = _readInt(json['minute'], 'minute');
    if (hour < 0 || hour > 23) {
      throw FormatException('Час вне диапазона 0–23: $hour');
    }
    if (minute < 0 || minute > 59) {
      throw FormatException('Минута вне диапазона 0–59: $minute');
    }

    final topic = json['topic'];
    if (topic is! String || topic.trim().isEmpty) {
      throw const FormatException('У будильника нет темы');
    }

    return InitiativeAlarm(
      id: json['id'] as String,
      hour: hour,
      minute: minute,
      topic: topic,
      isEnabled: json['isEnabled'] as bool? ?? true,
      daysOfWeek: _readDays(json['daysOfWeek']),
    );
  }
}

int _readInt(Object? raw, String field) {
  if (raw is int) return raw;
  if (raw is num) return raw.toInt();
  throw FormatException('Поле $field должно быть числом');
}

List<int> _readDays(Object? raw) {
  if (raw is! List) return const [];
  final days = <int>[];
  for (final item in raw) {
    if (item is! num) continue;
    final day = item.toInt();
    if (day < 1 || day > 7 || days.contains(day)) continue;
    days.add(day);
  }
  return days;
}
