import 'dart:math';
import 'package:flutter/material.dart';
import '../core/theme/design_tokens.dart';

/// Всплеск акцентных частиц для редких "ритуальных" моментов похвалы —
/// Team Pulse (герои дня), стрик/достижение (REDESIGN_V4_PLAN.md §6.7).
/// Намеренно НЕ используется как общий UI-элемент (никаких частиц на
/// свайп-удаление и т.п.) — только там, где сам момент по смыслу праздничный.
class ClarifySparkleBurst extends StatefulWidget {
  final Widget child;
  final bool trigger;

  const ClarifySparkleBurst({super.key, required this.child, required this.trigger});

  @override
  State<ClarifySparkleBurst> createState() => _ClarifySparkleBurstState();
}

class _ClarifySparkleBurstState extends State<ClarifySparkleBurst> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
  final _random = Random();
  late final List<_Sparkle> _sparkles = List.generate(10, (_) => _Sparkle(_random));

  @override
  void initState() {
    super.initState();
    if (widget.trigger) _controller.forward();
  }

  @override
  void didUpdateWidget(covariant ClarifySparkleBurst oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.trigger && !oldWidget.trigger) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    if (reduceMotion) return widget.child;
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        widget.child,
        IgnorePointer(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final progress = ClarifyMotion.standard.transform(_controller.value);
              return Stack(
                clipBehavior: Clip.none,
                children: _sparkles.map((sparkle) {
                  final dx = sparkle.dx * progress;
                  final dy = sparkle.dy * progress - 20 * progress * progress;
                  final opacity = _controller.isAnimating || _controller.value == 0 ? (1 - progress).clamp(0.0, 1.0) : 0.0;
                  return Positioned(
                    left: dx,
                    top: dy,
                    child: Opacity(
                      opacity: opacity,
                      child: Icon(Icons.auto_awesome, size: sparkle.size, color: t.accent),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _Sparkle {
  final double dx;
  final double dy;
  final double size;

  _Sparkle(Random random)
      : dx = (random.nextDouble() - 0.5) * 120,
        dy = (random.nextDouble() - 0.5) * 80,
        size = 10 + random.nextDouble() * 10;
}
