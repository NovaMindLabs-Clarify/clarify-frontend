import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/quick_parse.dart';

/// 5 сентября 2026 — суббота. Все ожидания в тестах считаются от неё.
final DateTime now = DateTime(2026, 9, 5, 10, 0);

QuickParseResult parse(String input) => parseQuickTask(input, now: now);

void main() {
  group('название', () {
    test('строка без разметки целиком становится названием', () {
      final r = parse('позвонить Ивану');
      expect(r.title, 'позвонить Ивану');
      expect(r.hasAnything, isFalse);
    });

    test('распознанные куски вырезаются, пробелы схлопываются', () {
      final r = parse('завтра в 15:00 позвонить Ивану #работа !1');
      expect(r.title, 'позвонить Ивану');
    });

    test('пустая строка не ломает разбор', () {
      final r = parse('   ');
      expect(r.title, '');
      expect(r.hasAnything, isFalse);
    });
  });

  group('дата', () {
    test('сегодня, завтра, послезавтра', () {
      expect(parse('сегодня отчёт').date, DateTime(2026, 9, 5));
      expect(parse('завтра отчёт').date, DateTime(2026, 9, 6));
      expect(parse('послезавтра отчёт').date, DateTime(2026, 9, 7));
    });

    test('день недели — ближайший будущий, не сегодняшний', () {
      // 5 сентября 2026 — суббота.
      expect(parse('в понедельник отчёт').date, DateTime(2026, 9, 7));
      expect(
        parse('в субботу отчёт').date,
        DateTime(2026, 9, 12),
        reason: 'сказанное в субботу «в субботу» — это следующая суббота',
      );
    });

    test('через N дней и недель', () {
      expect(parse('через 3 дня отчёт').date, DateTime(2026, 9, 8));
      expect(parse('через 2 недели отчёт').date, DateTime(2026, 9, 19));
      expect(parse('через 1 день отчёт').date, DateTime(2026, 9, 6));
    });

    test('числом: с годом и без', () {
      expect(parse('12.10 отчёт').date, DateTime(2026, 10, 12));
      expect(parse('12.10.2027 отчёт').date, DateTime(2027, 10, 12));
      expect(parse('12.10.27 отчёт').date, DateTime(2027, 10, 12));
    });

    test('дата без года, которая уже прошла, относится к следующему году', () {
      expect(parse('03.01 отчёт').date, DateTime(2027, 1, 3));
    });

    test('несуществующая дата не распознаётся и остаётся в названии', () {
      final r = parse('31.02 отчёт');
      expect(r.date, isNull);
      expect(r.title, '31.02 отчёт');
    });

    test('название месяца', () {
      expect(parse('12 октября отчёт').date, DateTime(2026, 10, 12));
      expect(parse('3 января отчёт').date, DateTime(2027, 1, 3),
          reason: 'уже прошло в этом году');
    });
  });

  group('время', () {
    test('с двоеточием, с «в» и без', () {
      expect(parse('в 15:30 отчёт').time, '15:30');
      expect(parse('15:30 отчёт').time, '15:30');
      expect(parse('в 9:05 отчёт').time, '09:05');
    });

    test('«в N часов»', () {
      expect(parse('в 15 часов отчёт').time, '15:00');
      expect(parse('в 9 часа отчёт').time, '09:00');
    });

    test('часть суток', () {
      expect(parse('в 7 вечера отчёт').time, '19:00');
      expect(parse('в 7 утра отчёт').time, '07:00');
      expect(parse('в 12 ночи отчёт').time, '00:00');
    });

    test('голое «в N» временем НЕ считается', () {
      // Иначе «купить хлеб в 15 магазине» потеряло бы кусок названия.
      final r = parse('купить хлеб в 15 магазине');
      expect(r.time, isNull);
      expect(r.title, 'купить хлеб в 15 магазине');
    });

    test('нереальное время не распознаётся', () {
      final r = parse('в 25:99 отчёт');
      expect(r.time, isNull);
      expect(r.title, contains('25:99'));
    });
  });

  group('тег и приоритет', () {
    test('#тег', () {
      final r = parse('отчёт #работа');
      expect(r.tag, 'работа');
      expect(r.title, 'отчёт');
    });

    test('!1..!4 разбираются в цвета приоритета', () {
      expect(parse('отчёт !1').priority, 'red');
      expect(parse('отчёт !2').priority, 'orange');
      expect(parse('отчёт !3').priority, 'blue');
      expect(parse('отчёт !4').priority, 'gray');
    });

    test('!5 и голое ! приоритетом не считаются', () {
      expect(parse('отчёт !5').priority, isNull);
      expect(parse('отчёт !').priority, isNull);
      expect(parse('срочно! отчёт').priority, isNull);
    });
  });

  group('всё вместе', () {
    test('пример из аудита разбирается целиком', () {
      final r = parse('завтра в 15 часов позвонить Ивану #работа');
      expect(r.title, 'позвонить Ивану');
      expect(r.date, DateTime(2026, 9, 6));
      expect(r.time, '15:00');
      expect(r.tag, 'работа');
    });

    test('границы распознанного отдаются интерфейсу для подсветки', () {
      final r = parse('завтра отчёт #дом');
      final kinds = r.tokens.map((t) => t.kind).toSet();
      expect(kinds, containsAll([QuickParseKind.date, QuickParseKind.tag]));
      for (final token in r.tokens) {
        expect('завтра отчёт #дом'.substring(token.start, token.end), token.text);
      }
    });
  });
}
