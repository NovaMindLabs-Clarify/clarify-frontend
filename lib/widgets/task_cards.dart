import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../core/clarify_date_format.dart';
import '../core/theme/design_tokens.dart';
import '../core/priority.dart';
import '../core/checklist.dart';
import 'clarify_collapsing_task_row.dart';
import 'clarify_pressable.dart';
import 'clarify_quick_actions_sheet.dart';
import 'clarify_task_checkbox.dart';

// `overdue`, переданный сюда извне (isOverdue-колбэк родителя), уже сам
// возвращает false для выполненных задач — из-за этого он и `isDone`
// схлопываются в false/true ОДНОВРЕМЕННО в один и тот же ребилд, и слот под
// иконку просрочки по условию `if (overdue)` не может резервировать место
// заранее: к моменту, когда задача отмечена выполненной, само условие уже
// ложно. Эта функция — та же проверка "дедлайн уже прошёл", но БЕЗ раннего
// return по is_completed, специально для резервирования места под иконку
// (тот же приём, что и в mobile_task_row.dart:_wasPastDue — раздельные
// файлы, см. комментарий в начале того файла про дублирование бейджей).
bool _wasPastDue(Map<String, dynamic> task) {
  if (task['due_date'] == null) return false;
  final date = parseClarifyDate(task['due_date']);
  if (date == null) return false;
  int hour = 23;
  int minute = 59;
  if (task['due_time'] != null && task['due_time'].toString().contains(':')) {
    final parts = task['due_time'].toString().split(':');
    hour = int.tryParse(parts[0]) ?? 23;
    minute = int.tryParse(parts[1]) ?? 59;
  }
  final dueDateTime = DateTime(date.year, date.month, date.day, hour, minute);
  return DateTime.now().isAfter(dueDateTime);
}

/// Строит карточки задачи для трёх представлений (список, доска "7 дней",
/// календарь). Вынесено из DesktopPlannerScreen (P3.1, docs/IMPROVEMENT_PLAN.md) —
/// логика и разметка не менялись, только доступ к состоянию родителя заменён
/// на явные параметры конструктора.
class TaskCardBuilders {
  final bool isDark;
  final double scale;
  final String currentLang;
  final Map<int, List<Map<String, dynamic>>> workspaceMembers;
  final Color Function(String? priority) getPriorityColor;
  final Map<String, int> Function(dynamic parentId) getSubtaskStats;
  final bool Function(Map<String, dynamic> task) isOverdue;
  final void Function(Map<String, dynamic> task) onToggle;
  final void Function(dynamic taskId) onDelete;
  final void Function(Map<String, dynamic> task) onTap;
  final void Function(String tag) onTagTap;
  final void Function(String priority) onPriorityTap;
  final void Function(dynamic taskId, Map<String, dynamic> updates)
  onQuickUpdateTask;
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
    required this.currentLang,
    required this.workspaceMembers,
    required this.getPriorityColor,
    required this.getSubtaskStats,
    required this.isOverdue,
    required this.onToggle,
    required this.onDelete,
    required this.onTap,
    required this.onTagTap,
    required this.onPriorityTap,
    required this.onQuickUpdateTask,
    required this.buildGlassContainer,
  });

  double get _s => scale;
  ClarifyTokens get _t => isDark ? ClarifyTokens.dark : ClarifyTokens.light;
  Color get textColor => _t.text;
  Color get textMuted => _t.text2;
  Color get glassBorderColor => _t.border;
  Color get doneCardColor =>
      _t.surfaceSunken.withValues(alpha: isDark ? 0.7 : 0.85);

  // Реализация — общие функции buildRotBadge/buildRescheduleBadge в
  // clarify_task_checkbox.dart (переиспользуются и mobile_task_row.dart).
  // Тап по бейджу гниения — не просто визуальная метка, а вход в быстрые
  // действия (см. showTaskRotQuickActions): пассивный бейдж рискует со
  // временем стать фоновым шумом, который перестают замечать.
  Widget? _rotBadge(Map<String, dynamic> task, bool isDone, bool overdue) {
    final badge = buildRotBadge(
      task: task,
      isDone: isDone,
      overdue: overdue,
      tokens: _t,
      currentLang: currentLang,
      scale: _s,
    );
    if (badge == null) return null;
    return Builder(
      builder: (context) => GestureDetector(
        onTap: () => showTaskRotQuickActions(
          context: context,
          isDark: isDark,
          currentLang: currentLang,
          onDoToday: () => onQuickUpdateTask(task['id'], {
            'due_date': formatClarifyDate(DateTime.now()),
          }),
          onClearDeadline: () => onQuickUpdateTask(task['id'], {
            'due_date': null,
            'due_time': null,
            'duration_minutes': null,
          }),
          onDelete: () => onDelete(task['id']),
        ),
        child: badge,
      ),
    );
  }

  Widget? _rescheduleBadge(Map<String, dynamic> task, bool isDone) {
    return buildRescheduleBadge(
      task: task,
      isDone: isDone,
      tokens: _t,
      currentLang: currentLang,
      scale: _s,
    );
  }

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
      child: AnimatedContainer(
        duration: ClarifyMotion.completion,
        curve: ClarifyMotion.standard,
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
              duration: ClarifyMotion.completion,
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
              if (_wasPastDue(task))
                Padding(
                  padding: EdgeInsets.only(right: 2 * _s),
                  child: SizedBox(
                    width: 8 * _s,
                    height: 8 * _s,
                    child: AnimatedOpacity(
                      opacity: isDone ? 0 : 1,
                      duration: ClarifyMotion.completion,
                      curve: ClarifyMotion.standard,
                      child: Icon(
                        LucideIcons.clockAlert,
                        size: 8 * _s,
                        color: _t.danger,
                      ),
                    ),
                  ),
                ),
              AnimatedDefaultTextStyle(
                duration: ClarifyMotion.completion,
                curve: ClarifyMotion.standard,
                style: TextStyle(
                  fontSize: 9 * _s,
                  fontWeight: overdue ? FontWeight.bold : FontWeight.normal,
                  color: overdue ? _t.danger : textMuted,
                ),
                child: Text(dueTime),
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

  // Google/Apple-calendar стиль: цветная полоска приоритета (тот же язык,
  // что и у buildCalendarTaskRow) вместо чекбокса — детали открытия/отметки
  // выполненной по тапу, не в самой ячейке. Вторая строка (приоритет,
  // просрочка, гниение, перенос) добавлена по прямому запросу — "как в
  // Мой день/Все задачи, места теперь достаточно" (2026-08-01), после того
  // как первая версия (только время+название) освободила ячейке заметный
  // запас высоты. Нужен отдельно от buildCalendarTaskRow (не просто его
  // уменьшением): месячная сетка статична (без скролла) и обязана
  // гарантированно вмещать 3 задачи в ячейке при любом размере окна.
  // Высота строки-превью в ячейке календаря должна быть ФИКСИРОВАННОЙ (не
  // зависеть от того, есть ли у задачи бейджи/приоритет) — это единственный
  // надёжный способ для _CalendarDayTasksPreview (main_content_area.dart)
  // достоверно посчитать, сколько задач реально влезает в ячейку, не
  // дублируя здесь и там всю логику "есть ли у задачи вторая строка". Живой
  // баг (2026-08-02): счётчик "влезает 3" был жёстко зашит без учёта
  // реальной высоты — пилюля "+1" накладывалась на текст 3-й задачи, когда
  // задачи стали двухстрочными. Проверено тестом (task_cards_test.dart) —
  // рендер с бейджами и без даёт одинаковую высоту.
  static double calendarChipHeight(double scale) => 26 * scale;
  static const double _calendarChipLine2Height = 13;

  Widget _calendarTaskChipRow(Map<String, dynamic> task) {
    final bool isDone = task['is_completed'] == true;
    final bool hasPriority = task['priority'] != null && task['priority'] != 'none';
    final Color stripeColor = isDone ? glassBorderColor : (hasPriority ? getPriorityColor(task['priority']) : glassBorderColor);
    final String? dueTime = task['due_time'] as String?;
    final bool overdue = isOverdue(task);
    // Компактнее, чем в списке/доске (scale*0.75) — тот же бейдж, тот же
    // компонент, просто меньше, чтобы не расталкивать 3-ю строку превью. Без
    // обёртки в быстрые действия (_rotBadge) — тап по всей строке уже ведёт
    // к деталям задачи, где тот же бейдж уже с быстрыми действиями.
    final rotBadge = buildRotBadge(task: task, isDone: isDone, overdue: overdue, tokens: _t, currentLang: currentLang, scale: _s * 0.75);
    final rescheduleBadge = buildRescheduleBadge(task: task, isDone: isDone, tokens: _t, currentLang: currentLang, scale: _s * 0.75);
    final priorityLabel = priorityFlagLabel(task['priority']);

    return ClarifyPressable(
      onTap: () => onTap(task),
      child: Container(
        margin: EdgeInsets.only(bottom: 1 * _s),
        decoration: BoxDecoration(border: Border(left: BorderSide(color: stripeColor, width: 2 * _s))),
        padding: EdgeInsets.symmetric(horizontal: 3 * _s),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Строка 1: время (если задано) + название. Время — своя Text,
            // не часть ClarifyStrikeText — временная метка не "перечёркнутый
            // факт", даже когда сама задача выполнена.
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (dueTime != null) ...[
                  Text(dueTime, style: TextStyle(fontSize: 9 * _s, fontWeight: FontWeight.w600, color: isDone ? textMuted : _t.text3)),
                  SizedBox(width: 4 * _s),
                ],
                Flexible(
                  child: ClarifyStrikeText(
                    text: task['title'] ?? '',
                    isDone: isDone,
                    style: TextStyle(fontSize: 9 * _s, fontWeight: FontWeight.w600, color: isDone ? textMuted : textColor),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            // Строка 2: приоритет + просрочка + гниение + перенос — та же
            // информация и те же анимации (вход/выход, opacity), что и в
            // Мой день/Все задачи, просто мельче. Высота ВСЕГДА
            // зарезервирована (SizedBox), даже когда показывать нечего —
            // без этого высота строки менялась бы от задачи к задаче, и
            // _CalendarDayTasksPreview не могла бы достоверно посчитать,
            // сколько задач влезает в ячейку.
            SizedBox(
              height: _calendarChipLine2Height * _s,
              child: (_wasPastDue(task) || priorityLabel.isNotEmpty || rotBadge != null || rescheduleBadge != null)
                  ? Wrap(
                      spacing: 4 * _s,
                      runSpacing: 1 * _s,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (_wasPastDue(task))
                          SizedBox(
                            width: 8 * _s,
                            height: 8 * _s,
                            child: AnimatedOpacity(
                              opacity: isDone ? 0 : 1,
                              duration: ClarifyMotion.completion,
                              curve: ClarifyMotion.standard,
                              child: Icon(LucideIcons.clockAlert, size: 8 * _s, color: _t.danger),
                            ),
                          ),
                        if (priorityLabel.isNotEmpty)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(LucideIcons.flag, size: 8 * _s, color: getPriorityColor(task['priority'])),
                              SizedBox(width: 1 * _s),
                              Text(priorityLabel, style: TextStyle(fontSize: 8 * _s, fontWeight: FontWeight.bold, color: getPriorityColor(task['priority']))),
                            ],
                          ),
                        clarifyAnimatedBadgeSlot(rotBadge),
                        clarifyAnimatedBadgeSlot(rescheduleBadge),
                      ],
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  /// Та же обёртка drag-and-drop, что и у buildCalendarTaskCard (перенос
  /// задачи на другой день зажатием) — по прямому запросу пользователя
  /// сохранить эту возможность и для компактного превью в ячейке месяца.
  Widget buildCalendarTaskChip(Map<String, dynamic> task) {
    return LongPressDraggable<Map<String, dynamic>>(
      data: task,
      delay: const Duration(milliseconds: 200),
      feedback: Material(
        color: Colors.transparent,
        child: SizedBox(width: 150, child: _calendarTaskChipRow(task)),
      ),
      childWhenDragging: Opacity(
        opacity: 0.3,
        child: _calendarTaskChipRow(task),
      ),
      child: ClarifyCollapsingTaskRow(
        key: ValueKey(task['id']),
        child: _calendarTaskChipRow(task),
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
                    if (_wasPastDue(task))
                      Padding(
                        padding: EdgeInsets.only(bottom: 2 * _s),
                        child: SizedBox(
                          width: 16 * _s,
                          height: 16 * _s,
                          child: AnimatedOpacity(
                            opacity: isDone ? 0 : 1,
                            duration: ClarifyMotion.completion,
                            curve: ClarifyMotion.standard,
                            child: Icon(
                              LucideIcons.clockAlert,
                              size: 16 * _s,
                              color: _t.danger,
                            ),
                          ),
                        ),
                      ),
                    AnimatedDefaultTextStyle(
                      duration: ClarifyMotion.completion,
                      curve: ClarifyMotion.standard,
                      style: TextStyle(
                        fontSize: 13 * _s,
                        fontWeight: FontWeight.bold,
                        color: overdue ? _t.danger : textMuted,
                      ),
                      child: Text(task['due_time'] ?? '--:--'),
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
                child: AnimatedContainer(
                  duration: ClarifyMotion.completion,
                  curve: ClarifyMotion.standard,
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
                        duration: ClarifyMotion.completion,
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
                                _rotBadge(task, isDone, overdue) != null ||
                                _rescheduleBadge(task, isDone) != null ||
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
                                    // Схлопывается, когда сама задача выполнена —
                                    // счётчик подзадач не нужен после закрытия
                                    // всей задачи целиком.
                                    if (hasSubtasks)
                                      AnimatedSize(
                                        duration: ClarifyMotion.completion,
                                        curve: ClarifyMotion.standard,
                                        child: isDone
                                            ? const SizedBox.shrink()
                                            : ClarifySubtaskBadge(
                                                done: stats['done']!,
                                                total: stats['total']!,
                                                tokens: _t,
                                                scale: _s,
                                              ),
                                      ),
                                    if (hasChecklist)
                                      AnimatedSize(
                                        duration: ClarifyMotion.completion,
                                        curve: ClarifyMotion.standard,
                                        child: isDone
                                            ? const SizedBox.shrink()
                                            : ClarifySubtaskBadge(
                                                done: cStats['done']!,
                                                total: cStats['total']!,
                                                tokens: _t,
                                                scale: _s,
                                                icon: LucideIcons.listTodo,
                                              ),
                                      ),
                                    clarifyAnimatedBadgeSlot(_rotBadge(task, isDone, overdue)),
                                    clarifyAnimatedBadgeSlot(_rescheduleBadge(task, isDone)),
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
                duration: ClarifyMotion.completion,
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
                        // Схлопывается, когда сама задача выполнена — счётчик
                        // подзадач не нужен после закрытия всей задачи целиком.
                        if (hasSubtasks)
                          Padding(
                            padding: const EdgeInsets.only(left: 12),
                            child: AnimatedSize(
                              duration: ClarifyMotion.completion,
                              curve: ClarifyMotion.standard,
                              child: isDone
                                  ? const SizedBox.shrink()
                                  : ClarifySubtaskBadge(
                                      done: stats['done']!,
                                      total: stats['total']!,
                                      tokens: _t,
                                    ),
                            ),
                          ),
                        if (hasChecklist)
                          Padding(
                            padding: const EdgeInsets.only(left: 12),
                            child: AnimatedSize(
                              duration: ClarifyMotion.completion,
                              curve: ClarifyMotion.standard,
                              child: isDone
                                  ? const SizedBox.shrink()
                                  : ClarifySubtaskBadge(
                                      done: cStats['done']!,
                                      total: cStats['total']!,
                                      tokens: _t,
                                      icon: LucideIcons.listTodo,
                                    ),
                            ),
                          ),
                      ],
                    ),
                    // Гниение/перенос — на второй строке РЯДОМ с иконкой
                    // просрочки, а не в строке заголовка: ровно та же
                    // группировка, что и на мобильной версии
                    // (mobile_task_row.dart — своя, отдельная от даты/тегов/
                    // счётчиков строка). Раньше стояли в строке заголовка —
                    // из-за этого визуально терялись среди чекбокса/
                    // зачёркивания/счётчиков подзадач (фидбек пользователя
                    // 2026-08-01: "не появились значки переносов и гниения").
                    // due_date (без due_time) и сами бейджи добавлены в
                    // условие показа строки ниже — раньше строка целиком не
                    // рендерилась, если у задачи не было ни due_time, ни
                    // note/tags/приоритета, даже если гниение/перенос были.
                    if (task['due_date'] != null ||
                        task['due_time'] != null ||
                        task['note'] != null ||
                        task['tags'] != null ||
                        priorityFlagLabel(task['priority']).isNotEmpty ||
                        _rotBadge(task, isDone, overdue) != null ||
                        _rescheduleBadge(task, isDone) != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        // crossAxisAlignment.center на плоском Row centrирует
                        // каждый элемент отдельно относительно высоты САМОГО
                        // высокого соседа (например бейджа гниения/переноса
                        // со своим внутренним padding) — из-за этого голая
                        // иконка/текст визуально "съезжали" относительно
                        // друг друга, хотя формально все центрированы (живой
                        // фидбек 2026-08-01: "значок просрочки не по
                        // середине... заметка и тег на другой высоте
                        // относительно даты"). Группируем каждую пару
                        // иконка+текст в свой Row — их взаимное выравнивание
                        // считается только относительно друг друга, а не
                        // случайного самого высокого элемента строки.
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            if (priorityFlagLabel(task['priority']).isNotEmpty)
                              GestureDetector(
                                onTap: () => onPriorityTap(task['priority']),
                                child: Padding(
                                  padding: const EdgeInsets.only(right: 12),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.center,
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
                                task['due_time'] != null)
                              Padding(
                                padding: const EdgeInsets.only(right: 12),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    if (_wasPastDue(task))
                                      Padding(
                                        padding: const EdgeInsets.only(right: 4),
                                        child: SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: AnimatedOpacity(
                                            opacity: isDone ? 0 : 1,
                                            duration: ClarifyMotion.completion,
                                            curve: ClarifyMotion.standard,
                                            child: Icon(
                                              LucideIcons.clockAlert,
                                              size: 16,
                                              color: _t.danger,
                                            ),
                                          ),
                                        ),
                                      ),
                                    AnimatedDefaultTextStyle(
                                      duration: ClarifyMotion.completion,
                                      curve: ClarifyMotion.standard,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: overdue ? _t.danger : textMuted,
                                        fontWeight: overdue
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                      ),
                                      child: Text(
                                        "${task['due_date'] != null ? '${task['due_date']} ' : ''}${task['due_time'] ?? ''}",
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            // clarifyAnimatedBadgeSlot — анимирует и вход, И
                            // выход (AnimatedSize+AnimatedOpacity), в точности
                            // как на мобильной версии.
                            Padding(
                              padding: const EdgeInsets.only(right: 12),
                              child: clarifyAnimatedBadgeSlot(_rotBadge(task, isDone, overdue)),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(right: 12),
                              child: clarifyAnimatedBadgeSlot(_rescheduleBadge(task, isDone)),
                            ),
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
