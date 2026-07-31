import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../core/localization.dart';
import '../../core/theme/design_tokens.dart';
import '../../widgets/clarify_cascade_item.dart';
import '../../widgets/clarify_illustrations.dart';
import 'widgets/mobile_mini_calendar.dart';
import 'widgets/swipe_to_delete_task_row.dart';

/// "Сегодня" — мобильный таймлайн дня вместо десктопной сетки/досок.
/// Задачи группируются по часу (без времени — отдельной группой сверху),
/// а не позиционируются пиксель-в-пиксель, как в HTML-макете — так надёжнее
/// на реальном разнообразии контента (длинные заголовки, теги, подзадачи).
class MobileTodayScreen extends StatelessWidget {
  final String currentLang;
  final List<Map<String, dynamic>> todayTasks;
  final int inboxCount;
  final Set<String> datesWithTasks;
  final Color Function(String? priority) getPriorityColor;
  final Map<String, int> Function(dynamic parentId) getSubtaskStats;
  final bool Function(Map<String, dynamic> task) isOverdue;
  final void Function(Map<String, dynamic> task) onToggle;
  final void Function(dynamic taskId) onDelete;
  final void Function(Map<String, dynamic> task) onTap;
  final VoidCallback onOpenInbox;
  final void Function(DateTime date) onOpenDate;

  const MobileTodayScreen({
    super.key,
    required this.currentLang,
    required this.todayTasks,
    required this.inboxCount,
    required this.datesWithTasks,
    required this.getPriorityColor,
    required this.getSubtaskStats,
    required this.isOverdue,
    required this.onToggle,
    required this.onDelete,
    required this.onTap,
    required this.onOpenInbox,
    required this.onOpenDate,
  });

  static const _weekdaysRu = ['понедельник', 'вторник', 'среда', 'четверг', 'пятница', 'суббота', 'воскресенье'];
  static const _monthsRu = ['', 'января', 'февраля', 'марта', 'апреля', 'мая', 'июня', 'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря'];

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final now = DateTime.now();
    final dateLabel = '${_weekdaysRu[now.weekday - 1][0].toUpperCase()}${_weekdaysRu[now.weekday - 1].substring(1)}, ${now.day} ${_monthsRu[now.month]}';

    final withTime = todayTasks.where((task) => task['due_time'] != null).toList()
      ..sort((a, b) => (a['due_time'] as String).compareTo(b['due_time'] as String));
    final allDay = todayTasks.where((task) => task['due_time'] == null).toList();

    // Группируем задачи с временем по часу, чтобы не рисовать пиксель-точное
    // позиционирование — оно ломается на разнообразии реального контента.
    final Map<String, List<Map<String, dynamic>>> byHour = {};
    for (final task in withTime) {
      final hour = (task['due_time'] as String).split(':').first.padLeft(2, '0');
      byHour.putIfAbsent(hour, () => []).add(task);
    }
    final hours = byHour.keys.toList()..sort();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Мой день'.tr(currentLang), style: TextStyle(fontFamily: 'Unbounded', fontSize: 22, fontWeight: FontWeight.w700, color: t.text)),
              const SizedBox(height: 2),
              Text(dateLabel, style: TextStyle(fontSize: 13, color: t.text3)),
            ],
          ),
        ),

        MobileMiniCalendar(
          currentLang: currentLang,
          selectedDate: now,
          datesWithTasks: datesWithTasks,
          onDaySelected: (day) {
            if (!(day.year == now.year && day.month == now.month && day.day == now.day)) onOpenDate(day);
          },
        ),

        if (inboxCount > 0)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: InkWell(
              onTap: onOpenInbox,
              borderRadius: BorderRadius.circular(ClarifyRadius.md),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(color: t.surface2, borderRadius: BorderRadius.circular(ClarifyRadius.md), border: Border.all(color: t.border)),
                child: Row(
                  children: [
                    Icon(LucideIcons.inbox, size: 18, color: t.text2),
                    const SizedBox(width: 10),
                    Expanded(child: Text("${'Входящие: '.tr(currentLang)}$inboxCount${' без даты'.tr(currentLang)}", style: TextStyle(fontSize: 13, color: t.text2, fontWeight: FontWeight.w500))),
                    Icon(LucideIcons.chevronRight, size: 18, color: t.text3),
                  ],
                ),
              ),
            ),
          ),

        Expanded(
          child: todayTasks.isEmpty
              ? _EmptyToday(currentLang: currentLang)
              : Builder(builder: (context) {
                  var cascadeIdx = 0;
                  Widget cascadeRow(Map<String, dynamic> task) {
                    final index = cascadeIdx++;
                    return ClarifyCascadeItem(
                      key: ValueKey('cascade_${task['id']}'),
                      index: index,
                      child: SwipeToDeleteTaskRow(
                        task: task,
                        currentLang: currentLang,
                        priorityColor: getPriorityColor(task['priority']),
                        subtaskStats: getSubtaskStats(task['id']),
                        overdue: isOverdue(task),
                        onToggle: () => onToggle(task),
                        onConfirmedDelete: () => onDelete(task['id']),
                        onTap: () => onTap(task),
                      ),
                    );
                  }

                  return ListView(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                    children: [
                      if (allDay.isNotEmpty) ...[
                        _HourLabel(label: 'Весь день'.tr(currentLang)),
                        ...allDay.map(cascadeRow),
                        const SizedBox(height: 12),
                      ],
                      for (final hour in hours) ...[
                        _HourLabel(label: '$hour:00'),
                        ...byHour[hour]!.map(cascadeRow),
                      ],
                    ],
                  );
                }),
        ),
      ],
    );
  }
}

class _HourLabel extends StatelessWidget {
  final String label;
  const _HourLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 8),
      child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: t.text3, letterSpacing: 0.4)),
    );
  }
}

class _EmptyToday extends StatelessWidget {
  final String currentLang;
  const _EmptyToday({required this.currentLang});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ClarifyIllustration(type: ClarifyIllustrationType.sunHorizon, size: 72),
            const SizedBox(height: 16),
            Text('На сегодня ничего не запланировано'.tr(currentLang), textAlign: TextAlign.center, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: t.text2)),
            const SizedBox(height: 6),
            Text('Нажмите «+», чтобы добавить задачу'.tr(currentLang), textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: t.text3)),
          ],
        ),
      ),
    );
  }
}
