import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../core/localization.dart';
import '../core/theme/design_tokens.dart';
import 'clarify_button.dart';
import 'clarify_glass.dart';
import 'clarify_surface.dart';

/// Выбор длительности задачи в минутах — пресеты вместо ещё одного колёсика
/// (см. docs/COMPETITOR_ANALYSIS_UPDATE_2026-07-31.md §3): без этого поля
/// CalendarDayTimeline не может рисовать блок задачи пропорционально её
/// длительности, как у целевого референса Structured. `null` — «без
/// длительности», сохраняет прежнее поведение (блок фиксированной высоты).
/// Пресетов не хватает на все случаи — "Другое" открывает
/// [showClarifyCustomDurationPicker] со ступенчатым выбором часов/минут.
const List<int> clarifyDurationPresets = [15, 30, 45, 60, 90, 120];

String formatDurationMinutes(int minutes, String currentLang) {
  if (minutes < 60) return '$minutes ${"мин".tr(currentLang)}';
  final hours = minutes ~/ 60;
  final rest = minutes % 60;
  if (rest == 0) return '$hours ${"ч".tr(currentLang)}';
  return '$hours ${"ч".tr(currentLang)} $rest ${"мин".tr(currentLang)}';
}

class ClarifyDurationChips extends StatelessWidget {
  final int? selectedMinutes;
  final String currentLang;
  final bool isDark;
  final void Function(int? minutes) onChanged;

  const ClarifyDurationChips({
    super.key,
    required this.selectedMinutes,
    required this.currentLang,
    required this.isDark,
    required this.onChanged,
  });

  bool get _isCustom =>
      selectedMinutes != null &&
      !clarifyDurationPresets.contains(selectedMinutes);

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final minutes in clarifyDurationPresets)
          _chip(
            t: t,
            label: formatDurationMinutes(minutes, currentLang),
            selected: selectedMinutes == minutes,
            onTap: () => onChanged(selectedMinutes == minutes ? null : minutes),
          ),
        _chip(
          t: t,
          label: _isCustom
              ? formatDurationMinutes(selectedMinutes!, currentLang)
              : 'Другое'.tr(currentLang),
          selected: _isCustom,
          onTap: () async {
            final picked = await showClarifyCustomDurationPicker(
              context: context,
              isDark: isDark,
              currentLang: currentLang,
              initialMinutes: _isCustom ? selectedMinutes : null,
            );
            if (picked != null) onChanged(picked == 0 ? null : picked);
          },
        ),
      ],
    );
  }

  Widget _chip({
    required ClarifyTokens t,
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(ClarifyRadius.pill),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? t.accentSoft : Colors.transparent,
          borderRadius: BorderRadius.circular(ClarifyRadius.pill),
          border: Border.all(
            color: selected ? t.accent.withValues(alpha: 0.4) : t.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? t.accent : t.text2,
            fontSize: 13,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

/// Ступенчатый выбор произвольной длительности (часы 0-8 + минуты с шагом 5) —
/// для случаев, которые не покрывают пресеты 15/30/45/60/90/120.
Future<int?> showClarifyCustomDurationPicker({
  required BuildContext context,
  required bool isDark,
  required String currentLang,
  int? initialMinutes,
}) {
  return showClarifySurface<int>(
    context: context,
    builder: (context) => _CustomDurationDialog(
      isDark: isDark,
      currentLang: currentLang,
      initialMinutes: initialMinutes ?? 60,
    ),
  );
}

class _CustomDurationDialog extends StatefulWidget {
  final bool isDark;
  final String currentLang;
  final int initialMinutes;

  const _CustomDurationDialog({
    required this.isDark,
    required this.currentLang,
    required this.initialMinutes,
  });

  @override
  State<_CustomDurationDialog> createState() => _CustomDurationDialogState();
}

class _CustomDurationDialogState extends State<_CustomDurationDialog> {
  static const int _maxHours = 8;
  static const int _minuteStep = 5;

  late int _hours;
  late int _minutes;

  @override
  void initState() {
    super.initState();
    _hours = widget.initialMinutes ~/ 60;
    _minutes = widget.initialMinutes % 60;
  }

  void _changeHours(int delta) {
    setState(() => _hours = (_hours + delta).clamp(0, _maxHours));
  }

  void _changeMinutes(int delta) {
    setState(() {
      _minutes += delta;
      if (_minutes < 0) {
        _minutes = 60 - _minuteStep;
        _changeHours(-1);
      } else if (_minutes >= 60) {
        _minutes = 0;
        _changeHours(1);
      }
    });
  }

  Widget _stepper({
    required ClarifyTokens t,
    required String label,
    required int value,
    required VoidCallback onDecrement,
    required VoidCallback onIncrement,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            color: t.text2,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(LucideIcons.circleMinus, color: t.text2),
              onPressed: onDecrement,
            ),
            SizedBox(
              width: 44,
              child: Text(
                '$value'.padLeft(2, '0'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: t.text,
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            IconButton(
              icon: Icon(LucideIcons.circlePlus, color: t.text2),
              onPressed: onIncrement,
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.isDark ? ClarifyTokens.dark : ClarifyTokens.light;
    final totalMinutes = _hours * 60 + _minutes;
    return Center(
      child: Material(
        color: Colors.transparent,
        child: ClarifyGlass(
          borderRadius: ClarifyRadius.dialogShell,
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Длительность'.tr(widget.currentLang),
                style: TextStyle(
                  color: t.text,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _stepper(
                    t: t,
                    label: 'ч'.tr(widget.currentLang),
                    value: _hours,
                    onDecrement: () => _changeHours(-1),
                    onIncrement: () => _changeHours(1),
                  ),
                  const SizedBox(width: 16),
                  _stepper(
                    t: t,
                    label: 'мин'.tr(widget.currentLang),
                    value: _minutes,
                    onDecrement: () => _changeMinutes(-_minuteStep),
                    onIncrement: () => _changeMinutes(_minuteStep),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ClarifyButton(
                    label: 'Без длительности'.tr(widget.currentLang),
                    variant: ClarifyButtonVariant.ghost,
                    onPressed: () => Navigator.of(context).pop(0),
                  ),
                  const SizedBox(width: 8),
                  ClarifyButton(
                    label: 'Готово'.tr(widget.currentLang),
                    variant: ClarifyButtonVariant.filled,
                    onPressed: totalMinutes > 0
                        ? () => Navigator.of(context).pop(totalMinutes)
                        : null,
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
