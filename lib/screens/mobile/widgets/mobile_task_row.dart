import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/theme/design_tokens.dart';

/// Строка задачи, общая для "Сегодня", "Задачи" и "Команды" на мобильной
/// версии — левая полоса цвета приоритета вместо отдельного кружка-чекбокса
/// с цветной обводкой, как на десктопе (там мышь, здесь палец — крупнее
/// область тапа, меньше мелких деталей).
class MobileTaskRow extends StatelessWidget {
  final Map<String, dynamic> task;
  final Color priorityColor;
  final Map<String, int> subtaskStats;
  final bool overdue;
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
    final String? tag = (task['tags'] as String?)?.split(',').first.trim();

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: isDone ? t.surfaceSunken : t.surface,
        borderRadius: BorderRadius.circular(ClarifyRadius.md),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(ClarifyRadius.md),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(ClarifyRadius.md),
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
                        if (showDate && task['due_date'] != null || task['due_time'] != null || hasSubtasks || tag != null) ...[
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              if (showDate && task['due_date'] != null)
                                Text(task['due_date'], style: TextStyle(fontSize: 12, color: overdue && !isDone ? t.danger : t.text3, fontWeight: FontWeight.w600)),
                              if (task['due_time'] != null)
                                Text(task['due_time'], style: TextStyle(fontSize: 12, color: overdue && !isDone ? t.danger : t.text3, fontWeight: FontWeight.w600)),
                              if (hasSubtasks)
                                Text('${subtaskStats['done']}/${subtaskStats['total']}', style: TextStyle(fontSize: 12, color: t.text3, fontWeight: FontWeight.w600)),
                              if (tag != null && tag.isNotEmpty)
                                Text('#$tag', style: TextStyle(fontSize: 12, color: t.accent, fontWeight: FontWeight.w600)),
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
