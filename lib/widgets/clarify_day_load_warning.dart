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

/// Полоса ёмкости дня над списком «Мой день».
///
/// Конкуренты (Todoist, TickTick, Things) показывают, СКОЛЬКО задач на день, но
/// не сколько от дня осталось. У нас длительности уже лежат в базе и до сих пор
/// использовались только для предупреждения в диалоге — то есть постфактум и в
/// одном месте. Здесь тот же сигнал становится ответом на главный вопрос
/// планирования: сколько ещё влезет.
///
/// Пустой хвост полосы справа — это и есть свободное время. Заполненная полоса
/// меняет цвет: спокойный, когда день не забит, охра около предела, красный при
/// перегрузе.
class ClarifyDayCapacity extends StatelessWidget {
  final int plannedMinutes;
  final int capacityMinutes;
  final int taskCount;
  final String currentLang;

  const ClarifyDayCapacity({
    super.key,
    required this.plannedMinutes,
    required this.capacityMinutes,
    required this.taskCount,
    required this.currentLang,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final ratio = capacityMinutes == 0 ? 0.0 : plannedMinutes / capacityMinutes;
    final overloaded = ratio > 1.0;
    final tight = ratio > 0.8;
    final barColor = overloaded ? t.danger : (tight ? t.warning : t.text2);

    // Задачи без длительности в сумму не попадают (нечего складывать), поэтому
    // при нулевой сумме полосу не показываем вовсе: пустая шкала над списком из
    // десяти задач врала бы сильнее, чем её отсутствие.
    if (plannedMinutes == 0) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '$taskCount ${_plural(taskCount, 'задача', 'задачи', 'задач')}',
                style: TextStyle(color: t.text2, fontSize: 12.5, fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              Text(
                '${formatDurationMinutes(plannedMinutes, currentLang)} ${'из'.tr(currentLang)} ${formatDurationMinutes(capacityMinutes, currentLang)}',
                style: TextStyle(
                  color: overloaded ? t.danger : t.text2,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, constraints) {
              return Stack(
                children: [
                  Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: t.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  AnimatedContainer(
                    duration: ClarifyMotion.slow,
                    curve: ClarifyMotion.standard,
                    height: 4,
                    width: constraints.maxWidth * (ratio > 1 ? 1 : ratio),
                    decoration: BoxDecoration(
                      color: barColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ],
              );
            },
          ),
          if (tight) ...[
            const SizedBox(height: 7),
            Text(
              (overloaded
                      ? 'День перегружен — что-то стоит перенести'
                      : 'День почти забит')
                  .tr(currentLang),
              style: TextStyle(color: barColor, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ],
        ],
      ),
    );
  }

  String _plural(int n, String one, String few, String many) {
    final mod100 = n % 100;
    if (mod100 >= 11 && mod100 <= 14) return many;
    switch (n % 10) {
      case 1:
        return one;
      case 2:
      case 3:
      case 4:
        return few;
      default:
        return many;
    }
  }
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
