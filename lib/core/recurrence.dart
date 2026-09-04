/// Правила порождения следующего экземпляра повторяющейся задачи.
///
/// Вынесено из экрана отдельно и без единой зависимости на Flutter — чтобы
/// поведение можно было проверить тестами, а не только глазами в приложении.
/// Повод конкретный: до 05.09.2026 следующий экземпляр создавался при отметке
/// ЛЮБОЙ копии и без проверки, существует ли он уже. Отметили три копии одного
/// месяца — получили три копии следующего. В базе на момент аудита лежало
/// 44 копии одной задачи с датами на год вперёд и 55 клонов её подзадач —
/// больше половины всех задач пользователя.
library;

/// Следующая дата по правилу повтора. `null` — правило не порождает продолжения.
DateTime? nextRecurrenceDate({
  required DateTime from,
  required String? recurrence,
  int? interval,
}) {
  switch (recurrence) {
    case 'daily':
      return from.add(const Duration(days: 1));
    case 'weekdays':
      // Пятница → понедельник, суббота → понедельник; воскресенье и будни → +1.
      final int addDays = switch (from.weekday) {
        DateTime.friday => 3,
        DateTime.saturday => 2,
        _ => 1,
      };
      return from.add(Duration(days: addDays));
    case 'weekly':
      return from.add(const Duration(days: 7));
    case 'monthly':
      // DateTime сам нормализует переполнение: 31.01 + месяц → 02.03 (или 03.03
      // в високосный). Так же вело себя и прежнее поведение — не меняю.
      return DateTime(from.year, from.month + 1, from.day);
    case 'custom':
      return from.add(Duration(days: interval ?? 1));
    default:
      return null;
  }
}

/// Две задачи — экземпляры одной серии.
///
/// Идентификатора серии в схеме нет (у `tasks` нет ничего вроде `series_id`),
/// поэтому серия опознаётся по полям, которые и копируются в новый экземпляр:
/// название, родитель, правило повтора и команда.
bool sameRecurringSeries(Map<String, dynamic> a, Map<String, dynamic> b) {
  return a['title'] == b['title'] &&
      a['parent_id'] == b['parent_id'] &&
      a['recurrence'] == b['recurrence'] &&
      a['workspace_id'] == b['workspace_id'];
}

/// Есть ли уже экземпляр этой серии на дату `dateStr` (формат ДД.ММ.ГГГГ).
///
/// Страхует от повторной отметки (сняли галочку и поставили обратно) и от
/// гонки двух устройств.
bool recurringInstanceExists({
  required List<Map<String, dynamic>> tasks,
  required Map<String, dynamic> task,
  required String dateStr,
}) {
  return tasks.any((t) =>
      t['id'] != task['id'] &&
      t['due_date'] == dateStr &&
      sameRecurringSeries(t, task));
}

/// Самый свежий по дате экземпляр серии — только он порождает следующий.
///
/// `parseDate` передаётся снаружи, чтобы модуль не знал про формат дат экрана
/// и оставался чистым.
bool isLatestRecurringInstance({
  required List<Map<String, dynamic>> tasks,
  required Map<String, dynamic> task,
  required DateTime date,
  required DateTime? Function(String raw) parseDate,
}) {
  for (final t in tasks) {
    if (t['id'] == task['id']) continue;
    if (!sameRecurringSeries(t, task)) continue;
    final dynamic raw = t['due_date'];
    if (raw is! String) continue;
    final DateTime? other = parseDate(raw);
    if (other != null && other.isAfter(date)) return false;
  }
  return true;
}
