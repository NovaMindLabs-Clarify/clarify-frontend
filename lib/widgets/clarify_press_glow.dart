import 'package:flutter/material.dart';
import '../core/theme/design_tokens.dart';

/// Цветное «облачко» позади интерактивного элемента, видимое пока он нажат —
/// отдельный слой СНАРУЖИ дочернего виджета (не ink-splash ВНУТРИ границ,
/// который и так есть у Material), поэтому не обрезается собственным
/// clip/border-radius/формой ребёнка.
class ClarifyGlowLayer extends StatelessWidget {
  final bool active;
  final Color color;
  final double spread;

  const ClarifyGlowLayer({
    super.key,
    required this.active,
    required this.color,
    this.spread = 20,
  });

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final visible = active && !reduceMotion;
    return Positioned(
      left: -spread,
      right: -spread,
      top: -spread,
      bottom: -spread,
      child: IgnorePointer(
        child: AnimatedOpacity(
          opacity: visible ? 1 : 0,
          duration: ClarifyMotion.base,
          curve: ClarifyMotion.standard,
          child: AnimatedScale(
            scale: visible ? 1.0 : 0.75,
            duration: ClarifyMotion.base,
            curve: ClarifyMotion.standard,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [
                    color.withValues(alpha: 0.30),
                    color.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Оборачивает любой интерактивный виджет откликом-облачком при нажатии — для
/// мест, которые сами не отслеживают своё press-состояние (кнопки, строки
/// меню). Если виджет уже отслеживает press сам (см. `ClarifyPressable`),
/// используйте [ClarifyGlowLayer] напрямую в его собственном Stack — не нужно
/// заводить второй независимый обработчик нажатия поверх первого.
class ClarifyPressGlow extends StatefulWidget {
  final Widget child;
  final Color color;
  final double spread;

  const ClarifyPressGlow({
    super.key,
    required this.child,
    required this.color,
    this.spread = 20,
  });

  @override
  State<ClarifyPressGlow> createState() => _ClarifyPressGlowState();
}

class _ClarifyPressGlowState extends State<ClarifyPressGlow> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (mounted && _pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _setPressed(true),
      onPointerUp: (_) => _setPressed(false),
      onPointerCancel: (_) => _setPressed(false),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          ClarifyGlowLayer(
            active: _pressed,
            color: widget.color,
            spread: widget.spread,
          ),
          widget.child,
        ],
      ),
    );
  }
}
