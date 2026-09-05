/// Парсер дат в формате DD.MM.YYYY, в котором `due_date` хранится в БД (см.
/// `_formatDate`/`_parseDate` в desktop_planner_screen.dart — та же логика,
/// продублирована здесь как чистая функция без состояния, чтобы её можно
/// было использовать в диалогах создания/редактирования задачи без протяжки
/// ещё одного callback-параметра через все точки создания диалогов).
DateTime? parseClarifyDate(String? dateStr) {
  if (dateStr == null) return null;
  try {
    final parts = dateStr.split('.');
    if (parts.length == 3) {
      return DateTime(
        int.parse(parts[2]),
        int.parse(parts[1]),
        int.parse(parts[0]),
      );
    }
  } catch (_) {
    return null;
  }
  return null;
}

/// Обратная операция — тот же формат DD.MM.YYYY, что и `_formatDate` в
/// desktop_planner_screen.dart (продублировано по той же причине, см. doc
/// [parseClarifyDate] выше).
String formatClarifyDate(DateTime date) {
  return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
}

/// Дата задачи как настоящая дата (B4 из docs/AUDIT_2026-09-04.md, шаг 2).
///
/// Читает колонку `due_on` (тип `date`, приходит через PostgREST строкой
/// `ГГГГ-ММ-ДД`), а строковую `due_date` разбирает только запасным путём.
/// Запасной путь нужен и будет нужен: у оптимистично созданной задачи, которая
/// ещё не доехала до сервера, есть только строка — колонки заполняет триггер в
/// базе, а он срабатывает после вставки. То же и для кэша, записанного до
/// появления колонок.
///
/// Писать по-прежнему нужно строку: клиентов у таблицы четыре (десктоп,
/// мобильный, ИИ-ассистент, бот), и смена типа на запись потребовала бы их
/// одновременного релиза — см. рассуждение в sql/task_real_dates.sql.
DateTime? taskDueDate(Map<String, dynamic> task) {
  final raw = task['due_on'];
  if (raw is String && raw.isNotEmpty) {
    final parsed = DateTime.tryParse(raw);
    if (parsed != null) return DateTime(parsed.year, parsed.month, parsed.day);
  }
  final legacy = task['due_date'];
  return legacy is String ? parseClarifyDate(legacy) : null;
}

/// Часы и минуты срока: сначала колонка `due_at_time` (`ЧЧ:ММ:СС`), потом
/// строковая `due_time` (`ЧЧ:ММ`). null — времени нет.
(int, int)? taskDueTime(Map<String, dynamic> task) {
  for (final raw in [task['due_at_time'], task['due_time']]) {
    if (raw is! String || !raw.contains(':')) continue;
    final parts = raw.split(':');
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) continue;
    return (hour, minute);
  }
  return null;
}

/// Момент дедлайна задачи. Без указанного времени — конец дня.
///
/// Одна функция вместо четырёх почти одинаковых копий, которые жили в
/// desktop_planner_screen (`_isOverdue`, `_taskDeadline`), task_cards и
/// mobile_task_row (`_wasPastDue`). Копии расходились: одна возвращала false
/// при неразобранной дате, другая — null, третья считала конец дня по-своему.
DateTime? taskDeadline(Map<String, dynamic> task) {
  final date = taskDueDate(task);
  if (date == null) return null;
  final time = taskDueTime(task);
  return DateTime(
    date.year,
    date.month,
    date.day,
    time?.$1 ?? 23,
    time?.$2 ?? 59,
  );
}

/// Дедлайн уже прошёл — независимо от того, выполнена задача или нет.
///
/// Именно «независимо»: у выполненной задачи признак просрочки гасится, и
/// место под значок часов резервируется по этой функции, а не по `isOverdue`.
/// Иначе слот и не появился бы в тот же кадр, где задача стала выполненной, и
/// дата прыгала бы влево.
bool taskWasPastDue(Map<String, dynamic> task, {DateTime? now}) {
  final deadline = taskDeadline(task);
  if (deadline == null) return false;
  return (now ?? DateTime.now()).isAfter(deadline);
}
