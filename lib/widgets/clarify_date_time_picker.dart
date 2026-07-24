import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../core/localization.dart';
import '../core/theme/design_tokens.dart';
import 'clarify_glass.dart';
import 'clarify_surface.dart';

/// Свои date/time picker'ы в стекле — замена стоковых `showDatePicker`/
/// `showTimePicker` (REDESIGN_V3_PLAN.md §3.5/5.5). Та же месячная сетка, что
/// уже используется в десктопном «Календаре» (MainContentArea), но упрощённая
/// (без задач — только выбор дня).
Future<DateTime?> showClarifyDatePicker({
  required BuildContext context,
  required bool isDark,
  required String currentLang,
  DateTime? initialDate,
}) {
  return showClarifySurface<DateTime>(
    context: context,
    builder: (context) => _ClarifyDatePickerDialog(isDark: isDark, currentLang: currentLang, initialDate: initialDate ?? DateTime.now()),
  );
}

Future<TimeOfDay?> showClarifyTimePicker({
  required BuildContext context,
  required bool isDark,
  required String currentLang,
  TimeOfDay? initialTime,
}) {
  return showClarifySurface<TimeOfDay>(
    context: context,
    builder: (context) => _ClarifyTimePickerDialog(isDark: isDark, currentLang: currentLang, initialTime: initialTime ?? TimeOfDay.now()),
  );
}

class _ClarifyDatePickerDialog extends StatefulWidget {
  final bool isDark;
  final String currentLang;
  final DateTime initialDate;

  const _ClarifyDatePickerDialog({required this.isDark, required this.currentLang, required this.initialDate});

  @override
  State<_ClarifyDatePickerDialog> createState() => _ClarifyDatePickerDialogState();
}

class _ClarifyDatePickerDialogState extends State<_ClarifyDatePickerDialog> {
  late DateTime _visibleMonth;
  static const _monthsRu = ['', 'Январь', 'Февраль', 'Март', 'Апрель', 'Май', 'Июнь', 'Июль', 'Август', 'Сентябрь', 'Октябрь', 'Ноябрь', 'Декабрь'];
  static const _weekdaysRu = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];

  @override
  void initState() {
    super.initState();
    _visibleMonth = DateTime(widget.initialDate.year, widget.initialDate.month);
  }

  bool _isSameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    final t = widget.isDark ? ClarifyTokens.dark : ClarifyTokens.light;
    final today = DateTime.now();
    final year = _visibleMonth.year;
    final month = _visibleMonth.month;
    final firstDayOfMonth = DateTime(year, month, 1);
    final lastDayOfMonth = DateTime(year, month + 1, 0);
    final startOffset = firstDayOfMonth.weekday - 1;
    final totalDays = lastDayOfMonth.day;
    final totalCells = startOffset + totalDays;

    return Center(
      child: Material(
        color: Colors.transparent,
        child: ClarifyGlass(
          borderRadius: BorderRadius.circular(ClarifyRadius.lg),
          padding: const EdgeInsets.all(20),
          child: SizedBox(
            width: 320,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: Icon(LucideIcons.chevronLeft, color: t.text),
                      onPressed: () => setState(() => _visibleMonth = DateTime(year, month - 1)),
                    ),
                    Text('${_monthsRu[month].tr(widget.currentLang)} $year', style: TextStyle(color: t.text, fontWeight: FontWeight.bold, fontSize: 16)),
                    IconButton(
                      icon: Icon(LucideIcons.chevronRight, color: t.text),
                      onPressed: () => setState(() => _visibleMonth = DateTime(year, month + 1)),
                    ),
                  ],
                ),
                Row(
                  children: _weekdaysRu
                      .map((d) => Expanded(child: Center(child: Text(d.tr(widget.currentLang), style: TextStyle(color: t.text2, fontWeight: FontWeight.bold, fontSize: 12)))))
                      .toList(),
                ),
                const SizedBox(height: 8),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7),
                  itemCount: totalCells,
                  itemBuilder: (context, index) {
                    if (index < startOffset) return const SizedBox.shrink();
                    final dayNumber = index - startOffset + 1;
                    final cellDate = DateTime(year, month, dayNumber);
                    final isToday = _isSameDay(cellDate, today);
                    final isSelected = _isSameDay(cellDate, widget.initialDate);
                    return Padding(
                      padding: const EdgeInsets.all(2),
                      child: Material(
                        color: isSelected ? t.accent : Colors.transparent,
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () => Navigator.of(context).pop(cellDate),
                          child: Center(
                            child: Text(
                              '$dayNumber',
                              style: TextStyle(
                                color: isSelected ? t.onAccent : (isToday ? t.accent : t.text),
                                fontWeight: isToday || isSelected ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(onPressed: () => Navigator.of(context).pop(), child: Text('Отмена'.tr(widget.currentLang), style: TextStyle(color: t.text2))),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ClarifyTimePickerDialog extends StatefulWidget {
  final bool isDark;
  final String currentLang;
  final TimeOfDay initialTime;

  const _ClarifyTimePickerDialog({required this.isDark, required this.currentLang, required this.initialTime});

  @override
  State<_ClarifyTimePickerDialog> createState() => _ClarifyTimePickerDialogState();
}

class _ClarifyTimePickerDialogState extends State<_ClarifyTimePickerDialog> {
  late int _hour;
  late int _minute;
  late final FixedExtentScrollController _hourController;
  late final FixedExtentScrollController _minuteController;

  @override
  void initState() {
    super.initState();
    _hour = widget.initialTime.hour;
    _minute = widget.initialTime.minute;
    _hourController = FixedExtentScrollController(initialItem: _hour);
    _minuteController = FixedExtentScrollController(initialItem: _minute);
  }

  @override
  void dispose() {
    _hourController.dispose();
    _minuteController.dispose();
    super.dispose();
  }

  Widget _wheel({
    required int itemCount,
    required FixedExtentScrollController controller,
    required void Function(int) onChanged,
    required ClarifyTokens t,
  }) {
    return SizedBox(
      width: 64,
      height: 160,
      child: ListWheelScrollView.useDelegate(
        controller: controller,
        itemExtent: 40,
        diameterRatio: 1.4,
        physics: const FixedExtentScrollPhysics(),
        onSelectedItemChanged: onChanged,
        childDelegate: ListWheelChildBuilderDelegate(
          childCount: itemCount,
          builder: (context, index) => Center(
            child: Text(
              index.toString().padLeft(2, '0'),
              style: TextStyle(color: t.text, fontSize: 22, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.isDark ? ClarifyTokens.dark : ClarifyTokens.light;

    return Center(
      child: Material(
        color: Colors.transparent,
        child: ClarifyGlass(
          borderRadius: BorderRadius.circular(ClarifyRadius.lg),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Время'.tr(widget.currentLang), style: TextStyle(color: t.text, fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 12),
              Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    height: 40,
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(color: t.accentSoft, borderRadius: BorderRadius.circular(ClarifyRadius.sm)),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _wheel(itemCount: 24, controller: _hourController, onChanged: (v) => _hour = v, t: t),
                      Text(':', style: TextStyle(color: t.text, fontSize: 22, fontWeight: FontWeight.bold)),
                      _wheel(itemCount: 60, controller: _minuteController, onChanged: (v) => _minute = v, t: t),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(onPressed: () => Navigator.of(context).pop(), child: Text('Отмена'.tr(widget.currentLang), style: TextStyle(color: t.text2))),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: t.accent, foregroundColor: t.onAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ClarifyRadius.sm))),
                    onPressed: () => Navigator.of(context).pop(TimeOfDay(hour: _hour, minute: _minute)),
                    child: Text('Готово'.tr(widget.currentLang), style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
