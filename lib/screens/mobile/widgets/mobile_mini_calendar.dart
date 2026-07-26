import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../core/localization.dart';
import '../../../core/theme/design_tokens.dart';

/// Мини-календарь наверху «Мой день»/«Задачи» на мобильном (REDESIGN_V3_PLAN.md
/// §3.7/5.7) — сворачиваемая неделя⇄месяц. Тап по дню — фильтр списка ниже по
/// выбранной дате; тап по шеврону/заголовку — разворот в месяц, повторный тап —
/// обратно в неделю. Высота анимируется через `AnimatedSize`.
class MobileMiniCalendar extends StatefulWidget {
  final String currentLang;
  final DateTime selectedDate;
  final void Function(DateTime date) onDaySelected;

  const MobileMiniCalendar({
    super.key,
    required this.currentLang,
    required this.selectedDate,
    required this.onDaySelected,
  });

  @override
  State<MobileMiniCalendar> createState() => _MobileMiniCalendarState();
}

class _MobileMiniCalendarState extends State<MobileMiniCalendar> {
  bool _expanded = false;
  late DateTime _visibleMonth = DateTime(widget.selectedDate.year, widget.selectedDate.month);

  static const _monthsRu = ['', 'Январь', 'Февраль', 'Март', 'Апрель', 'Май', 'Июнь', 'Июль', 'Август', 'Сентябрь', 'Октябрь', 'Ноябрь', 'Декабрь'];
  static const _weekdaysRu = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];

  bool _isSameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  List<DateTime> _currentWeek() {
    final today = widget.selectedDate;
    final monday = today.subtract(Duration(days: today.weekday - 1));
    return List.generate(7, (i) => monday.add(Duration(days: i)));
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final today = DateTime.now();

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: t.surface2, borderRadius: BorderRadius.circular(ClarifyRadius.md), border: Border.all(color: t.border)),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(ClarifyRadius.sm),
            onTap: () => setState(() {
              _expanded = !_expanded;
              _visibleMonth = DateTime(widget.selectedDate.year, widget.selectedDate.month);
            }),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${_monthsRu[_visibleMonth.month].tr(widget.currentLang)} ${_visibleMonth.year}',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: t.text2),
                  ),
                  Icon(_expanded ? LucideIcons.chevronUp : LucideIcons.chevronDown, size: 18, color: t.text3),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: ClarifyMotion.base,
            curve: ClarifyMotion.spring,
            alignment: Alignment.topCenter,
            child: _expanded ? _buildMonthGrid(t, today) : _buildWeekRow(t, today),
          ),
        ],
      ),
    );
  }

  Widget _buildWeekRow(ClarifyTokens t, DateTime today) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: _currentWeek().map((day) => _DayCell(
              day: day,
              label: _weekdaysRu[day.weekday - 1].tr(widget.currentLang),
              isToday: _isSameDay(day, today),
              isSelected: _isSameDay(day, widget.selectedDate),
              onTap: () => widget.onDaySelected(day),
            )).toList(),
      ),
    );
  }

  Widget _buildMonthGrid(ClarifyTokens t, DateTime today) {
    final year = _visibleMonth.year;
    final month = _visibleMonth.month;
    final firstDayOfMonth = DateTime(year, month, 1);
    final lastDayOfMonth = DateTime(year, month + 1, 0);
    final startOffset = firstDayOfMonth.weekday - 1;
    final totalDays = lastDayOfMonth.day;
    final totalCells = startOffset + totalDays;
    final rows = (totalCells / 7).ceil();

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: Icon(LucideIcons.chevronLeft, size: 18, color: t.text2),
                onPressed: () => setState(() => _visibleMonth = DateTime(year, month - 1)),
              ),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: Icon(LucideIcons.chevronRight, size: 18, color: t.text2),
                onPressed: () => setState(() => _visibleMonth = DateTime(year, month + 1)),
              ),
            ],
          ),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7, childAspectRatio: 1.4, mainAxisExtent: 36),
            itemCount: rows * 7,
            itemBuilder: (context, index) {
              if (index < startOffset || index >= startOffset + totalDays) return const SizedBox.shrink();
              final dayNumber = index - startOffset + 1;
              final day = DateTime(year, month, dayNumber);
              return _DayCell(
                day: day,
                label: '$dayNumber',
                isToday: _isSameDay(day, today),
                isSelected: _isSameDay(day, widget.selectedDate),
                onTap: () {
                  widget.onDaySelected(day);
                  setState(() => _expanded = false);
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  final DateTime day;
  final String label;
  final bool isToday;
  final bool isSelected;
  final VoidCallback onTap;

  const _DayCell({required this.day, required this.label, required this.isToday, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: 32,
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isSelected ? t.accent : Colors.transparent,
          border: isToday && !isSelected ? Border.all(color: t.accent, width: 1.5) : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected || isToday ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? t.onAccent : (isToday ? t.accent : t.text2),
          ),
        ),
      ),
    );
  }
}
