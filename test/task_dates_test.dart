import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/clarify_date_format.dart';

/// Срок задачи (B4 из docs/AUDIT_2026-09-04.md, шаг 2).
///
/// До этого «дедлайн задачи» вычислялся четырьмя почти одинаковыми копиями —
/// в desktop_planner_screen (_isOverdue и _taskDeadline), в task_cards и в
/// mobile_task_row. Копии уже расходились в мелочах, и ни одна не была покрыта
/// тестом. Теперь реализация одна и читает настоящие колонки дат.
void main() {
  group('taskDueDate', () {
    test('читает настоящую колонку due_on', () {
      expect(
        taskDueDate({'due_on': '2026-09-05'}),
        DateTime(2026, 9, 5),
      );
    });

    test('строковая due_date — запасной путь', () {
      // Так выглядит оптимистично созданная задача: колонки заполняет триггер
      // в базе, а он срабатывает уже после вставки, поэтому до ответа сервера
      // у задачи есть только строка.
      expect(
        taskDueDate({'due_date': '05.09.2026'}),
        DateTime(2026, 9, 5),
      );
    });

    test('настоящая колонка выигрывает у строки', () {
      expect(
        taskDueDate({'due_on': '2026-09-05', 'due_date': '01.01.2000'}),
        DateTime(2026, 9, 5),
      );
    });

    test('без даты — null', () {
      expect(taskDueDate({}), isNull);
      expect(taskDueDate({'due_date': null, 'due_on': null}), isNull);
      expect(taskDueDate({'due_date': ''}), isNull);
    });

    test('мусор в строке не роняет разбор', () {
      expect(taskDueDate({'due_date': 'вчера'}), isNull);
      expect(taskDueDate({'due_on': 'не дата'}), isNull);
    });

    test('битая колонка не мешает запасному пути', () {
      expect(
        taskDueDate({'due_on': 'мусор', 'due_date': '05.09.2026'}),
        DateTime(2026, 9, 5),
      );
    });
  });

  group('taskDueTime', () {
    test('читает настоящую колонку due_at_time', () {
      expect(taskDueTime({'due_at_time': '16:00:00'}), (16, 0));
    });

    test('строковая due_time — запасной путь', () {
      expect(taskDueTime({'due_time': '16:30'}), (16, 30));
    });

    test('без времени — null', () {
      expect(taskDueTime({}), isNull);
      expect(taskDueTime({'due_time': ''}), isNull);
      expect(taskDueTime({'due_time': 'вечером'}), isNull);
    });
  });

  group('taskDeadline', () {
    test('дата со временем', () {
      expect(
        taskDeadline({'due_on': '2026-09-05', 'due_at_time': '16:00:00'}),
        DateTime(2026, 9, 5, 16, 0),
      );
    });

    test('без времени — конец дня, а не полночь', () {
      // Полночь означала бы, что задача «на сегодня» просрочена весь день.
      expect(
        taskDeadline({'due_on': '2026-09-05'}),
        DateTime(2026, 9, 5, 23, 59),
      );
    });

    test('без даты — null, даже если время есть', () {
      expect(taskDeadline({'due_time': '16:00'}), isNull);
    });
  });

  group('taskWasPastDue', () {
    final now = DateTime(2026, 9, 5, 12, 0);

    test('вчерашняя задача просрочена', () {
      expect(taskWasPastDue({'due_on': '2026-09-04'}, now: now), isTrue);
    });

    test('сегодняшняя без времени ещё не просрочена в полдень', () {
      expect(taskWasPastDue({'due_on': '2026-09-05'}, now: now), isFalse);
    });

    test('сегодняшняя с прошедшим временем просрочена', () {
      expect(
        taskWasPastDue(
          {'due_on': '2026-09-05', 'due_at_time': '10:00:00'},
          now: now,
        ),
        isTrue,
      );
    });

    test('задача без даты не просрочена', () {
      expect(taskWasPastDue({}, now: now), isFalse);
    });

    test('отметка «выполнено» на ответ не влияет', () {
      // Именно в этом отличие от _isOverdue: место под значок часов
      // резервируется по «дедлайн прошёл», иначе в кадре, где задача стала
      // выполненной, слот исчез бы и дата прыгнула влево.
      expect(
        taskWasPastDue(
          {'due_on': '2026-09-04', 'is_completed': true},
          now: now,
        ),
        isTrue,
      );
    });

    test('строковая дата сравнивается как дата, а не как строка', () {
      // Ровно та ловушка, на которой я сам ошибся 05.09.2026, разбирая
      // утреннюю сводку: '31.08.2026' лексикографически БОЛЬШЕ '05.09.2026'.
      expect(taskWasPastDue({'due_date': '31.08.2026'}, now: now), isTrue);
      expect(taskWasPastDue({'due_date': '06.09.2026'}, now: now), isFalse);
    });
  });
}
