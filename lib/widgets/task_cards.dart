import 'package:flutter/material.dart';

/// Строит карточки задачи для трёх представлений (список, доска "7 дней",
/// календарь). Вынесено из DesktopPlannerScreen (P3.1, docs/IMPROVEMENT_PLAN.md) —
/// логика и разметка не менялись, только доступ к состоянию родителя заменён
/// на явные параметры конструктора.
class TaskCardBuilders {
  final bool isDark;
  final double scale;
  final Map<int, List<Map<String, dynamic>>> workspaceMembers;
  final Color Function(String? priority) getPriorityColor;
  final Map<String, int> Function(dynamic parentId) getSubtaskStats;
  final bool Function(Map<String, dynamic> task) isOverdue;
  final void Function(Map<String, dynamic> task) onToggle;
  final void Function(dynamic taskId) onDelete;
  final void Function(Map<String, dynamic> task) onTap;
  final void Function(String tag) onTagTap;
  final Widget Function({
    required Widget child,
    BorderRadius? borderRadius,
    EdgeInsetsGeometry? padding,
    EdgeInsetsGeometry? margin,
    Color? customColor,
  }) buildGlassContainer;

  const TaskCardBuilders({
    required this.isDark,
    required this.scale,
    required this.workspaceMembers,
    required this.getPriorityColor,
    required this.getSubtaskStats,
    required this.isOverdue,
    required this.onToggle,
    required this.onDelete,
    required this.onTap,
    required this.onTagTap,
    required this.buildGlassContainer,
  });

  double get _s => scale;
  Color get textColor => isDark ? const Color(0xFFF1F5F9) : const Color(0xFF1E293B);
  Color get textMuted => isDark ? Colors.white70 : Colors.black54;
  Color get glassBorderColor => isDark ? Colors.white.withOpacity(0.15) : Colors.black.withOpacity(0.15);
  Color get doneCardColor => isDark ? Colors.black.withOpacity(0.4) : Colors.white.withOpacity(0.5);

  Widget buildCalendarTaskRow(Map<String, dynamic> task) {
    final bool isDone = task['is_completed'] == true;
    Color priorityColor = getPriorityColor(task['priority']);
    bool hasPriority = task['priority'] != null && task['priority'] != 'none';
    bool hasRecurrence = task['recurrence'] != null && task['recurrence'] != 'none';
    final stats = getSubtaskStats(task['id']);
    final bool hasSubtasks = stats['total']! > 0;
    final bool allDone = hasSubtasks && stats['done'] == stats['total'];

    final bool overdue = isOverdue(task);

    String displayTitle = task['title'] ?? '';

    return GestureDetector(
      onTap: () => onTap(task),
      child: Container(
        margin: EdgeInsets.only(bottom: 4 * _s, left: 4 * _s, right: 4 * _s),
        decoration: BoxDecoration(
          color: isDone ? Colors.transparent : (overdue ? Colors.redAccent.withOpacity(0.08) : Colors.transparent),
          borderRadius: BorderRadius.circular(6 * _s),
        ),
        padding: EdgeInsets.symmetric(vertical: 2 * _s),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // ПРИНУДИТЕЛЬНОЕ масштабирование кругляшка
            SizedBox(
              width: 16 * _s,
              height: 16 * _s,
              child: Transform.scale(
                scale: 0.7 * _s, // Уменьшаем сам рисунок чекбокса
                child: Checkbox(
                  shape: const CircleBorder(),
                  side: BorderSide(color: isDone ? glassBorderColor : (hasPriority ? priorityColor : (overdue ? Colors.redAccent : glassBorderColor)), width: hasPriority || overdue ? 2.0 : 1.5),
                  value: isDone,
                  activeColor: Colors.blueAccent,
                  onChanged: (val) => onToggle(task),
                ),
              ),
            ),
            SizedBox(width: 4 * _s),

            Expanded(
              child: Text(
                displayTitle,
                style: TextStyle(
                  fontSize: 11 * _s,
                  fontWeight: FontWeight.w600,
                  decoration: isDone ? TextDecoration.lineThrough : TextDecoration.none,
                  color: isDone ? textMuted : textColor,
                ),
                maxLines: 1, // Запрет переноса строк
                overflow: TextOverflow.ellipsis, // Многоточие, если не влезает
              ),
            ),

            SizedBox(width: 4 * _s),

            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (overdue) Icon(Icons.error_outline, size: 10 * _s, color: Colors.redAccent),
                if (task['due_time'] != null) Text(task['due_time'], style: TextStyle(fontSize: 10 * _s, fontWeight: overdue ? FontWeight.bold : FontWeight.normal, color: overdue ? Colors.redAccent : textMuted)),
                if (hasRecurrence) Padding(padding: EdgeInsets.only(left: 4 * _s), child: Icon(Icons.repeat, size: 10 * _s, color: isDone ? textMuted : Colors.orange)),
                if (hasSubtasks) Padding(padding: EdgeInsets.only(left: 4 * _s), child: Text("[${stats['done']}/${stats['total']}]", style: TextStyle(fontSize: 10 * _s, fontWeight: FontWeight.bold, color: allDone ? Colors.green : Colors.orange))),
                if (task['tags'] != null && task['tags'].toString().trim().isNotEmpty) Padding(padding: EdgeInsets.only(left: 4 * _s), child: Text("[${task['tags'].toString().split(',')[0].trim()}]", style: TextStyle(fontSize: 10 * _s, fontWeight: FontWeight.bold, color: Colors.blueAccent))),
              ],
            ),

            GestureDetector(onTap: () => onDelete(task['id']), child: Padding(padding: EdgeInsets.only(left: 4 * _s), child: Icon(Icons.close, size: 12 * _s, color: textMuted))),
          ],
        ),
      ),
    );
  }

  Widget buildCalendarTaskCard(Map<String, dynamic> task) {
    return LongPressDraggable<Map<String, dynamic>>(
      data: task,
      delay: const Duration(milliseconds: 200),
      feedback: Material(color: Colors.transparent, child: SizedBox(width: 150, child: buildCalendarTaskRow(task))),
      childWhenDragging: Opacity(opacity: 0.3, child: buildCalendarTaskRow(task)),
      child: buildCalendarTaskRow(task),
    );
  }

  Widget buildBoardTaskCardExpanded(Map<String, dynamic> task) {
    final bool isDone = task['is_completed'] == true;
    Color priorityColor = getPriorityColor(task['priority']);
    bool hasPriority = task['priority'] != null && task['priority'] != 'none';
    bool hasRecurrence = task['recurrence'] != null && task['recurrence'] != 'none';
    final stats = getSubtaskStats(task['id']);
    final bool hasSubtasks = stats['total']! > 0;
    final bool allDone = hasSubtasks && stats['done'] == stats['total'];

    final bool overdue = isOverdue(task);

    String displayTitle = task['title'] ?? '';

    return GestureDetector(
      onTap: () => onTap(task),
      child: Container(
        margin: EdgeInsets.only(bottom: 12 * _s), color: Colors.transparent,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center, // <-- ИДЕАЛЬНОЕ ВЫРАВНИВАНИЕ ПО ЦЕНТРУ
          children: [
            SizedBox(
              width: 44 * _s,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center, // <-- Центрируем иконку и время
                children: [
                  if (overdue) Padding(padding: EdgeInsets.only(bottom: 2 * _s), child: Icon(Icons.error_outline, size: 16 * _s, color: Colors.redAccent)),
                  Text(task['due_time'] ?? '--:--', style: TextStyle(fontSize: 13 * _s, fontWeight: FontWeight.bold, color: overdue ? Colors.redAccent : textMuted)),
                ],
              ),
            ),
            Expanded(
              child: buildGlassContainer(
                customColor: isDone ? doneCardColor : (overdue ? Colors.redAccent.withOpacity(0.08) : null),
                padding: EdgeInsets.symmetric(horizontal: 12 * _s, vertical: 12 * _s),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 20 * _s,
                      height: 20 * _s,
                      child: Transform.scale(
                        scale: 0.9 * _s,
                        child: Checkbox(shape: const CircleBorder(), side: BorderSide(color: isDone ? glassBorderColor : (hasPriority ? priorityColor : (overdue ? Colors.redAccent : glassBorderColor)), width: 2.0), value: isDone, onChanged: (val) => onToggle(task), activeColor: Colors.blueAccent),
                      ),
                    ),
                    SizedBox(width: 10 * _s),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayTitle,
                            style: TextStyle(
                              fontSize: 15 * _s,
                              decoration: isDone ? TextDecoration.lineThrough : TextDecoration.none,
                              color: isDone ? textMuted : textColor,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (hasRecurrence || hasSubtasks || (task['tags'] != null && task['tags'].toString().trim().isNotEmpty))
                            Padding(
                              padding: EdgeInsets.only(top: 6 * _s),
                              child: Wrap(
                                spacing: 8 * _s,
                                runSpacing: 4 * _s,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  if (hasRecurrence) Icon(Icons.repeat, size: 14 * _s, color: isDone ? textMuted : Colors.orange),
                                  if (hasSubtasks) Text("[${stats['done']}/${stats['total']}]", style: TextStyle(fontSize: 12 * _s, fontWeight: FontWeight.bold, color: allDone ? Colors.green : Colors.orange)),
                                  if (task['tags'] != null && task['tags'].toString().trim().isNotEmpty)
                                    GestureDetector(onTap: () => onTagTap(task['tags'].toString().split(',')[0].trim()), child: Text("[${task['tags'].toString().split(',')[0].trim()}]", style: TextStyle(fontSize: 12 * _s, fontWeight: FontWeight.bold, color: Colors.blueAccent))),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                    IconButton(padding: EdgeInsets.zero, constraints: const BoxConstraints(), icon: Icon(Icons.close, size: 18 * _s, color: textMuted), onPressed: () => onDelete(task['id'])),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildListTaskCard(Map<String, dynamic> task) {
    final bool isDone = task['is_completed'] == true;
    bool hasPriority = task['priority'] != null && task['priority'] != 'none';
    bool hasRecurrence = task['recurrence'] != null && task['recurrence'] != 'none';
    final stats = getSubtaskStats(task['id']);
    final bool hasSubtasks = stats['total']! > 0;
    final bool allDone = hasSubtasks && stats['done'] == stats['total'];

    final bool overdue = isOverdue(task);

    return buildGlassContainer(
      margin: const EdgeInsets.only(bottom: 12),
      customColor: isDone ? doneCardColor : (overdue ? Colors.redAccent.withOpacity(0.08) : null),
      child: ListTile(
        onTap: () => onTap(task),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: Checkbox(shape: const CircleBorder(), side: BorderSide(color: isDone ? glassBorderColor : (hasPriority ? getPriorityColor(task['priority']) : (overdue ? Colors.redAccent : glassBorderColor)), width: 2.0), value: isDone, onChanged: (val) => onToggle(task), activeColor: Colors.blueAccent),
        title: Row(
          children: [
            Expanded(
              child: Text(
                task['title'] ?? '',
                style: TextStyle(fontSize: 18, decoration: isDone ? TextDecoration.lineThrough : TextDecoration.none, color: isDone ? textMuted : textColor, fontWeight: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (hasRecurrence) Padding(padding: const EdgeInsets.only(left: 8), child: Icon(Icons.repeat, size: 16, color: isDone ? textMuted : Colors.orange)),
            if (hasSubtasks) Padding(padding: const EdgeInsets.only(left: 12), child: Text("[${stats['done']}/${stats['total']}]", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: allDone ? Colors.green : Colors.orange))),
          ],
        ),
        subtitle: (task['due_time'] != null || task['note'] != null || task['tags'] != null)
            ? Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    if (task['due_date'] != null || task['due_time'] != null) ...[
                      if (overdue) const Padding(padding: EdgeInsets.only(right: 4), child: Icon(Icons.error_outline, size: 16, color: Colors.redAccent)),
                      Text("${task['due_date'] != null ? '${task['due_date']} ' : ''}${task['due_time'] ?? ''}  ", style: TextStyle(fontSize: 14, color: overdue ? Colors.redAccent : textMuted, fontWeight: overdue ? FontWeight.bold : FontWeight.normal)),
                    ],
                    if (task['tags'] != null && task['tags'].toString().trim().isNotEmpty) GestureDetector(onTap: () => onTagTap(task['tags'].toString().split(',')[0].trim()), child: Padding(padding: const EdgeInsets.only(right: 12), child: Text("[${task['tags'].toString().split(',')[0].trim()}]", style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blueAccent)))),
                    if (task['note'] != null && task['note'].toString().isNotEmpty) Expanded(child: Text(task['note'], style: TextStyle(fontSize: 14, color: textMuted), maxLines: 1, overflow: TextOverflow.ellipsis)),
                  ],
                ),
              )
            : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (task['assigned_to'] != null)
              Builder(builder: (context) {
                var members = workspaceMembers[task['workspace_id']] ?? [];
                var member = members.firstWhere(
                  (m) => m['user_id'] == task['assigned_to'],
                  orElse: () => <String, dynamic>{},
                );

                if (member.isEmpty) return const SizedBox();

                String rawName = member['full_name']?.toString().trim() ?? '';
                String name = rawName.isNotEmpty ? rawName : '?';
                String initial = name[0].toUpperCase();

                return Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Tooltip(
                    message: "Ответственный: $name",
                    child: CircleAvatar(
                      radius: 14,
                      backgroundColor: Colors.primaries[members.indexOf(member) % Colors.primaries.length].shade700,
                      child: Text(
                        initial,
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                );
              }),
            IconButton(
              icon: Icon(Icons.close, color: Colors.red[300], size: 26),
              onPressed: () => onDelete(task['id']),
            ),
          ],
        ),
      ),
    );
  }
}
