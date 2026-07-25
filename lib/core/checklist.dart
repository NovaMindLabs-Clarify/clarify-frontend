/// Мини-чек-лист внутри задачи (MISSING_FEATURES.md P1.4) — отдельно от
/// подзадач (`parent_id`, отдельные задачи): пункты списка, хранятся прямо
/// в задаче в jsonb-колонке `checklist` как [{text, done}], без своих id.
class ChecklistItem {
  final String text;
  final bool done;

  const ChecklistItem({required this.text, required this.done});

  Map<String, dynamic> toJson() => {'text': text, 'done': done};

  factory ChecklistItem.fromJson(Map<String, dynamic> json) =>
      ChecklistItem(text: json['text'] as String? ?? '', done: json['done'] == true);
}

List<ChecklistItem> parseChecklist(dynamic raw) {
  if (raw is! List) return const [];
  return raw.whereType<Map>().map((e) => ChecklistItem.fromJson(Map<String, dynamic>.from(e))).toList();
}

List<Map<String, dynamic>> encodeChecklist(List<ChecklistItem> items) =>
    items.map((e) => e.toJson()).toList();

Map<String, int> checklistStats(dynamic raw) {
  final items = parseChecklist(raw);
  return {'total': items.length, 'done': items.where((e) => e.done).length};
}
