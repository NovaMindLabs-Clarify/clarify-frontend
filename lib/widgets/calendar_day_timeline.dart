import 'package:flutter/material.dart';
import '../core/localization.dart';
import '../core/theme/design_tokens.dart';

/// Таймлайн дня (REDESIGN_V4_PLAN.md §6.5) — основной вид "Календаря": часовая
/// сетка 00:00–23:00 с задачами, привязанными к их `due_time`, и линией
/// «сейчас» для сегодняшнего дня. Задачи с указанной `duration_minutes`
/// рисуются высотой, пропорциональной длительности (см.
/// docs/COMPETITOR_ANALYSIS_UPDATE_2026-07-31.md §3 — целевой референс
/// Structured строится на этом); задачи без длительности (поле nullable,
/// старые задачи и те, где пользователь её не указал) остаются как раньше —
/// фиксированной минимальной высоты.
class CalendarDayTimeline extends StatefulWidget {
  final DateTime date;
  final List<Map<String, dynamic>> tasks;
  final Widget Function(Map<String, dynamic>) buildCalendarTaskCard;
  final double scale;
  final ClarifyTokens t;
  final String currentLang;
  final void Function(Map<String, dynamic> task, String dateStr) onTaskDropped;

  const CalendarDayTimeline({
    super.key,
    required this.date,
    required this.tasks,
    required this.buildCalendarTaskCard,
    required this.scale,
    required this.t,
    required this.currentLang,
    required this.onTaskDropped,
  });

  @override
  State<CalendarDayTimeline> createState() => _CalendarDayTimelineState();
}

class _CalendarDayTimelineState extends State<CalendarDayTimeline> {
  static const double _hourHeight = 64;
  final ScrollController _scrollController = ScrollController();

  String _formatDate(DateTime date) =>
      "${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}";

  bool get _isToday => _formatDate(widget.date) == _formatDate(DateTime.now());

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      final targetHour = _isToday ? DateTime.now().hour : 8;
      final maxOffset = _scrollController.position.maxScrollExtent;
      final target = ((targetHour - 1).clamp(0, 24) * _hourHeight * widget.scale).clamp(0.0, maxOffset);
      _scrollController.jumpTo(target);
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.t;
    final s = widget.scale;
    final hourHeight = _hourHeight * s;

    final timedTasks = widget.tasks.where((task) => task['due_time'] != null).toList()
      ..sort((a, b) => (a['due_time'] as String).compareTo(b['due_time'] as String));
    final noTimeTasks = widget.tasks.where((task) => task['due_time'] == null).toList();

    final now = DateTime.now();
    final double nowOffset = (now.hour + now.minute / 60.0) * hourHeight;

    // Задачи с одинаковым временем — небольшой каскад со сдвигом вместо
    // полного наложения друг на друга.
    final Map<String, int> sameTimeIndex = {};

    return DragTarget<Map<String, dynamic>>(
      onAcceptWithDetails: (details) => widget.onTaskDropped(details.data, _formatDate(widget.date)),
      builder: (context, candidateData, rejectedData) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (noTimeTasks.isNotEmpty) ...[
              Padding(
                padding: EdgeInsets.fromLTRB(56 * s, 8 * s, 16 * s, 6 * s),
                child: Text(
                  "Без времени".tr(widget.currentLang),
                  style: TextStyle(fontSize: 12 * s, fontWeight: FontWeight.w600, color: t.text2),
                ),
              ),
              Padding(
                padding: EdgeInsets.only(left: 48 * s, right: 16 * s, bottom: 4 * s),
                child: Column(children: noTimeTasks.map(widget.buildCalendarTaskCard).toList()),
              ),
              Divider(height: 1, color: t.border),
            ],
            if (timedTasks.isEmpty && noTimeTasks.isEmpty)
              Expanded(
                child: Center(
                  child: Text(
                    "Свободно".tr(widget.currentLang),
                    style: TextStyle(fontSize: 14 * s, color: t.text2, fontWeight: FontWeight.w600),
                  ),
                ),
              )
            else
              Expanded(
                child: SingleChildScrollView(
                  controller: _scrollController,
                  child: SizedBox(
                    height: 24 * hourHeight,
                    child: Stack(
                      children: [
                        for (int h = 0; h < 24; h++)
                          Positioned(
                            top: h * hourHeight,
                            left: 0,
                            right: 0,
                            child: SizedBox(
                              height: hourHeight,
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(
                                    width: 48 * s,
                                    child: Padding(
                                      padding: EdgeInsets.only(top: 2 * s, right: 8 * s),
                                      child: Text(
                                        "${h.toString().padLeft(2, '0')}:00",
                                        textAlign: TextAlign.right,
                                        style: TextStyle(fontSize: 11 * s, color: t.text2, fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Container(
                                      decoration: BoxDecoration(border: Border(top: BorderSide(color: t.border, width: 1))),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        for (final task in timedTasks)
                          _buildTaskBlock(task, hourHeight, s, sameTimeIndex),
                        if (_isToday)
                          Positioned(
                            top: nowOffset - 4 * s,
                            left: 48 * s,
                            right: 16 * s,
                            child: Row(
                              children: [
                                Container(width: 8 * s, height: 8 * s, decoration: BoxDecoration(color: t.danger, shape: BoxShape.circle)),
                                Expanded(child: Container(height: 1.5 * s, color: t.danger)),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildTaskBlock(Map<String, dynamic> task, double hourHeight, double s, Map<String, int> sameTimeIndex) {
    final parts = (task['due_time'] as String).split(':');
    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
    final key = task['due_time'].toString();
    final idx = sameTimeIndex[key] ?? 0;
    sameTimeIndex[key] = idx + 1;
    final top = (hour + minute / 60.0) * hourHeight + idx * 10 * s;

    // Длительность рисуется как подложка позади карточки, а не через
    // растягивание самой карточки (buildCalendarTaskCard — общий билдер,
    // используемый и в списке/доске, где растягивание по высоте не имеет
    // смысла) — минимальная высота гарантирует, что 15-минутная задача
    // всё равно даёт видимую полоску, а не схлопывается в ничто.
    final durationMinutes = task['duration_minutes'] as int?;
    final double? blockHeight = durationMinutes != null
        ? (durationMinutes / 60.0 * hourHeight).clamp(28.0 * s, (24 * hourHeight - top).clamp(28.0 * s, double.infinity))
        : null;

    return Positioned(
      top: top,
      left: (56 + idx * 14) * s,
      right: 16 * s,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (blockHeight != null)
            Container(
              width: double.infinity,
              height: blockHeight,
              decoration: BoxDecoration(
                color: widget.t.accent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(ClarifyRadius.sm),
                border: Border(left: BorderSide(color: widget.t.accent.withValues(alpha: 0.5), width: 2.5 * s)),
              ),
            ),
          widget.buildCalendarTaskCard(task),
        ],
      ),
    );
  }
}
