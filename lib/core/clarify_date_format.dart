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
