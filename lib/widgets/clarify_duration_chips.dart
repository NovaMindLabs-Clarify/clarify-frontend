import 'package:flutter/material.dart';
import '../core/localization.dart';
import '../core/theme/design_tokens.dart';

/// Выбор длительности задачи в минутах — пресеты вместо ещё одного колёсика
/// (см. docs/COMPETITOR_ANALYSIS_UPDATE_2026-07-31.md §3): без этого поля
/// CalendarDayTimeline не может рисовать блок задачи пропорционально её
/// длительности, как у целевого референса Structured. `null` — «без
/// длительности», сохраняет прежнее поведение (блок фиксированной высоты).
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
  final void Function(int? minutes) onChanged;

  const ClarifyDurationChips({
    super.key,
    required this.selectedMinutes,
    required this.currentLang,
    required this.onChanged,
  });

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
      ],
    );
  }

  Widget _chip({required ClarifyTokens t, required String label, required bool selected, required VoidCallback onTap}) {
    return InkWell(
      borderRadius: BorderRadius.circular(ClarifyRadius.pill),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? t.accentSoft : Colors.transparent,
          borderRadius: BorderRadius.circular(ClarifyRadius.pill),
          border: Border.all(color: selected ? t.accent.withValues(alpha: 0.4) : t.border),
        ),
        child: Text(
          label,
          style: TextStyle(color: selected ? t.accent : t.text2, fontSize: 13, fontWeight: selected ? FontWeight.bold : FontWeight.normal),
        ),
      ),
    );
  }
}
