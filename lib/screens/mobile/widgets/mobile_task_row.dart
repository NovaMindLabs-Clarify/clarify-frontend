import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/checklist.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../widgets/clarify_task_checkbox.dart';

/// Внимание: mobile_task_row.dart и task_cards.dart — два отдельных виджета
/// для одного и того же визуального смысла (десктоп/мобильный ряд задачи),
/// не связаны наследованием. Любой новый бейдж на карточке задачи нужно
/// добавлять в ОБА места — реализация вынесена в общие buildRotBadge/
/// buildRescheduleBadge (clarify_task_checkbox.dart) именно чтобы не
/// дублировать саму логику, но сам факт вызова в каждом виджете дублировать
/// придётся (см. историю бага: бейджи появились только на десктопе, потому
/// что при добавлении забыли про этот файл).

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

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: isDone ? t.surfaceSunken : (overdue ? t.dangerSoft : t.surface),
        borderRadius: BorderRadius.circular(ClarifyRadius.md),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(ClarifyRadius.md),
          child: Container(
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
                  GestureDetector(
                    onTap: onToggle,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 2, right: 10),
                      child: Icon(
                        isDone ? LucideIcons.checkCircle : LucideIcons.circle,
                        size: 22,
                        color: isDone ? t.success : (overdue ? t.danger : t.text3),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          task['title'] ?? '',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            decoration: isDone ? TextDecoration.lineThrough : TextDecoration.none,
                            color: isDone ? t.text3 : t.text,
                          ),
                        ),
                        if (showDate && task['due_date'] != null || task['due_time'] != null || hasSubtasks || hasChecklist || tag != null || rotBadge != null || rescheduleBadge != null) ...[
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              if (overdue && !isDone)
                                Icon(LucideIcons.clockAlert, size: 12, color: t.danger),
                              if (showDate && task['due_date'] != null)
                                Text(task['due_date'], style: TextStyle(fontSize: 12, color: overdue && !isDone ? t.danger : t.text3, fontWeight: FontWeight.w600)),
                              if (task['due_time'] != null)
                                Text(task['due_time'], style: TextStyle(fontSize: 12, color: overdue && !isDone ? t.danger : t.text3, fontWeight: FontWeight.w600)),
                              if (hasSubtasks)
                                ClarifySubtaskBadge(done: subtaskStats['done']!, total: subtaskStats['total']!, tokens: t),
                              if (hasChecklist)
                                ClarifySubtaskBadge(done: cStats['done']!, total: cStats['total']!, tokens: t, icon: LucideIcons.listTodo),
                              if (tag != null && tag.isNotEmpty)
                                Text('#$tag', style: TextStyle(fontSize: 12, color: t.accent, fontWeight: FontWeight.w600)),
                              ?rotBadge,
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
