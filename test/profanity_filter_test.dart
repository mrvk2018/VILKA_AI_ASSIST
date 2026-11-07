import 'package:flutter_test/flutter_test.dart';
import 'package:vilka_ai_assist/features/chat/domain/profanity_filter.dart';

void main() {
  const filter = ProfanityFilter();

  void expectTone(
    String text, {
    bool profanity = false,
    bool aggressive = false,
  }) {
    expect(
      filter.analyze(text),
      ChatTone(hasProfanity: profanity, isAggressive: aggressive),
      reason: text,
    );
  }

  test('ordinary speech stays neutral', () {
    for (final text in [
      'привет',
      'как дела, ты дома?',
      'пошел на работу',
      'барсука видно из окна',
      'у борта корабля тихо',
      'ребёнок спит',
      'мне нравится влюбляться',
      'это хулиган, не путай',
      'купи мандарин и мандат не путай',
      'парикмахер закрыт',
      'херсон далеко',
      'шлюз открыт',
      'возьми себе хлеб',
      'учеба и похудеть — разные вещи',
      'художник смотрит',
      'нехудожественный пересказ',
      'отвар остыл',
      'чмок',
      'объем бака',
    ]) {
      expectTone(text);
    }
  });

  test('swear stems and split letters are profanity', () {
    for (final text in [
      'бля, ну сколько можно',
      'Блять, это уже слишком',
      'ну и пиздец',
      'х.у.й',
      'х у й',
      'сука',
      'да иди нахуй',
      'опять заебал',
      'ёб твою',
      'долбоеб',
    ]) {
      expectTone(text, profanity: true);
    }
  });

  test('caps, слышь and insults are aggressive without counting plain ты', () {
    expectTone('СЛЫШЬ ТЫ', aggressive: true);
    expectTone('ты дурак', aggressive: true);
    expectTone('ты чё себе позволяешь', aggressive: true);
    expectTone('ХВАТИТ ОРАТЬ НА МЕНЯ', aggressive: true);
    expectTone('слышь, бля', profanity: true, aggressive: true);
  });
}
