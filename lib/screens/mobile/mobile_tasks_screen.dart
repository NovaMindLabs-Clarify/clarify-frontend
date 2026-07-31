import 'package:flutter/material.dart';
import '../../core/localization.dart';
import '../../core/theme/design_tokens.dart';
import '../../widgets/clarify_cascade_item.dart';
import '../../widgets/clarify_illustrations.dart';
import 'widgets/mobile_mini_calendar.dart';
import 'widgets/swipe_to_delete_task_row.dart';

enum _TaskFilter { today, upcoming, inbox, all }

/// "Задачи" — единый фильтруемый список вместо четырёх отдельных пунктов
/// десктопного сайдбара (Мой день/Следующие 7 дней/Все задачи/Входящие).
/// На маленьком экране это один экран с переключателем сверху, а не четыре
/// таба, которые некуда физически поместить в нижней навигации.
class MobileTasksScreen extends StatefulWidget {
  final String currentLang;
  final List<Map<String, dynamic>> tasks;
  final Color Function(String? priority) getPriorityColor;
  final Map<String, int> Function(dynamic parentId) getSubtaskStats;
  final bool Function(Map<String, dynamic> task) isOverdue;
  final void Function(Map<String, dynamic> task) onToggle;
  final void Function(dynamic taskId) onDelete;
  final void Function(Map<String, dynamic> task) onTap;
  final void Function(dynamic taskId, Map<String, dynamic> updates)
  onQuickUpdateTask;
  final DateTime? initialDate;
  final Set<String> datesWithTasks;
  final Map<String, int> dateLoadMinutes;

  const MobileTasksScreen({
    super.key,
    required this.currentLang,
    required this.tasks,
    required this.getPriorityColor,
    required this.getSubtaskStats,
    required this.isOverdue,
    required this.onToggle,
    required this.onDelete,
    required this.onTap,
    required this.onQuickUpdateTask,
    required this.datesWithTasks,
    required this.dateLoadMinutes,
    this.initialDate,
  });

  @override
  State<MobileTasksScreen> createState() => _MobileTasksScreenState();
}

class _MobileTasksScreenState extends State<MobileTasksScreen> {
  _TaskFilter _filter = _TaskFilter.today;
  late DateTime? _calendarDate = widget.initialDate;

  String _formatDate(DateTime d) => '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

  String get _emptyStateKey {
    if (_calendarDate != null) return 'На эту дату ничего не запланировано';
    switch (_filter) {
      case _TaskFilter.today:
        return 'На сегодня ничего не запланировано';
      case _TaskFilter.upcoming:
        return 'На ближайшие 7 дней ничего не запланировано';
      case _TaskFilter.inbox:
        return 'Во входящих пока пусто';
      case _TaskFilter.all:
        return 'Задач пока нет';
    }
  }

  ClarifyIllustrationType get _emptyIllustration {
    if (_calendarDate != null) return ClarifyIllustrationType.checklistFold;
    switch (_filter) {
      case _TaskFilter.today:
        return ClarifyIllustrationType.sunHorizon;
      case _TaskFilter.upcoming:
        return ClarifyIllustrationType.checklistFold;
      case _TaskFilter.inbox:
        return ClarifyIllustrationType.inboxEmpty;
      case _TaskFilter.all:
        return ClarifyIllustrationType.checklistFold;
    }
  }

  List<Map<String, dynamic>> get _filtered {
    final base = widget.tasks.where((t) => t['parent_id'] == null).toList();
    if (_calendarDate != null) {
      final dateStr = _formatDate(_calendarDate!);
      return base.where((t) => t['due_date'] == dateStr).toList();
    }
    switch (_filter) {
      case _TaskFilter.today:
        final todayStr = _formatDate(DateTime.now());
        return base.where((t) => t['due_date'] == todayStr).toList();
      case _TaskFilter.upcoming:
        final now = DateTime.now();
        final dates = {for (var i = 0; i < 7; i++) _formatDate(now.add(Duration(days: i)))};
        return base.where((t) => t['due_date'] != null && dates.contains(t['due_date'])).toList();
      case _TaskFilter.inbox:
        return base.where((t) => t['due_date'] == null || t['due_date'] == '').toList();
      case _TaskFilter.all:
        return base;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final tasks = _filtered..sort((a, b) => (a['due_time'] ?? '23:59').compareTo(b['due_time'] ?? '23:59'));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Задачи'.tr(widget.currentLang), style: TextStyle(fontFamily: 'Golos Text', fontSize: 22, fontWeight: FontWeight.w700, color: t.text)),
              const SizedBox(height: 2),
              // Невидимый плейсхолдер той же высоты, что подпись даты на "Мой
              // день" (MobileTodayScreen) — без него календарная плашка и
              // пустое состояние оказываются на разной высоте между вкладками.
              Opacity(opacity: 0, child: Text('.', style: TextStyle(fontSize: 13, color: t.text3))),
            ],
          ),
        ),
        MobileMiniCalendar(
          currentLang: widget.currentLang,
          selectedDate: _calendarDate ?? DateTime.now(),
          datesWithTasks: widget.datesWithTasks,
          dateLoadMinutes: widget.dateLoadMinutes,
          onDaySelected: (day) => setState(() => _calendarDate = day),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _FilterChip(label: 'Сегодня'.tr(widget.currentLang), active: _calendarDate == null && _filter == _TaskFilter.today, onTap: () => setState(() { _calendarDate = null; _filter = _TaskFilter.today; })),
                const SizedBox(width: 8),
                _FilterChip(label: '7 дней'.tr(widget.currentLang), active: _calendarDate == null && _filter == _TaskFilter.upcoming, onTap: () => setState(() { _calendarDate = null; _filter = _TaskFilter.upcoming; })),
                const SizedBox(width: 8),
                _FilterChip(label: 'Входящие'.tr(widget.currentLang), active: _calendarDate == null && _filter == _TaskFilter.inbox, onTap: () => setState(() { _calendarDate = null; _filter = _TaskFilter.inbox; })),
                const SizedBox(width: 8),
                _FilterChip(label: 'Все'.tr(widget.currentLang), active: _calendarDate == null && _filter == _TaskFilter.all, onTap: () => setState(() { _calendarDate = null; _filter = _TaskFilter.all; })),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: tasks.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ClarifyIllustration(type: _emptyIllustration, size: 72),
                        const SizedBox(height: 16),
                        Text(_emptyStateKey.tr(widget.currentLang), textAlign: TextAlign.center, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: t.text2)),
                        const SizedBox(height: 6),
                        Text('Нажмите «+», чтобы добавить задачу'.tr(widget.currentLang), textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: t.text3)),
                      ],
                    ),
                  ),
                )
              // Долгое нажатие прямо на строке задачи запускает переупорядочивание —
              // без отдельной ручки-хвата: она вносила визуальный шум и не
              // схлопывалась вместе со строкой при удалении/отмене (оставалась
              // висеть "осиротевшей" точкой, пока SwipeToDeleteTaskRow был уже
              // схлопнут). ReorderableDelayedDragStartListener ждёт задержку перед
              // стартом драга, поэтому не конфликтует с мгновенным горизонтальным
              // свайпом-удалением внутри SwipeToDeleteTaskRow — жесты различаются
              // по направлению и по задержке распознавания.
              : ReorderableListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                  itemCount: tasks.length,
                  onReorder: (oldIndex, newIndex) {
                    setState(() {
                      if (newIndex > oldIndex) newIndex -= 1;
                      final item = tasks.removeAt(oldIndex);
                      tasks.insert(newIndex, item);
                    });
                  },
                  itemBuilder: (context, index) {
                    final task = tasks[index];
                    return ClarifyCascadeItem(
                      key: ValueKey('cascade_${task['id']}'),
                      index: index,
                      child: ReorderableDelayedDragStartListener(
                        key: ValueKey(task['id'].toString()),
                        index: index,
                        child: SwipeToDeleteTaskRow(
                          task: task,
                          currentLang: widget.currentLang,
                          showDate: _filter != _TaskFilter.today,
                          priorityColor: widget.getPriorityColor(task['priority']),
                          subtaskStats: widget.getSubtaskStats(task['id']),
                          overdue: widget.isOverdue(task),
                          onToggle: () => widget.onToggle(task),
                          onConfirmedDelete: () => widget.onDelete(task['id']),
                          onTap: () => widget.onTap(task),
                          onQuickUpdateTask: (updates) => widget.onQuickUpdateTask(task['id'], updates),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _FilterChip({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ClarifyRadius.pill),
      child: Container(
        // vertical:10, а не 8 — та же высота плашки, что у "Входящие" на
        // "Мой день" (MobileTodayScreen), иначе календарь и пустое состояние
        // между вкладками "прыгают" по высоте.
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: active ? t.accent : t.surface2,
          borderRadius: BorderRadius.circular(ClarifyRadius.pill),
          border: Border.all(color: active ? t.accent : t.border),
        ),
        child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: active ? t.onAccent : t.text2)),
      ),
    );
  }
}
