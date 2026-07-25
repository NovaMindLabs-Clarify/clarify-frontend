/// Явный флаг приоритета P1–P4 (MISSING_FEATURES.md P1.3) — поле `priority`
/// у задачи уже существовало (значения 'red'/'orange'/'blue'/'gray'/'none'),
/// но трактовалось как произвольный цвет. Здесь фиксируется семантика этих
/// же значений как уровней P1 (высший) — P4 (низший), без миграции данных.
const List<String> kPriorityLevels = ['red', 'orange', 'blue', 'gray'];

const Map<String, String> _priorityFlagLabels = {
  'red': 'P1',
  'orange': 'P2',
  'blue': 'P3',
  'gray': 'P4',
};

String priorityFlagLabel(String? priority) => _priorityFlagLabels[priority] ?? '';

/// Для сортировки — 0 (P1) выше 3 (P4), задачи без приоритета идут последними.
int priorityRank(String? priority) {
  final index = kPriorityLevels.indexOf(priority ?? '');
  return index == -1 ? kPriorityLevels.length : index;
}
