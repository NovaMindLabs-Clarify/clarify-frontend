import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../core/clarify_date_format.dart';
import '../core/theme/design_tokens.dart';
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

  /// Масштаб строки задачи. Раньше строка была единственным местом с
  /// фиксированными размерами: шапка, сайдбар и всё остальное сжимаются вместе
  /// с окном через [scale], а строка нет — на окне 1000px заголовок раздела
  /// становился почти одного кегля с названием задачи, и список выглядел
  /// непропорционально крупным (живой фидбек 2026-09-04: «блоки огромные, как
  /// и сам текст»).
  ///
  /// Масштабируется мягче остального: у текста задачи есть нижняя граница
  /// читаемости, ниже которой уменьшать нельзя, поэтому не голый [scale], а
  /// сжатый диапазон.
  double get _rowScale => (0.7 + _s * 0.3).clamp(0.88, 1.1);

  /// Масштаб строки-превью в ячейке месяца. Там всё и так мелкое (кегль 9 при
  /// единичном масштабе), а [_s] на окне 1100px опускается до 0.57 — текст
  /// превращался в 5 пикселей, то есть в нечитаемую рябь. Нижняя граница
  /// нужна именно здесь, а не в общем [_rowScale]: ячейка календаря
  /// принципиально теснее строки списка.
  double get _chipScale => _s.clamp(0.85, 1.1);
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
  Widget? _rotBadge(
    Map<String, dynamic> task,
    bool isDone,
    bool overdue, {
    bool compact = false,
  }) {
    final badge = buildRotBadge(
      task: task,
      isDone: isDone,
      overdue: overdue,
      tokens: _t,
      currentLang: currentLang,
      // _rowScale, а не _s: сигналы живут внутри строки задачи и обязаны
      // масштабироваться вместе с ней. На узком окне _s опускается до 0.4-0.5,
      // и фраза «лежит без движения 38 дней» превращалась в нечитаемые 6px.
      scale: _rowScale,
      compact: compact,
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

  Widget? _rescheduleBadge(
    Map<String, dynamic> task,
    bool isDone, {
    bool compact = false,
  }) {
    return buildRescheduleBadge(
      task: task,
      isDone: isDone,
      tokens: _t,
      currentLang: currentLang,
      scale: _rowScale,
      compact: compact,
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
  // что и у buildCalendarTaskRow). Чекбокс в ячейке сперва не рисовали
  // (отметка предполагалась через детали задачи по тапу), но по фидбеку
  // 2026-09-03 кружок вернули — см. комментарий у самого ClarifyCheckCircle
  // ниже. Вторая строка (приоритет,
  // просрочка, гниение, перенос) добавлена по прямому запросу — "как в
  // Мой день/Все задачи, места теперь достаточно" (2026-08-01), после того
  // как первая версия (только время+название) освободила ячейке заметный
  // запас высоты. Нужен отдельно от buildCalendarTaskRow (не просто его
  // уменьшением): месячная сетка статична (без скролла) и обязана
  // гарантированно вмещать 3 задачи в ячейке при любом размере окна.
  // Высота строки-превью в ячейке календаря ФИКСИРОВАНА (не зависит от того,
  // есть ли у задачи бейджи/приоритет) — без этого высота "плавала" бы от
  // задачи к задаче, и _CalendarDayTasksPreview не могла бы измерить её по
  // одной-единственной задаче и считать эту высоту одинаковой для всех
  // остальных. Проверено тестом (task_cards_test.dart) — рендер с бейджами и
  // без даёт одинаковую высоту.
  //
  // calendarChipHeight ниже — НЕ источник истины (первая попытка фикса
  // 2026-08-02 полагалась на неё как на константу, подобранную по замеру в
  // виджет-тесте; тест рендерит текст ДРУГИМ шрифтом, не настоящим Golos
  // Text, так что "измеренная" высота разошлась с реальной в собранном
  // приложении — 3 задачи вместо переполнения стали помещаться только 2 с
  // пустым местом под ними). Используется только как консервативная оценка
  // для самого первого кадра _CalendarDayTasksPreview, пока не пришло
  // РЕАЛЬНОЕ измерение (Offstage-зонд) — после него эта константа не влияет
  // ни на что.
  static double calendarChipHeight(double scale) => 28 * scale;

  Widget _calendarTaskChipRow(Map<String, dynamic> task) {
    final bool isDone = task['is_completed'] == true;
    final bool hasPriority =
        task['priority'] != null && task['priority'] != 'none';
    final Color stripeColor = isDone
        ? glassBorderColor
        : (hasPriority ? getPriorityColor(task['priority']) : glassBorderColor);
    final String? dueTime = task['due_time'] as String?;
    final bool overdue = isOverdue(task);
    // Компактнее, чем в списке/доске (scale*0.75) — тот же бейдж, тот же
    // компонент, просто меньше, чтобы не расталкивать 3-ю строку превью. Без
    // обёртки в быстрые действия (_rotBadge) — тап по всей строке уже ведёт
    // к деталям задачи, где тот же бейдж уже с быстрыми действиями.
    final rotBadge = buildRotBadge(
      task: task,
      isDone: isDone,
      overdue: overdue,
      tokens: _t,
      currentLang: currentLang,
      scale: _chipScale * 0.8,
      // Ячейка месяца шириной в сотню пикселей: фраза целиком туда не влезет,
      // а обрезанная многоточием фраза хуже короткого числа.
      compact: true,
    );
    final rescheduleBadge = buildRescheduleBadge(
      task: task,
      isDone: isDone,
      tokens: _t,
      currentLang: currentLang,
      scale: _chipScale * 0.8,
      compact: true,
    );
    // Размеры считаются от РЕАЛЬНОЙ ширины ячейки, а не от масштаба окна
    // (2026-09-04). Прежняя привязка к scale давала обе крайности сразу: на
    // окне 1100px строка сжималась в нечитаемую рябь, а на полном экране, где
    // ячейка размером с визитку, текст упирался в потолок масштаба и тонул в
    // пустоте. Ячейке важна её собственная ширина, а не то, какое окно вокруг.
    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.maxWidth;
        // 0.055 от ширины: на узкой ячейке (100px) даёт нижнюю границу
        // читаемости, на широкой (275px) — спокойный кегль 14, соразмерный
        // самой ячейке. Границы жёсткие, чтобы на экстремумах не уехало.
        final double titleSize = (width * 0.055).clamp(9.5, 14.0);
        final double timeSize = titleSize - 1.5;
        final double circleSize = titleSize * 0.9;
        // Время прячем, только если оно физически отнимает у названия больше,
        // чем даёт само: на узкой ячейке от названия оставались три буквы с
        // многоточием. Порог — по ширине ячейки, а не по масштабу окна.
        final bool showTime = dueTime != null && width >= 108;

        return ClarifyPressable(
          onTap: () => onTap(task),
          child: Container(
            margin: const EdgeInsets.only(bottom: 1),
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(color: stripeColor, width: 2),
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Строка 1: время (если влезает) + название. Время — своя Text,
                // не часть ClarifyStrikeText: временная метка не «перечёркнутый
                // факт», даже когда сама задача выполнена.
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Отметить выполненной прямо из ячейки месяца (фидбек
                    // 2026-09-03): раньше кружка тут не было сознательно —
                    // предполагалось отмечать по тапу в деталях задачи, но на
                    // практике календарь оказался единственным разделом, где
                    // задачу нельзя закрыть в один клик.
                    ClarifyCheckCircle(
                      size: circleSize,
                      borderWidth: hasPriority ? 1.5 : 1.2,
                      borderColor: stripeColor,
                      checkedColor: _t.accent,
                      value: isDone,
                      onTap: () => onToggle(task),
                      duration: ClarifyMotion.completion,
                    ),
                    const SizedBox(width: 4),
                    if (showTime) ...[
                      Text(
                        dueTime,
                        style: TextStyle(
                          fontSize: timeSize,
                          fontWeight: FontWeight.w600,
                          color: isDone ? textMuted : _t.text3,
                        ),
                      ),
                      const SizedBox(width: 5),
                    ],
                    Flexible(
                      child: ClarifyStrikeText(
                        text: task['title'] ?? '',
                        isDone: isDone,
                        style: TextStyle(
                          fontSize: titleSize,
                          fontWeight: FontWeight.w600,
                          color: isDone ? textMuted : textColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                // Строка 2: просрочка + гниение + перенос. Высота ВСЕГДА
                // зарезервирована, даже когда показывать нечего — без этого
                // высота строки менялась бы от задачи к задаче, и
                // _CalendarDayTasksPreview не могла бы достоверно посчитать,
                // сколько задач влезает в ячейку.
                SizedBox(
                  height: titleSize * 1.25,
                  child:
                      (_wasPastDue(task) ||
                          rotBadge != null ||
                          rescheduleBadge != null)
                      ? Wrap(
                          spacing: 4,
                          runSpacing: 1,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            if (_wasPastDue(task))
                              SizedBox(
                                width: timeSize,
                                height: timeSize,
                                child: AnimatedOpacity(
                                  opacity: isDone ? 0 : 1,
                                  duration: ClarifyMotion.completion,
                                  curve: ClarifyMotion.standard,
                                  child: Icon(
                                    LucideIcons.clockAlert,
                                    size: timeSize,
                                    color: _t.danger,
                                  ),
                                ),
                              ),
                            // Подпись приоритета («P1»…«P4») из ячейки месяца
                            // убрана (2026-09-04): приоритет и так виден
                            // цветной кромкой слева и обводкой кружка, а
                            // буквенный код без легенды ничего не сообщает.
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
      },
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

  /// Строка задачи в колонке «7 дней» и на доске проекта. С 2026-09-04 живёт
  /// по тем же правилам, что и строка списка: круга-чекбокса нет, вместо него
  /// зона выполнения, проявляющаяся под курсором.
  Widget buildBoardTaskCardExpanded(Map<String, dynamic> task) {
    return _HoverRowShell(
      builder: (hovered) => _buildBoardRowBody(task, hovered: hovered),
    );
  }

  Widget _buildBoardRowBody(Map<String, dynamic> task, {required bool hovered}) {
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
                      _completionZone(
                        task,
                        isDone: isDone,
                        hovered: hovered,
                        size: 15 * _s,
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClarifyStrikeText(
                              text: displayTitle,
                              isDone: isDone,
                              // bold → w600 и кегль по общему масштабу строки:
                              // жирное начертание в узкой колонке спорило с
                              // заголовком самой колонки (2026-09-04).
                              style: TextStyle(
                                fontSize: 14.5 * _rowScale,
                                color: isDone ? textMuted : textColor,
                                fontWeight: overdue && !isDone
                                    ? FontWeight.w700
                                    : FontWeight.w600,
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
                                    // Колонка «7 дней» узкая — сигналы здесь в
                                    // короткой форме, фраза целиком не влезет.
                                    clarifyAnimatedBadgeSlot(
                                      _rotBadge(task, isDone, overdue, compact: true),
                                    ),
                                    clarifyAnimatedBadgeSlot(
                                      _rescheduleBadge(task, isDone, compact: true),
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

  /// Строка задачи в списках («Мой день», «Все задачи», «Входящие», команды).
  ///
  /// Переписана 2026-09-04. Была: стеклянная карточка со скруглением, полосой
  /// приоритета и кругом-чекбоксом, ~90px высотой — приём, по которому продукт
  /// не отличить от любого другого (живой фидбек: «видел уже два проекта с
  /// абсолютно идентичными блочками»). Стало: строка документа без подложки и
  /// без круга.
  ///
  /// Круг убран не ради минимализма: он занимал место постоянно, а нужен раз
  /// в день. Вместо него зона выполнения по левой кромке — галочка проявляется
  /// при наведении, у выполненной задачи видна всегда (иначе состояние
  /// читалось бы только по зачёркиванию). Крестик удаления тоже показывается
  /// только под курсором: постоянно висящий крестик и шумит, и провоцирует
  /// случайные удаления.
  ///
  /// Всё поведение прежнее: тап открывает детали, зона выполнения отмечает,
  /// крестик удаляет через схлопывание, бейджи гниения и переносов со своими
  /// быстрыми действиями на месте, тег кликабелен, аватар ответственного и
  /// счётчики подзадач/чек-листа сохранены.
  Widget buildListTaskCard(Map<String, dynamic> task) {
    return _HoverRowShell(
      builder: (hovered) => _buildListRowBody(task, hovered: hovered),
    );
  }

  /// Зона выполнения вместо круга-чекбокса — общая для списка и досок, чтобы
  /// жест «закрыть задачу» был одинаковым во всех разделах.
  Widget _completionZone(
    Map<String, dynamic> task, {
    required bool isDone,
    required bool hovered,
    required double size,
  }) {
    return SizedBox(
      width: size * 2,
      child: Center(
        child: ClarifyPressable(
          onTap: () => onToggle(task),
          child: AnimatedOpacity(
            duration: ClarifyMotion.base,
            curve: ClarifyMotion.standard,
            opacity: isDone || hovered ? 1 : 0,
            child: Icon(
              LucideIcons.check,
              size: size,
              color: isDone ? _t.success : _t.text2,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildListRowBody(Map<String, dynamic> task, {required bool hovered}) {
    final double rs = _rowScale;
    final bool isDone = task['is_completed'] == true;
    final cStats = checklistStats(task['checklist']);
    final bool hasChecklist = cStats['total']! > 0;
    bool hasPriority = task['priority'] != null && task['priority'] != 'none';
    bool hasRecurrence =
        task['recurrence'] != null && task['recurrence'] != 'none';
    final stats = getSubtaskStats(task['id']);
    final bool hasSubtasks = stats['total']! > 0;
    final String? tag = (task['tags'] as String?)?.split(',').first.trim();

    final bool overdue = isOverdue(task);
    // Полоса приоритета слева — тот же визуальный язык, что и на мобильной
    // версии (mobile_task_row.dart). С 2026-09-04 рисуется границей самой
    // строки, а не отдельным Positioned поверх карточки: карточки больше нет.
    // Флаг+подпись приоритета убраны из строки метаданных — приоритет теперь
    // читается только через цвет (обводка чекбокса + полоса слева), отдельный
    // текстовый бейдж стал избыточным (живой фидбек 2026-08-02, тот же раунд,
    // где согласована трёхстрочная структура ниже).
    final rotBadge = _rotBadge(task, isDone, overdue);
    final rescheduleBadge = _rescheduleBadge(task, isDone);
    // "Был бы бейдж, если бы задача не была выполнена" — НЕ то же самое, что
    // rotBadge/rescheduleBadge выше (те специально null, когда isDone, это и
    // управляет исчезающей анимацией). Нужно отдельно, чтобы решить, монтировать
    // ли саму 3-ю строку: если гасить обёртку по текущему (уже null) значению,
    // clarifyAnimatedBadgeSlot размонтируется вместе с ней в тот же кадр, что
    // и isDone, и анимации исчезновения не будет — тот же приём, что и у
    // _wasPastDue для иконки просрочки.
    final bool line3EverRelevant =
        _rotBadge(task, false, overdue) != null ||
        _rescheduleBadge(task, false) != null;

    return ClarifyCollapsingTaskRow(
      key: ValueKey(task['id']),
      child: AnimatedContainer(
        duration: ClarifyMotion.base,
        curve: ClarifyMotion.standard,
        constraints: BoxConstraints(minHeight: 44 * rs),
        decoration: BoxDecoration(
          // Заливка только у того, что требует внимания, и лёгкая подсветка под
          // курсором. У обычной задачи фона нет вовсе: именно одинаковая
          // подложка у всех строк и превращала список в стопку одинаковых
          // плиток.
          color: !isDone && overdue
              ? _t.dangerSoft
              : (hovered ? _t.accentSoft : Colors.transparent),
          border: Border(
            bottom: BorderSide(color: _t.border),
            // Приоритет — по левой кромке всей строки, без отдельного
            // Positioned поверх карточки: карточки больше нет.
            left: BorderSide(
              color: isDone || !hasPriority
                  ? Colors.transparent
                  : getPriorityColor(task['priority']),
              width: overdue && !isDone ? 3 : 2,
            ),
          ),
        ),
        padding: EdgeInsets.fromLTRB(0, 7 * rs, 8 * rs, 7 * rs),
        child: GestureDetector(
          onTap: () => onTap(task),
          behavior: HitTestBehavior.opaque,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Зона выполнения вместо круга: в покое пустая, галочка
                      // проявляется под курсором. У выполненной задачи видна
                      // всегда — иначе состояние читалось бы только по
                      // зачёркиванию, а в смешанном списке этого мало.
                      _completionZone(
                        task,
                        isDone: isDone,
                        hovered: hovered,
                        size: 16 * rs,
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Строка 1: чекбокс (слева от Column) + заголовок +
                            // значок повтора. Счётчики подзадач/чек-листа
                            // переехали на строку 2 (см. ниже) — по
                            // согласованной структуре 2026-08-02.
                            Row(
                              children: [
                                Expanded(
                                  child: ClarifyStrikeText(
                                    text: task['title'] ?? '',
                                    isDone: isDone,
                                    // 18 → 15: в плотной строке заголовок в
                                    // 18px перебивал собой всё остальное и
                                    // задавал высоту, из-за которой на экран
                                    // влезало 6 задач вместо 12.
                                    style: TextStyle(
                                      fontSize: 15 * rs,
                                      height: 1.25,
                                      color: isDone ? textMuted : textColor,
                                      fontWeight: overdue && !isDone
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (hasRecurrence)
                                  Padding(
                                    padding: EdgeInsets.only(left: 8 * rs),
                                    child: Icon(
                                      LucideIcons.repeat,
                                      size: 15 * rs,
                                      color: isDone ? textMuted : _t.text3,
                                    ),
                                  ),
                                // Дата, счётчики и тег — в ОДНОЙ строке с
                                // заголовком, а не под ним. Вторая строка
                                // удваивала высоту у каждой задачи, у которой
                                // есть дата, то есть почти у всех: строка
                                // занимала 62px вместо 44 и список выглядел
                                // стопкой крупных блоков.
                                //
                                // Каждая иконка с текстом по-прежнему
                                // сгруппирована в свой Row (не голые элементы
                                // плоского Row) — иначе crossAxisAlignment
                                // центрирует их по высоте самого высокого
                                // соседа, а не друг относительно друга (живой
                                // фидбек 2026-08-01: «значок просрочки на
                                // другой высоте относительно даты»).
                                if (task['due_date'] != null ||
                                    task['due_time'] != null ||
                                    hasSubtasks ||
                                    hasChecklist ||
                                    (tag != null && tag.isNotEmpty))
                                  Padding(
                                    padding: EdgeInsets.only(left: 12 * rs),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      children: [
                                    if (task['due_date'] != null ||
                                        task['due_time'] != null)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          right: 12,
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.center,
                                          children: [
                                            if (_wasPastDue(task))
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                  right: 4,
                                                ),
                                                child: SizedBox(
                                                  width: 16,
                                                  height: 16,
                                                  child: AnimatedOpacity(
                                                    opacity: isDone ? 0 : 1,
                                                    duration: ClarifyMotion
                                                        .completion,
                                                    curve:
                                                        ClarifyMotion.standard,
                                                    child: Icon(
                                                      LucideIcons.clockAlert,
                                                      size: 16,
                                                      color: _t.danger,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            AnimatedDefaultTextStyle(
                                              duration:
                                                  ClarifyMotion.completion,
                                              curve: ClarifyMotion.standard,
                                              style: TextStyle(
                                                // 14 → 12.5: дата и время —
                                                // сопровождение заголовка, а не
                                                // равный ему по весу элемент.
                                                fontSize: 12.5 * rs,
                                                color: overdue
                                                    ? _t.danger
                                                    : textMuted,
                                                fontWeight: overdue
                                                    ? FontWeight.w700
                                                    : FontWeight.w500,
                                              ),
                                              child: Text(
                                                "${task['due_date'] != null ? '${task['due_date']} ' : ''}${task['due_time'] ?? ''}",
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    // Схлопывается, когда сама задача выполнена —
                                    // счётчик не нужен после закрытия всей задачи.
                                    if (hasSubtasks)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          right: 12,
                                        ),
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
                                        padding: const EdgeInsets.only(
                                          right: 12,
                                        ),
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
                                    if (tag != null && tag.isNotEmpty)
                                      GestureDetector(
                                        onTap: () => onTagTap(tag),
                                        // Было "[$tag]" жирным акцентным цветом.
                                        // После перехода на контрастный акцент
                                        // (2026-09-04) метка стала ярче самого
                                        // заголовка задачи — решётка, обычный
                                        // вес, приглушённый цвет.
                                        child: Text(
                                          "#$tag",
                                          style: TextStyle(
                                            fontSize: 12.5 * rs,
                                            fontWeight: FontWeight.w500,
                                            color: _t.text3,
                                          ),
                                        ),
                                      ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                            // Вторая строка — только сигналы состояния (гниение
                            // и переносы). Они редки, поэтому строка задачи
                            // остаётся однострочной у подавляющего большинства
                            // задач, а вырастает ровно там, где есть что
                            // сказать.
                            if (line3EverRelevant)
                              Padding(
                                padding: EdgeInsets.only(top: 4 * rs),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.only(right: 12),
                                      child: clarifyAnimatedBadgeSlot(rotBadge),
                                    ),
                                    clarifyAnimatedBadgeSlot(rescheduleBadge),
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
                            var members =
                                workspaceMembers[task['workspace_id']] ?? [];
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
                      // Крестик удаления — только под курсором. Постоянно
                      // висящий крестик и добавлял шума в каждую строку, и
                      // провоцировал случайные удаления (задача удаляется
                      // безвозвратно, корзины нет).
                      // IgnorePointer, а не отключение кнопки: невидимая, но
                      // кликабельная зона — это удаление вслепую по случайному
                      // попаданию мышью.
                      IgnorePointer(
                        ignoring: !hovered,
                        child: AnimatedOpacity(
                          duration: ClarifyMotion.base,
                          curve: ClarifyMotion.standard,
                          opacity: hovered ? 1 : 0,
                          child: Builder(
                            builder: (btnContext) => IconButton(
                              icon: Icon(LucideIcons.x, color: _t.text3, size: 17),
                              hoverColor: _t.dangerSoft,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 26,
                                minHeight: 26,
                              ),
                              onPressed: () =>
                                  ClarifyCollapsingTaskRow.collapseThenRun(
                                    btnContext,
                                    () => onDelete(task['id']),
                                  ),
                            ),
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

/// Обёртка строки задачи: держит состояние наведения. Нужна отдельным
/// виджетом, потому что [TaskCardBuilders] — обычный объект с колбэками, а не
/// виджет, и своего состояния иметь не может. Одна на все виды строк (список,
/// доска «7 дней», доска проекта) — чтобы наведение везде вело себя одинаково.
class _HoverRowShell extends StatefulWidget {
  final Widget Function(bool hovered) builder;

  const _HoverRowShell({required this.builder});

  @override
  State<_HoverRowShell> createState() => _HoverRowShellState();
}

class _HoverRowShellState extends State<_HoverRowShell> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: widget.builder(_hovered),
    );
  }
}
