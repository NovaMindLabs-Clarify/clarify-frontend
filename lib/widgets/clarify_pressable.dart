import 'package:flutter/material.dart';
import '../core/theme/design_tokens.dart';

/// Лёгкий tap-фидбек (scale 0.97 на press) для карточек/кнопок, где раньше
/// не было вообще никакой реакции на нажатие — голый `GestureDetector`
/// (REDESIGN_V3_PLAN.md §3.6/5.6). Не заменяет `InkWell`/`Material`-ripple
/// там, где он уже есть — только для мест без какого-либо визуального отклика.
class ClarifyPressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;

  const ClarifyPressable({super.key, required this.child, this.onTap});

  @override
  State<ClarifyPressable> createState() => _ClarifyPressableState();
}

class _ClarifyPressableState extends State<ClarifyPressable> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (mounted) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      child: AnimatedScale(
        scale: _pressed && !reduceMotion ? 0.97 : 1.0,
        duration: ClarifyMotion.fast,
        curve: ClarifyMotion.standard,
        child: widget.child,
      ),
    );
  }
}
