import 'package:flutter/material.dart';
import '../../core/localization.dart';
import '../../core/theme/design_tokens.dart';
import 'widgets/mobile_task_row.dart';

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
  });

  @override
  State<MobileTasksScreen> createState() => _MobileTasksScreenState();
}

class _MobileTasksScreenState extends State<MobileTasksScreen> {
  _TaskFilter _filter = _TaskFilter.today;

  String _formatDate(DateTime d) => '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

  List<Map<String, dynamic>> get _filtered {
    final base = widget.tasks.where((t) => t['parent_id'] == null).toList();
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
          child: Text('Задачи'.tr(widget.currentLang), style: TextStyle(fontFamily: 'Golos Text', fontSize: 22, fontWeight: FontWeight.w700, color: t.text)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _FilterChip(label: 'Сегодня'.tr(widget.currentLang), active: _filter == _TaskFilter.today, onTap: () => setState(() => _filter = _TaskFilter.today)),
                const SizedBox(width: 8),
                _FilterChip(label: '7 дней'.tr(widget.currentLang), active: _filter == _TaskFilter.upcoming, onTap: () => setState(() => _filter = _TaskFilter.upcoming)),
                const SizedBox(width: 8),
                _FilterChip(label: 'Входящие'.tr(widget.currentLang), active: _filter == _TaskFilter.inbox, onTap: () => setState(() => _filter = _TaskFilter.inbox)),
                const SizedBox(width: 8),
                _FilterChip(label: 'Все'.tr(widget.currentLang), active: _filter == _TaskFilter.all, onTap: () => setState(() => _filter = _TaskFilter.all)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: tasks.isEmpty
              ? Center(
                  child: Text('Пусто. Отдыхаем!'.tr(widget.currentLang), style: TextStyle(fontSize: 15, color: t.text3)),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                  itemCount: tasks.length,
                  itemBuilder: (context, index) {
                    final task = tasks[index];
                    return MobileTaskRow(
                      task: task,
                      showDate: _filter != _TaskFilter.today,
                      priorityColor: widget.getPriorityColor(task['priority']),
                      subtaskStats: widget.getSubtaskStats(task['id']),
                      overdue: widget.isOverdue(task),
                      onToggle: () => widget.onToggle(task),
                      onDelete: () => widget.onDelete(task['id']),
                      onTap: () => widget.onTap(task),
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
