import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vilka_ai_assist/core/constants/app_constants.dart';
import 'package:vilka_ai_assist/features/characters/characters.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('profile keeps relationship defaults', () {
    const profile = CharacterProfile(
      id: 'custom',
      name: 'Своя',
      avatar: 'avatar',
      systemPrompt: 'prompt',
    );

    expect(profile.affectionLevel, 0.5);
    expect(profile.lastInteractionTime, isNull);

    final restored = CharacterProfile.fromJson({
      'id': 'custom',
      'name': 'Своя',
      'avatar': 'avatar',
      'systemPrompt': 'prompt',
      'affectionLevel': 1.8,
      'lastInteractionTime': '2026-11-07T00:00:00.000Z',
    });

    expect(restored.affectionLevel, 1);
    expect(restored.lastInteractionTime, '2026-11-07T00:00:00.000Z');
    expect(restored.toJson()['affectionLevel'], 1);
  });

  test('relationship memory survives a new service instance', () async {
    final first = CharactersService(await SharedPreferences.getInstance());
    await first.selectCharacter('shy_wife');
    await first.updateRelationship(
      characterId: 'shy_wife',
      affectionLevel: 1.4,
      lastInteractionTime: DateTime.utc(2026, 11, 7, 5),
    );
    await first.updateRelationship(
      characterId: 'moody_wife',
      affectionLevel: -2,
    );

    final second = CharactersService(await SharedPreferences.getInstance());

    expect(second.selectedCharacterId, 'shy_wife');

    final shy = second.profile('shy_wife');
    expect(shy.affectionLevel, 1);
    expect(shy.lastInteractionTime, '2026-11-07T05:00:00.000Z');
    expect(
      shy.composedPrompt(now: DateTime.utc(2026, 11, 7, 6)),
      contains('Последнее общение (ISO): 2026-11-07T05:00:00.000Z.'),
    );

    final moody = second.profile('moody_wife');
    expect(moody.affectionLevel, 0);
    expect(moody.lastInteractionTime, isNull);
    expect(
      moody.systemPrompt,
      CharactersPresets.byId('moody_wife').systemPrompt,
    );

    final stored = (await SharedPreferences.getInstance()).getString(
      AppConstants.emotionMemoryPrefsKey,
    );
    expect(stored, isNot(contains('systemPrompt')));
  });

  test('partial update keeps the previous timestamp', () async {
    final service = CharactersService(await SharedPreferences.getInstance());
    await service.updateRelationship(
      characterId: 'teacher_wife',
      affectionLevel: 0.8,
      lastInteractionTime: DateTime.utc(2026, 11, 1),
    );

    final updated = await service.updateRelationship(
      characterId: 'teacher_wife',
      affectionLevel: 0.3,
    );

    expect(updated.affectionLevel, 0.3);
    expect(updated.lastInteractionTime, '2026-11-01T00:00:00.000Z');
  });

  test('unknown character is rejected', () async {
    final service = CharactersService(await SharedPreferences.getInstance());

    expect(() => CharactersPresets.byId('nope'), throwsArgumentError);
    await expectLater(service.selectCharacter('nope'), throwsArgumentError);
    expect(service.selectedCharacterId, isNull);
  });
}
