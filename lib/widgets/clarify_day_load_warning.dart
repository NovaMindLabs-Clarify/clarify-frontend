import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../core/localization.dart';
import '../core/theme/design_tokens.dart';
import 'clarify_duration_chips.dart';
import 'clarify_task_checkbox.dart';

/// Суммарная известная длительность задач на день. Задачи без
/// duration_minutes не учитываются в сумме (нечего складывать), но всё равно
/// занимают день — предупреждение по этой сумме всегда нижняя оценка
/// реальной загрузки, не точная цифра.
int dayLoadMinutes(
  List<Map<String, dynamic>> tasks,
  String dateStr, {
  int? excludeTaskId,
}) {
  return tasks
      .where(
        (t) =>
            t['due_date'] == dateStr &&
            t['parent_id'] == null &&
            t['is_completed'] != true &&
            t['id'] != excludeTaskId,
      )
      .fold<int>(0, (sum, t) => sum + ((t['duration_minutes'] as int?) ?? 0));
}

/// Предупреждение о загрузке дня — показывается прямо в диалоге создания/
/// редактирования задачи, в момент выбора даты (а не постфактум, как уже
/// существующий _checkBurnoutWarning в desktop_planner_screen.dart, который
/// считает КОЛИЧЕСТВО задач и всплывает уже после сохранения). Здесь — по
/// сумме duration_minutes, до сохранения, пока пользователь ещё выбирает
/// дату/время.
class ClarifyDayLoadWarning extends StatelessWidget {
  final int totalMinutes;
  final String currentLang;

  const ClarifyDayLoadWarning({
    super.key,
    required this.totalMinutes,
    required this.currentLang,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return ClarifyBadgeEntrance(
      child: Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: t.warningSoft,
          borderRadius: BorderRadius.circular(ClarifyRadius.sm),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(LucideIcons.triangleAlert, size: 16, color: t.warning),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${"На этот день уже занято".tr(currentLang)} ${formatDurationMinutes(totalMinutes, currentLang)}',
                style: TextStyle(color: t.warning, fontSize: 12.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
