import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/app_constants.dart';
import '../data/characters_presets.dart';
import '../models/character_model.dart';

/// Локальная память характеров.
///
/// Пресеты остаются в коде. На устройстве лежат только выбранный id,
/// привязанность и время последнего общения.
class CharactersService {
  CharactersService(this._preferences);

  final SharedPreferences _preferences;

  static Future<CharactersService> open() async {
    final preferences = await SharedPreferences.getInstance();
    return CharactersService(preferences);
  }

  /// Id выбранного характера. Неизвестный или пустой ключ считается отсутствием выбора.
  String? get selectedCharacterId {
    final id = _preferences.getString(AppConstants.selectedCharacterIdKey);
    if (id == null || !CharactersPresets.contains(id)) return null;
    return id;
  }

  Future<void> selectCharacter(String characterId) async {
    CharactersPresets.byId(characterId);
    await _preferences.setString(
      AppConstants.selectedCharacterIdKey,
      characterId,
    );
  }

  /// Все пресеты с уже наложенной локальной памятью.
  List<CharacterProfile> loadAll() {
    final memory = _readMemory();
    return [
      for (final preset in CharactersPresets.all)
        _apply(preset, memory[preset.id]),
    ];
  }

  /// Профиль с памятью. Бросает [ArgumentError], если id нет среди пресетов.
  CharacterProfile profile(String characterId) {
    return _apply(
      CharactersPresets.byId(characterId),
      _readMemory()[characterId],
    );
  }

  /// Перезаписывает память одного характера.
  ///
  /// Пропущенное поле не стирается. [lastInteractionTime] сохраняется
  /// как ISO-8601 в UTC. Привязанность обрезается до диапазона 0.0–1.0.
  Future<CharacterProfile> updateRelationship({
    required String characterId,
    double? affectionLevel,
    DateTime? lastInteractionTime,
  }) async {
    final current = profile(characterId);
    final updated = current.copyWith(
      affectionLevel: affectionLevel,
      lastInteractionTime: lastInteractionTime?.toUtc().toIso8601String(),
    );
    final memory = _readMemory();
    memory[characterId] = _RelationshipMemory(
      affectionLevel: updated.affectionLevel,
      lastInteractionTime: updated.lastInteractionTime,
    );
    await _writeMemory(memory);
    return updated;
  }

  CharacterProfile _apply(
    CharacterProfile preset,
    _RelationshipMemory? memory,
  ) {
    if (memory == null) return preset;
    return preset.copyWith(
      affectionLevel: memory.affectionLevel,
      lastInteractionTime: memory.lastInteractionTime,
    );
  }

  Map<String, _RelationshipMemory> _readMemory() {
    final raw = _preferences.getString(AppConstants.emotionMemoryPrefsKey);
    if (raw == null || raw.isEmpty) return {};

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return {};

      final memory = <String, _RelationshipMemory>{};
      for (final entry in decoded.entries) {
        final id = entry.key;
        final value = entry.value;
        if (id is! String || value is! Map || !CharactersPresets.contains(id)) {
          continue;
        }
        memory[id] = _RelationshipMemory.fromJson(value);
      }
      return memory;
    } on FormatException {
      return {};
    }
  }

  Future<void> _writeMemory(Map<String, _RelationshipMemory> memory) {
    final payload = <String, Object?>{
      for (final entry in memory.entries) entry.key: entry.value.toJson(),
    };
    return _preferences.setString(
      AppConstants.emotionMemoryPrefsKey,
      jsonEncode(payload),
    );
  }
}

class _RelationshipMemory {
  const _RelationshipMemory({
    required this.affectionLevel,
    required this.lastInteractionTime,
  });

  final double affectionLevel;
  final String? lastInteractionTime;

  Map<String, Object?> toJson() {
    return {
      'affectionLevel': affectionLevel,
      'lastInteractionTime': lastInteractionTime,
    };
  }

  factory _RelationshipMemory.fromJson(Map<dynamic, dynamic> json) {
    final rawLevel = json['affectionLevel'];
    final rawTime = json['lastInteractionTime'];
    return _RelationshipMemory(
      affectionLevel: rawLevel is num ? rawLevel.toDouble() : 0.5,
      lastInteractionTime: rawTime is String && rawTime.isNotEmpty
          ? rawTime
          : null,
    );
  }
}
