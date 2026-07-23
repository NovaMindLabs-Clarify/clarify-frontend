import 'package:flutter/material.dart';
import '../core/theme/design_tokens.dart';

/// Мягкое появление списка при первом рендере экрана — fade+slide всего
/// контейнера целиком, не per-item stagger (REDESIGN_V3_PLAN.md §5.6: "не на
/// каждый через weight — иначе это уже не «сдержанно»"). Разовая анимация на
/// монтирование виджета, не повторяется при последующих rebuild.
class ClarifyListEntrance extends StatelessWidget {
  final Widget child;

  const ClarifyListEntrance({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    if (reduceMotion) return child;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: ClarifyMotion.deliberate,
      curve: ClarifyMotion.standard,
      builder: (context, value, builtChild) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 16),
            child: builtChild,
          ),
        );
      },
      child: child,
    );
  }
}
