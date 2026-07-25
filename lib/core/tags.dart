/// Общая логика разбора тегов (MISSING_FEATURES.md P1.2) — теги хранятся как
/// одна строка через запятую в поле `tags` задачи, отдельной таблицы для них
/// нет. Раньше парсинг дублировался построчно в нескольких экранах.
List<String> parseTagsString(dynamic raw) {
  if (raw == null || raw.toString().trim().isEmpty) return const [];
  return raw
      .toString()
      .split(',')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();
}

/// Все уникальные теги, встречающиеся хотя бы в одной задаче — источник
/// автодополнения при вводе и список авто-папок проектов.
List<String> collectAllTags(List<Map<String, dynamic>> tasks) {
  final tags = <String>{};
  for (final task in tasks) {
    tags.addAll(parseTagsString(task['tags']));
  }
  final sorted = tags.toList()..sort();
  return sorted;
}
