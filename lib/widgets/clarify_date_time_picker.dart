import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  static const double _itemExtent = 40;
  static const int _visibleRadius = 2;
  static const List<(int, int)> _presets = [(9, 0), (12, 0), (15, 0), (18, 0), (21, 0)];

  late int _hour;
  late int _minute;
  double _hourDrag = 0;
  double _minuteDrag = 0;
  bool _editingHour = false;
  bool _editingMinute = false;
  late final TextEditingController _hourFieldController;
  late final TextEditingController _minuteFieldController;
  late final FocusNode _hourFocusNode;
  late final FocusNode _minuteFocusNode;

  @override
  void initState() {
    super.initState();
    _hour = widget.initialTime.hour;
    _minute = widget.initialTime.minute;
    _hourFieldController = TextEditingController();
    _minuteFieldController = TextEditingController();
    _hourFocusNode = FocusNode()..addListener(_onHourFocusChange);
    _minuteFocusNode = FocusNode()..addListener(_onMinuteFocusChange);
  }

  @override
  void dispose() {
    _hourFocusNode.removeListener(_onHourFocusChange);
    _minuteFocusNode.removeListener(_onMinuteFocusChange);
    _hourFieldController.dispose();
    _minuteFieldController.dispose();
    _hourFocusNode.dispose();
    _minuteFocusNode.dispose();
    super.dispose();
  }

  void _onHourFocusChange() {
    if (!_hourFocusNode.hasFocus && _editingHour) _commitHourEdit();
  }

  void _onMinuteFocusChange() {
    if (!_minuteFocusNode.hasFocus && _editingMinute) _commitMinuteEdit();
  }

  void _startEditHour() {
    setState(() {
      _editingHour = true;
      _hourFieldController.text = _hour.toString().padLeft(2, '0');
      _hourFieldController.selection = TextSelection(baseOffset: 0, extentOffset: _hourFieldController.text.length);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _hourFocusNode.requestFocus());
  }

  void _startEditMinute() {
    setState(() {
      _editingMinute = true;
      _minuteFieldController.text = _minute.toString().padLeft(2, '0');
      _minuteFieldController.selection = TextSelection(baseOffset: 0, extentOffset: _minuteFieldController.text.length);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _minuteFocusNode.requestFocus());
  }

  void _commitHourEdit() {
    final parsed = int.tryParse(_hourFieldController.text);
    setState(() {
      if (parsed != null) _hour = parsed < 0 ? 0 : (parsed > 23 ? 23 : parsed);
      _editingHour = false;
    });
  }

  void _commitMinuteEdit() {
    final parsed = int.tryParse(_minuteFieldController.text);
    setState(() {
      if (parsed != null) _minute = parsed < 0 ? 0 : (parsed > 59 ? 59 : parsed);
      _editingMinute = false;
    });
  }

  // Своя drag-логика вместо ListWheelScrollView: последний реагирует и на
  // колесо мыши (Scrollable перехватывает PointerScrollEvent) — по концепту
  // нужен только жест перетаскивания, имитирующий тач-свайп на сенсорном
  // экране, колесо мыши сюда специально не подключено.
  void _onHourDrag(double delta) {
    setState(() {
      _hourDrag += delta;
      while (_hourDrag <= -_itemExtent) {
        _hourDrag += _itemExtent;
        _hour = (_hour + 1) % 24;
      }
      while (_hourDrag >= _itemExtent) {
        _hourDrag -= _itemExtent;
        _hour = (_hour - 1 + 24) % 24;
      }
    });
  }

  void _onMinuteDrag(double delta) {
    setState(() {
      _minuteDrag += delta;
      while (_minuteDrag <= -_itemExtent) {
        _minuteDrag += _itemExtent;
        _minute = (_minute + 1) % 60;
      }
      while (_minuteDrag >= _itemExtent) {
        _minuteDrag -= _itemExtent;
        _minute = (_minute - 1 + 60) % 60;
      }
    });
  }

  Widget _column({
    required int value,
    required int itemCount,
    required double dragOffset,
    required void Function(double) onDrag,
    required VoidCallback onDragEnd,
    required bool editing,
    required TextEditingController fieldController,
    required FocusNode focusNode,
    required VoidCallback onStartEdit,
    required ClarifyTokens t,
  }) {
    if (editing) {
      return SizedBox(
        width: 64,
        height: _itemExtent,
        child: TextField(
          controller: fieldController,
          focusNode: focusNode,
          autofocus: true,
          textAlign: TextAlign.center,
          keyboardType: TextInputType.number,
          maxLength: 2,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(counterText: '', border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero),
          style: TextStyle(color: t.text, fontSize: 22, fontWeight: FontWeight.w600),
          onSubmitted: (_) => focusNode.unfocus(),
        ),
      );
    }
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onVerticalDragUpdate: (details) => onDrag(details.delta.dy),
      onVerticalDragEnd: (_) => onDragEnd(),
      onTap: onStartEdit,
      child: SizedBox(
        width: 64,
        height: _itemExtent * (_visibleRadius * 2 + 1),
        child: ClipRect(
          child: Stack(
            alignment: Alignment.center,
            children: [
              for (var offset = -_visibleRadius; offset <= _visibleRadius; offset++)
                Transform.translate(
                  offset: Offset(0, offset * _itemExtent + dragOffset),
                  child: SizedBox(
                    height: _itemExtent,
                    child: Center(
                      child: Opacity(
                        opacity: offset == 0 ? 1.0 : (1.0 - offset.abs() * 0.3),
                        child: Text(
                          (((value + offset) % itemCount + itemCount) % itemCount).toString().padLeft(2, '0'),
                          style: TextStyle(
                            color: t.text,
                            fontSize: offset == 0 ? 22 : 16,
                            fontWeight: offset == 0 ? FontWeight.w600 : FontWeight.w400,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
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
                    height: _itemExtent,
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(color: t.accentSoft, borderRadius: BorderRadius.circular(ClarifyRadius.sm)),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _column(
                        value: _hour,
                        itemCount: 24,
                        dragOffset: _hourDrag,
                        onDrag: _onHourDrag,
                        onDragEnd: () => setState(() => _hourDrag = 0),
                        editing: _editingHour,
                        fieldController: _hourFieldController,
                        focusNode: _hourFocusNode,
                        onStartEdit: _startEditHour,
                        t: t,
                      ),
                      Text(':', style: TextStyle(color: t.text, fontSize: 22, fontWeight: FontWeight.bold)),
                      _column(
                        value: _minute,
                        itemCount: 60,
                        dragOffset: _minuteDrag,
                        onDrag: _onMinuteDrag,
                        onDragEnd: () => setState(() => _minuteDrag = 0),
                        editing: _editingMinute,
                        fieldController: _minuteFieldController,
                        focusNode: _minuteFocusNode,
                        onStartEdit: _startEditMinute,
                        t: t,
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                alignment: WrapAlignment.center,
                children: _presets.map((p) {
                  final selected = _hour == p.$1 && _minute == p.$2;
                  return InkWell(
                    borderRadius: BorderRadius.circular(ClarifyRadius.pill),
                    onTap: () => setState(() {
                      _hour = p.$1;
                      _minute = p.$2;
                    }),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: selected ? t.accentSoft : Colors.transparent,
                        borderRadius: BorderRadius.circular(ClarifyRadius.pill),
                        border: Border.all(color: selected ? t.accent.withValues(alpha: 0.4) : t.border),
                      ),
                      child: Text(
                        '${p.$1.toString().padLeft(2, '0')}:${p.$2.toString().padLeft(2, '0')}',
                        style: TextStyle(color: selected ? t.accent : t.text2, fontSize: 13, fontWeight: selected ? FontWeight.bold : FontWeight.normal),
                      ),
                    ),
                  );
                }).toList(),
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
