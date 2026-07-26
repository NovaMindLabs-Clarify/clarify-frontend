import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../core/theme/design_tokens.dart';
import '../core/priority.dart';
import '../core/checklist.dart';
import 'clarify_collapsing_task_row.dart';
import 'clarify_pressable.dart';
import 'clarify_task_checkbox.dart';

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
  final void Function(String priority) onPriorityTap;
  final Widget Function({
    required Widget child,
    BorderRadius? borderRadius,
    EdgeInsetsGeometry? padding,
    EdgeInsetsGeometry? margin,
    Color? customColor,
  })
  buildGlassContainer;

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
    required this.onPriorityTap,
    required this.buildGlassContainer,
  });

  double get _s => scale;
  ClarifyTokens get _t => isDark ? ClarifyTokens.dark : ClarifyTokens.light;
  Color get textColor => _t.text;
  Color get textMuted => _t.text2;
  Color get glassBorderColor => _t.border;
  Color get doneCardColor =>
      _t.surfaceSunken.withValues(alpha: isDark ? 0.7 : 0.85);

  // Компактная строка для узких колонок (Календарь/7 дней) — только чекбокс,
  // заголовок и (если есть) время второй строкой под ним. Тег/подзадачи/повтор
  // сюда намеренно не помещаются (см. REDESIGN_V3_PLAN.md §3.2/5.3) — в узкой
  // колонке они забирали место у заголовка раньше, чем он успевал показаться;
  // та же информация доступна по тапу в деталях задачи.
  Widget buildCalendarTaskRow(Map<String, dynamic> task) {
    final bool isDone = task['is_completed'] == true;
    Color priorityColor = getPriorityColor(task['priority']);
    bool hasPriority = task['priority'] != null && task['priority'] != 'none';

    final bool overdue = isOverdue(task);

    String displayTitle = task['title'] ?? '';
    final String? dueTime = task['due_time'];
    // Полоса слева — канал приоритета ТОЛЬКО (§6.4 REDESIGN_V4_PLAN.md):
    // просрочка больше не подменяет цвет полосы, когда приоритет не задан —
    // раньше оба явления делили один канал и были неразличимы на глаз.
    // Просрочка теперь — фон строки (ниже) + отдельная иконка часов у времени.
    final Color stripeColor = isDone
        ? glassBorderColor
        : (hasPriority ? priorityColor : glassBorderColor);

    return ClarifyPressable(
      onTap: () => onTap(task),
      child: Container(
        margin: EdgeInsets.only(bottom: 2 * _s, left: 4 * _s, right: 4 * _s),
        decoration: BoxDecoration(
          color: (!isDone && overdue) ? _t.dangerSoft : null,
          border: Border(
            left: BorderSide(color: stripeColor, width: 2 * _s),
          ),
        ),
        padding: EdgeInsets.symmetric(vertical: 1 * _s, horizontal: 4 * _s),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // ПРИНУДИТЕЛЬНОЕ масштабирование кругляшка
            ClarifyCheckCircle(
              size: 10 * _s,
              borderWidth: hasPriority ? 2.0 : 1.5,
              borderColor: isDone
                  ? glassBorderColor
                  : (hasPriority ? priorityColor : glassBorderColor),
              checkedColor: _t.accent,
              value: isDone,
              onTap: () => onToggle(task),
            ),
            SizedBox(width: 4 * _s),

            // Заголовок и время — одной строкой (не заголовок + время под ним),
            // чтобы ряд задачи умещался по высоте втрое компактнее и в ячейку
            // календаря реально помещалось 3 задачи, а не 1-2.
            Expanded(
              child: ClarifyStrikeText(
                text: displayTitle,
                isDone: isDone,
                style: TextStyle(
                  fontSize: 10.5 * _s,
                  fontWeight: FontWeight.w600,
                  color: isDone ? textMuted : textColor,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (dueTime != null) ...[
              SizedBox(width: 3 * _s),
              if (overdue)
                Padding(
                  padding: EdgeInsets.only(right: 2 * _s),
                  child: Icon(
                    LucideIcons.clockAlert,
                    size: 8 * _s,
                    color: _t.danger,
                  ),
                ),
              Text(
                dueTime,
                style: TextStyle(
                  fontSize: 9 * _s,
                  fontWeight: overdue ? FontWeight.bold : FontWeight.normal,
                  color: overdue ? _t.danger : textMuted,
                ),
              ),
            ],

            Builder(
              builder: (btnContext) => GestureDetector(
                onTap: () => ClarifyCollapsingTaskRow.collapseThenRun(
                  btnContext,
                  () => onDelete(task['id']),
                ),
                child: Padding(
                  padding: EdgeInsets.only(left: 4 * _s),
                  child: Icon(LucideIcons.x, size: 11 * _s, color: textMuted),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildCalendarTaskCard(Map<String, dynamic> task) {
    return LongPressDraggable<Map<String, dynamic>>(
      data: task,
      delay: const Duration(milliseconds: 200),
      feedback: Material(
        color: Colors.transparent,
        child: SizedBox(width: 150, child: buildCalendarTaskRow(task)),
      ),
      childWhenDragging: Opacity(
        opacity: 0.3,
        child: buildCalendarTaskRow(task),
      ),
      child: ClarifyCollapsingTaskRow(
        key: ValueKey(task['id']),
        child: buildCalendarTaskRow(task),
      ),
    );
  }

  Widget buildBoardTaskCardExpanded(Map<String, dynamic> task) {
    final bool isDone = task['is_completed'] == true;
    Color priorityColor = getPriorityColor(task['priority']);
    bool hasPriority = task['priority'] != null && task['priority'] != 'none';
    bool hasRecurrence =
        task['recurrence'] != null && task['recurrence'] != 'none';
    final stats = getSubtaskStats(task['id']);
    final bool hasSubtasks = stats['total']! > 0;
    final cStats = checklistStats(task['checklist']);
    final bool hasChecklist = cStats['total']! > 0;

    final bool overdue = isOverdue(task);

    String displayTitle = task['title'] ?? '';
    // Полоса слева вместо сплошной стеклянной подложки — тот же язык, что у
    // MobileTaskRow (REDESIGN_V3_PLAN §5.3): "жирный блок" был из-за границы
    // со всех сторон + заливки, здесь акцент только слева, карточка легче.
    // Канал приоритета ТОЛЬКО (§6.4 REDESIGN_V4_PLAN.md) — просрочка больше не
    // подменяет цвет полосы, у неё свой канал (иконка часов у времени слева).
    final Color stripeColor = isDone
        ? glassBorderColor
        : (hasPriority ? priorityColor : glassBorderColor);

    return ClarifyCollapsingTaskRow(
      key: ValueKey(task['id']),
      child: ClarifyPressable(
        onTap: () => onTap(task),
        child: Container(
          margin: EdgeInsets.only(bottom: 12 * _s),
          color: Colors.transparent,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment
                .center, // <-- ИДЕАЛЬНОЕ ВЫРАВНИВАНИЕ ПО ЦЕНТРУ
            children: [
              SizedBox(
                width: 44 * _s,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment:
                      MainAxisAlignment.center, // <-- Центрируем иконку и время
                  children: [
                    if (overdue)
                      Padding(
                        padding: EdgeInsets.only(bottom: 2 * _s),
                        child: Icon(
                          LucideIcons.clockAlert,
                          size: 16 * _s,
                          color: _t.danger,
                        ),
                      ),
                    Text(
                      task['due_time'] ?? '--:--',
                      style: TextStyle(
                        fontSize: 13 * _s,
                        fontWeight: FontWeight.bold,
                        color: overdue ? _t.danger : textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                // Настоящая линия, не карточка: без заливки и скругления —
                // только полоса приоритета слева и тонкий разделитель снизу.
                // Раньше здесь была та же "стеклянная" заливка+скругление, что
                // и у остальных карточек, из-за чего в узкой колонке "7 дней"
                // это читалось как жирный блок, а не строка списка.
                child: Container(
                  decoration: BoxDecoration(
                    color: (!isDone && overdue) ? _t.dangerSoft : null,
                    border: Border(
                      left: BorderSide(color: stripeColor, width: 3 * _s),
                      bottom: BorderSide(color: glassBorderColor),
                    ),
                  ),
                  padding: EdgeInsets.fromLTRB(
                    12 * _s,
                    10 * _s,
                    6 * _s,
                    10 * _s,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClarifyCheckCircle(
                        size: 18 * _s,
                        borderColor: stripeColor,
                        checkedColor: _t.accent,
                        value: isDone,
                        onTap: () => onToggle(task),
                      ),
                      SizedBox(width: 10 * _s),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClarifyStrikeText(
                              text: displayTitle,
                              isDone: isDone,
                              style: TextStyle(
                                fontSize: 15 * _s,
                                color: isDone ? textMuted : textColor,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (hasRecurrence ||
                                hasSubtasks ||
                                hasChecklist ||
                                (task['tags'] != null &&
                                    task['tags'].toString().trim().isNotEmpty))
                              Padding(
                                padding: EdgeInsets.only(top: 6 * _s),
                                child: Wrap(
                                  spacing: 8 * _s,
                                  runSpacing: 4 * _s,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    if (hasRecurrence)
                                      Icon(
                                        LucideIcons.repeat,
                                        size: 14 * _s,
                                        color: isDone ? textMuted : _t.text3,
                                      ),
                                    if (hasSubtasks)
                                      ClarifySubtaskBadge(
                                        done: stats['done']!,
                                        total: stats['total']!,
                                        tokens: _t,
                                        scale: _s,
                                      ),
                                    if (hasChecklist)
                                      ClarifySubtaskBadge(
                                        done: cStats['done']!,
                                        total: cStats['total']!,
                                        tokens: _t,
                                        scale: _s,
                                        icon: LucideIcons.listTodo,
                                      ),
                                    if (task['tags'] != null &&
                                        task['tags']
                                            .toString()
                                            .trim()
                                            .isNotEmpty)
                                      GestureDetector(
                                        onTap: () => onTagTap(
                                          task['tags']
                                              .toString()
                                              .split(',')[0]
                                              .trim(),
                                        ),
                                        child: Text(
                                          "[${task['tags'].toString().split(',')[0].trim()}]",
                                          style: TextStyle(
                                            fontSize: 12 * _s,
                                            fontWeight: FontWeight.bold,
                                            color: _t.accent,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                      Builder(
                        builder: (btnContext) => IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: Icon(
                            LucideIcons.x,
                            size: 18 * _s,
                            color: textMuted,
                          ),
                          onPressed: () =>
                              ClarifyCollapsingTaskRow.collapseThenRun(
                                btnContext,
                                () => onDelete(task['id']),
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildListTaskCard(Map<String, dynamic> task) {
    final bool isDone = task['is_completed'] == true;
    final cStats = checklistStats(task['checklist']);
    final bool hasChecklist = cStats['total']! > 0;
    bool hasPriority = task['priority'] != null && task['priority'] != 'none';
    bool hasRecurrence =
        task['recurrence'] != null && task['recurrence'] != 'none';
    final stats = getSubtaskStats(task['id']);
    final bool hasSubtasks = stats['total']! > 0;

    final bool overdue = isOverdue(task);

    // Раньше это был ListTile: leading/trailing он центрирует по всей высоте
    // плитки (с учётом subtitle), а бейдж подзадач в title — по верху title-
    // строки. Из-за этого X и бейдж оказывались на разных высотах, когда
    // была видна subtitle-строка (время/тег/заметка). Обычный Row с единым
    // crossAxisAlignment.start убирает рассинхронизацию — так же, как уже
    // сделано в buildBoardTaskCardExpanded.
    return ClarifyCollapsingTaskRow(
      key: ValueKey(task['id']),
      child: buildGlassContainer(
        margin: const EdgeInsets.only(bottom: 12),
        customColor: isDone ? doneCardColor : (overdue ? _t.dangerSoft : null),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: GestureDetector(
          onTap: () => onTap(task),
          behavior: HitTestBehavior.opaque,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClarifyCheckCircle(
                size: 22,
                borderColor: isDone
                    ? glassBorderColor
                    : (hasPriority
                          ? getPriorityColor(task['priority'])
                          : glassBorderColor),
                checkedColor: _t.accent,
                value: isDone,
                onTap: () => onToggle(task),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: ClarifyStrikeText(
                            text: task['title'] ?? '',
                            isDone: isDone,
                            style: TextStyle(
                              fontSize: 18,
                              color: isDone ? textMuted : textColor,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (hasRecurrence)
                          Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: Icon(
                              LucideIcons.repeat,
                              size: 16,
                              color: isDone ? textMuted : _t.text3,
                            ),
                          ),
                        if (hasSubtasks)
                          Padding(
                            padding: const EdgeInsets.only(left: 12),
                            child: ClarifySubtaskBadge(
                              done: stats['done']!,
                              total: stats['total']!,
                              tokens: _t,
                            ),
                          ),
                        if (hasChecklist)
                          Padding(
                            padding: const EdgeInsets.only(left: 12),
                            child: ClarifySubtaskBadge(
                              done: cStats['done']!,
                              total: cStats['total']!,
                              tokens: _t,
                              icon: LucideIcons.listTodo,
                            ),
                          ),
                      ],
                    ),
                    if (task['due_time'] != null ||
                        task['note'] != null ||
                        task['tags'] != null ||
                        priorityFlagLabel(task['priority']).isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Row(
                          children: [
                            if (priorityFlagLabel(task['priority']).isNotEmpty)
                              GestureDetector(
                                onTap: () => onPriorityTap(task['priority']),
                                child: Padding(
                                  padding: const EdgeInsets.only(right: 12),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        LucideIcons.flag,
                                        size: 14,
                                        color: getPriorityColor(task['priority']),
                                      ),
                                      const SizedBox(width: 3),
                                      Text(
                                        priorityFlagLabel(task['priority']),
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: getPriorityColor(task['priority']),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            if (task['due_date'] != null ||
                                task['due_time'] != null) ...[
                              if (overdue)
                                Padding(
                                  padding: const EdgeInsets.only(right: 4),
                                  child: Icon(
                                    LucideIcons.clockAlert,
                                    size: 16,
                                    color: _t.danger,
                                  ),
                                ),
                              Text(
                                "${task['due_date'] != null ? '${task['due_date']} ' : ''}${task['due_time'] ?? ''}  ",
                                style: TextStyle(
                                  fontSize: 14,
                                  color: overdue ? _t.danger : textMuted,
                                  fontWeight: overdue
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                            ],
                            if (task['tags'] != null &&
                                task['tags'].toString().trim().isNotEmpty)
                              GestureDetector(
                                onTap: () => onTagTap(
                                  task['tags'].toString().split(',')[0].trim(),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.only(right: 12),
                                  child: Text(
                                    "[${task['tags'].toString().split(',')[0].trim()}]",
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: _t.accent,
                                    ),
                                  ),
                                ),
                              ),
                            if (task['note'] != null &&
                                task['note'].toString().isNotEmpty)
                              Expanded(
                                child: Text(
                                  task['note'],
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: textMuted,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (task['assigned_to'] != null)
                Builder(
                  builder: (context) {
                    var members = workspaceMembers[task['workspace_id']] ?? [];
                    var member = members.firstWhere(
                      (m) => m['user_id'] == task['assigned_to'],
                      orElse: () => <String, dynamic>{},
                    );

                    if (member.isEmpty) return const SizedBox();

                    String rawName =
                        member['full_name']?.toString().trim() ?? '';
                    String name = rawName.isNotEmpty ? rawName : '?';
                    String initial = name[0].toUpperCase();
                    final avatarColor =
                        _t.tagPalette[members.indexOf(member) %
                            _t.tagPalette.length];

                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Tooltip(
                        message: "Ответственный: $name",
                        child: CircleAvatar(
                          radius: 14,
                          backgroundColor: avatarColor,
                          child: Text(
                            initial,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              Builder(
                builder: (btnContext) => IconButton(
                  icon: Icon(LucideIcons.x, color: _t.danger, size: 22),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 28,
                    minHeight: 28,
                  ),
                  onPressed: () => ClarifyCollapsingTaskRow.collapseThenRun(
                    btnContext,
                    () => onDelete(task['id']),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
