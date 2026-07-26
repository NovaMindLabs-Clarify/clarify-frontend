import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../core/priority.dart';
import '../core/theme/design_tokens.dart';

/// Единый интерактивный "рычаг" выбора приоритета — REDESIGN_V4_PLAN.md §6.3.
/// Заменяет ряд из 5 одинаковых кружков (нарушение чек-листа §5: "ряд
/// одинаковых иконок-свотчей вместо одного интерактивного объекта") одним
/// объектом — бегунок можно тащить по треку или тапнуть по нужной позиции.
class ClarifyPriorityLever extends StatefulWidget {
  final String value;
  final ValueChanged<String> onChanged;
  final Color Function(String? priority) getPriorityColor;
  final Color textMuted;

  const ClarifyPriorityLever({
    super.key,
    required this.value,
    required this.onChanged,
    required this.getPriorityColor,
    required this.textMuted,
  });

  @override
  State<ClarifyPriorityLever> createState() => _ClarifyPriorityLeverState();
}

class _ClarifyPriorityLeverState extends State<ClarifyPriorityLever> {
  static const List<String> _stops = ['none', ...kPriorityLevels];
  static const double _thumbSize = 28;

  Color _colorFor(String stop) => stop == 'none' ? widget.textMuted : widget.getPriorityColor(stop);

  void _handlePointer(double localDx, double maxWidth) {
    final trackWidth = maxWidth - _thumbSize;
    if (trackWidth <= 0) return;
    final thumbLeft = (localDx - _thumbSize / 2).clamp(0.0, trackWidth);
    final index = (thumbLeft / trackWidth * (_stops.length - 1)).round().clamp(0, _stops.length - 1);
    final stop = _stops[index];
    if (stop != widget.value) widget.onChanged(stop);
  }

  @override
  Widget build(BuildContext context) {
    final index = _stops.indexOf(widget.value).clamp(0, _stops.length - 1);
    final color = _colorFor(widget.value);

    return LayoutBuilder(
      builder: (context, constraints) {
        final trackWidth = constraints.maxWidth - _thumbSize;
        final thumbLeft = trackWidth <= 0 ? 0.0 : trackWidth * index / (_stops.length - 1);

        return SizedBox(
          height: _thumbSize,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (d) => _handlePointer(d.localPosition.dx, constraints.maxWidth),
            onPanUpdate: (d) => _handlePointer(d.localPosition.dx, constraints.maxWidth),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  top: _thumbSize / 2 - 2,
                  left: _thumbSize / 2,
                  right: _thumbSize / 2,
                  child: Container(
                    height: 4,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(ClarifyRadius.pill),
                      gradient: LinearGradient(
                        colors: _stops.map((s) => _colorFor(s).withValues(alpha: 0.35)).toList(),
                      ),
                    ),
                  ),
                ),
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                  left: thumbLeft,
                  top: 0,
                  child: Container(
                    width: _thumbSize,
                    height: _thumbSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: widget.value == 'none' ? Colors.transparent : color.withValues(alpha: 0.16),
                      border: Border.all(color: color, width: 2),
                    ),
                    alignment: Alignment.center,
                    child: widget.value == 'none'
                        ? Icon(LucideIcons.x, size: 14, color: widget.textMuted)
                        : Icon(LucideIcons.flag, size: 14, color: color),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
