import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/checklist.dart';
import '../../../core/clarify_date_format.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../widgets/clarify_quick_actions_sheet.dart';
import '../../../widgets/clarify_task_checkbox.dart';

/// Внимание: mobile_task_row.dart и task_cards.dart — два отдельных виджета
/// для одного и того же визуального смысла (десктоп/мобильный ряд задачи),
/// не связаны наследованием. Любой новый бейдж на карточке задачи нужно
/// добавлять в ОБА места — реализация вынесена в общие buildRotBadge/
/// buildRescheduleBadge (clarify_task_checkbox.dart) именно чтобы не
/// дублировать саму логику, но сам факт вызова в каждом виджете дублировать
/// придётся (см. историю бага: бейджи появились только на десктопе, потому
/// что при добавлении забыли про этот файл).

// `overdue`, переданный этому виджету, уже вычислен через isOverdue(task)
// колбэком экрана, который сам возвращает false для выполненных задач (см.
// desktop_planner_screen.dart._isOverdue). Из-за этого `overdue` и `isDone`
// становятся false/true ОДНОВРЕМЕННО в один и тот же ребилд — резервировать
// место под иконку по условию `if (overdue)` не работает, значение уже
// схлопнулось к false к моменту, когда задача отмечена выполненной. Эта
// функция — та же проверка "дедлайн уже прошёл", но БЕЗ раннего return по
// is_completed, специально для резервирования места под иконку.
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

/// Строка задачи, общая для "Сегодня", "Задачи" и "Команды" на мобильной
/// версии — левая полоса цвета приоритета вместо отдельного кружка-чекбокса
/// с цветной обводкой, как на десктопе (там мышь, здесь палец — крупнее
/// область тапа, меньше мелких деталей).
class MobileTaskRow extends StatelessWidget {
  final Map<String, dynamic> task;
  final Color priorityColor;
  final Map<String, int> subtaskStats;
  final bool overdue;
  final String currentLang;
  final VoidCallback onToggle;
  final VoidCallback onDelete;
  final VoidCallback onTap;
  final void Function(Map<String, dynamic> updates) onQuickUpdateTask;
  final bool showDate;

  const MobileTaskRow({
    super.key,
    required this.task,
    required this.priorityColor,
    required this.subtaskStats,
    required this.overdue,
    required this.currentLang,
    required this.onToggle,
    required this.onDelete,
    required this.onTap,
    required this.onQuickUpdateTask,
    this.showDate = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final bool isDone = task['is_completed'] == true;
    final bool hasSubtasks = subtaskStats['total']! > 0;
    final cStats = checklistStats(task['checklist']);
    final bool hasChecklist = cStats['total']! > 0;
    final String? tag = (task['tags'] as String?)?.split(',').first.trim();
    final rotBadge = buildRotBadge(task: task, isDone: isDone, overdue: overdue, tokens: t, currentLang: currentLang);
    final rescheduleBadge = buildRescheduleBadge(task: task, isDone: isDone, tokens: t, currentLang: currentLang);
    // Тап по бейджу гниения открывает быстрые действия вместо простого
    // просмотра — см. showTaskRotQuickActions (пассивный бейдж рискует со
    // временем превратиться в фоновый шум, который перестают замечать).
    final rotBadgeInteractive = rotBadge == null
        ? null
        : Builder(
            builder: (context) => GestureDetector(
              onTap: () => showTaskRotQuickActions(
                context: context,
                isDark: Theme.of(context).brightness == Brightness.dark,
                currentLang: currentLang,
                onDoToday: () => onQuickUpdateTask({'due_date': formatClarifyDate(DateTime.now())}),
                onClearDeadline: () => onQuickUpdateTask({'due_date': null, 'due_time': null, 'duration_minutes': null}),
                onDelete: onDelete,
              ),
              child: rotBadge,
            ),
          );

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: isDone ? t.surfaceSunken : (overdue ? t.dangerSoft : t.surface),
        animationDuration: ClarifyMotion.base,
        borderRadius: BorderRadius.circular(ClarifyRadius.md),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(ClarifyRadius.md),
          child: AnimatedContainer(
            duration: ClarifyMotion.base,
            curve: ClarifyMotion.standard,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(ClarifyRadius.md),
              // Полоса — канал приоритета ТОЛЬКО (§6.4 REDESIGN_V4_PLAN.md);
              // просрочка теперь читается через фон строки + иконку часов
              // у времени ниже, не через эту же полосу.
              border: Border(left: BorderSide(color: isDone ? t.border : priorityColor, width: 3)),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2, right: 10),
                    // ClarifyCheckCircle/ClarifyStrikeText — те же анимированные
                    // примитивы, что и на десктопе (TaskCardBuilders); здесь
                    // раньше стояла голая статичная Icon() без единой анимации,
                    // отметка/снятие выполнения выглядели как мгновенный "скачок"
                    // на всех фронтах сразу (иконка/зачёркивание/цвет).
                    child: ClarifyCheckCircle(
                      size: 22,
                      value: isDone,
                      onTap: onToggle,
                      borderColor: overdue ? t.danger : t.text3,
                      checkedColor: t.success,
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClarifyStrikeText(
                          text: task['title'] ?? '',
                          isDone: isDone,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: isDone ? t.text3 : t.text,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (showDate && task['due_date'] != null || task['due_time'] != null || hasSubtasks || hasChecklist || tag != null) ...[
                          const SizedBox(height: 4),
                          // Строка 1: дата/время/тег/счётчик подзадач — как и
                          // раньше. Бейджи гниения/переноса сюда НЕ попадают
                          // даже если есть место (см. вторая строка ниже) —
                          // по прямому запросу они должны быть строго отдельно
                          // от даты/времени/тега, не тесниться с ними в Wrap.
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              if (showDate && task['due_date'] != null)
                                Text(task['due_date'], style: TextStyle(fontSize: 12, color: overdue && !isDone ? t.danger : t.text3, fontWeight: FontWeight.w600)),
                              if (task['due_time'] != null)
                                Text(task['due_time'], style: TextStyle(fontSize: 12, color: overdue && !isDone ? t.danger : t.text3, fontWeight: FontWeight.w600)),
                              // Бейдж подзадач/чек-листа схлопывается, когда сама
                              // задача выполнена — счётчик "N из N" не несёт
                              // смысла после того, как вся задача уже закрыта.
                              // AnimatedSize вместо мгновенного исчезновения —
                              // по аналогии с остальными анимациями отметки.
                              if (hasSubtasks)
                                AnimatedSize(
                                  duration: ClarifyMotion.base,
                                  curve: ClarifyMotion.standard,
                                  child: isDone
                                      ? const SizedBox.shrink()
                                      : ClarifySubtaskBadge(done: subtaskStats['done']!, total: subtaskStats['total']!, tokens: t),
                                ),
                              if (hasChecklist)
                                AnimatedSize(
                                  duration: ClarifyMotion.base,
                                  curve: ClarifyMotion.standard,
                                  child: isDone
                                      ? const SizedBox.shrink()
                                      : ClarifySubtaskBadge(done: cStats['done']!, total: cStats['total']!, tokens: t, icon: LucideIcons.listTodo),
                                ),
                              if (tag != null && tag.isNotEmpty)
                                Text('#$tag', style: TextStyle(fontSize: 12, color: t.accent, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ],
                        if (_wasPastDue(task) || rotBadge != null || rescheduleBadge != null) ...[
                          const SizedBox(height: 4),
                          // Строка 2, всегда отдельно от строки 1: иконка
                          // просрочки + бейджи гниения/переноса.
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              // Слот иконки просрочки закреплён по ширине, если
                              // дедлайн задачи вообще был в прошлом (см.
                              // _wasPastDue) — НЕ по `overdue`, который сам уже
                              // false для выполненных задач: иначе слот и не
                              // появился бы в тот же ребилд, где isDone стал true,
                              // и дата всё равно "прыгала" бы влево.
                              if (_wasPastDue(task))
                                SizedBox(
                                  width: 12,
                                  height: 12,
                                  child: AnimatedOpacity(
                                    opacity: isDone ? 0 : 1,
                                    duration: ClarifyMotion.base,
                                    curve: ClarifyMotion.standard,
                                    child: Icon(LucideIcons.clockAlert, size: 12, color: t.danger),
                                  ),
                                ),
                              ?rotBadgeInteractive,
                              ?rescheduleBadge,
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(LucideIcons.x, size: 16, color: t.text3),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    onPressed: onDelete,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
