import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/recurrence.dart';

/// Разбор даты в формате приложения (ДД.ММ.ГГГГ) — тот же формат, что у
/// _parseDate на экране.
DateTime? parseDate(String raw) {
  final parts = raw.split('.');
  if (parts.length != 3) return null;
  final d = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  final y = int.tryParse(parts[2]);
  if (d == null || m == null || y == null) return null;
  return DateTime(y, m, d);
}

Map<String, dynamic> task({
  required int id,
  String title = 'Полить цветы',
  String? dueDate,
  String? recurrence = 'monthly',
  dynamic parentId,
  dynamic workspaceId,
}) {
  return {
    'id': id,
    'title': title,
    'due_date': dueDate,
    'recurrence': recurrence,
    'parent_id': parentId,
    'workspace_id': workspaceId,
  };
}

void main() {
  group('nextRecurrenceDate', () {
    test('ежедневно — следующий день', () {
      expect(
        nextRecurrenceDate(from: DateTime(2026, 9, 4), recurrence: 'daily'),
        DateTime(2026, 9, 5),
      );
    });

    test('по будням — с пятницы на понедельник, с субботы на понедельник', () {
      expect(
        nextRecurrenceDate(from: DateTime(2026, 9, 4), recurrence: 'weekdays'),
        DateTime(2026, 9, 7),
        reason: '4 сентября 2026 — пятница',
      );
      expect(
        nextRecurrenceDate(from: DateTime(2026, 9, 5), recurrence: 'weekdays'),
        DateTime(2026, 9, 7),
        reason: '5 сентября 2026 — суббота',
      );
      expect(
        nextRecurrenceDate(from: DateTime(2026, 9, 7), recurrence: 'weekdays'),
        DateTime(2026, 9, 8),
        reason: 'понедельник — обычный +1',
      );
    });

    test('еженедельно и ежемесячно', () {
      expect(
        nextRecurrenceDate(from: DateTime(2026, 9, 4), recurrence: 'weekly'),
        DateTime(2026, 9, 11),
      );
      expect(
        nextRecurrenceDate(from: DateTime(2026, 9, 4), recurrence: 'monthly'),
        DateTime(2026, 10, 4),
      );
    });

    test('свой интервал; без интервала — раз в день', () {
      expect(
        nextRecurrenceDate(from: DateTime(2026, 9, 4), recurrence: 'custom', interval: 10),
        DateTime(2026, 9, 14),
      );
      expect(
        nextRecurrenceDate(from: DateTime(2026, 9, 4), recurrence: 'custom'),
        DateTime(2026, 9, 5),
      );
    });

    test('без повтора продолжения нет', () {
      expect(nextRecurrenceDate(from: DateTime(2026, 9, 4), recurrence: 'none'), isNull);
      expect(nextRecurrenceDate(from: DateTime(2026, 9, 4), recurrence: null), isNull);
    });
  });

  group('recurringInstanceExists', () {
    test('находит уже созданный экземпляр серии на ту же дату', () {
      final current = task(id: 1, dueDate: '04.09.2026');
      final tasks = [current, task(id: 2, dueDate: '04.10.2026')];
      expect(
        recurringInstanceExists(tasks: tasks, task: current, dateStr: '04.10.2026'),
        isTrue,
      );
    });

    test('сам себя экземпляром не считает', () {
      final current = task(id: 1, dueDate: '04.10.2026');
      expect(
        recurringInstanceExists(tasks: [current], task: current, dateStr: '04.10.2026'),
        isFalse,
      );
    });

    test('чужая серия с той же датой не мешает', () {
      final current = task(id: 1, dueDate: '04.09.2026');
      final other = task(id: 2, title: 'Другая задача', dueDate: '04.10.2026');
      expect(
        recurringInstanceExists(tasks: [current, other], task: current, dateStr: '04.10.2026'),
        isFalse,
      );
    });

    test('задача из другой команды — другая серия', () {
      final current = task(id: 1, dueDate: '04.09.2026');
      final other = task(id: 2, dueDate: '04.10.2026', workspaceId: 7);
      expect(
        recurringInstanceExists(tasks: [current, other], task: current, dateStr: '04.10.2026'),
        isFalse,
      );
    });
  });

  group('isLatestRecurringInstance', () {
    test('единственный экземпляр — самый свежий', () {
      final current = task(id: 1, dueDate: '04.09.2026');
      expect(
        isLatestRecurringInstance(
          tasks: [current],
          task: current,
          date: DateTime(2026, 9, 4),
          parseDate: parseDate,
        ),
        isTrue,
      );
    });

    test('старая копия следующий экземпляр не порождает', () {
      final old = task(id: 1, dueDate: '04.09.2026');
      final newer = task(id: 2, dueDate: '04.10.2026');
      expect(
        isLatestRecurringInstance(
          tasks: [old, newer],
          task: old,
          date: DateTime(2026, 9, 4),
          parseDate: parseDate,
        ),
        isFalse,
      );
    });

    test('самая свежая копия порождает', () {
      final old = task(id: 1, dueDate: '04.09.2026');
      final newer = task(id: 2, dueDate: '04.10.2026');
      expect(
        isLatestRecurringInstance(
          tasks: [old, newer],
          task: newer,
          date: DateTime(2026, 10, 4),
          parseDate: parseDate,
        ),
        isTrue,
      );
    });

    test('копия без даты не блокирует порождение', () {
      final current = task(id: 1, dueDate: '04.09.2026');
      final broken = task(id: 2, dueDate: null);
      expect(
        isLatestRecurringInstance(
          tasks: [current, broken],
          task: current,
          date: DateTime(2026, 9, 4),
          parseDate: parseDate,
        ),
        isTrue,
      );
    });
  });

  group('лавина из аудита не воспроизводится', () {
    test('отметка трёх копий одного месяца порождает ровно один следующий', () {
      // Ровно тот сценарий, из-за которого в базе накопилось 44 копии:
      // три копии на 01.09, каждую отмечают выполненной.
      final copies = [
        task(id: 1, dueDate: '01.09.2026'),
        task(id: 2, dueDate: '01.09.2026'),
        task(id: 3, dueDate: '01.09.2026'),
      ];
      final all = <Map<String, dynamic>>[...copies];

      var spawned = 0;
      for (final copy in copies) {
        final from = parseDate(copy['due_date'])!;
        if (!isLatestRecurringInstance(
          tasks: all,
          task: copy,
          date: from,
          parseDate: parseDate,
        )) {
          continue;
        }
        final next = nextRecurrenceDate(from: from, recurrence: copy['recurrence'] as String?);
        final nextStr = '01.10.2026';
        expect(next, DateTime(2026, 10, 1));
        if (recurringInstanceExists(tasks: all, task: copy, dateStr: nextStr)) continue;
        all.add(task(id: 100 + spawned, dueDate: nextStr));
        spawned++;
      }

      expect(spawned, 1, reason: 'три отметки одного месяца — один следующий экземпляр');
      expect(all.where((t) => t['due_date'] == '01.10.2026').length, 1);
    });
  });
}
