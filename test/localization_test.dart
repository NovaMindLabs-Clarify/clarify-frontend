import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/localization.dart';

void main() {
  group('TranslateExtension.tr', () {
    test('возвращает русский перевод для известного ключа', () {
      expect('Сегодня'.tr('ru'), 'Сегодня');
    });

    test('возвращает английский перевод для известного ключа', () {
      expect('Сегодня'.tr('en'), 'Today');
    });

    test('возвращает исходную строку, если перевод не найден', () {
      const missingKey = 'Такого ключа точно нет в словаре';
      expect(missingKey.tr('ru'), missingKey);
      expect(missingKey.tr('en'), missingKey);
    });

    test('возвращает исходную строку для неизвестного языка', () {
      expect('Сегодня'.tr('fr'), 'Сегодня');
    });
  });
}
