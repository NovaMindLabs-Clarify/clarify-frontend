import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../core/theme/design_tokens.dart';

/// Анимированный кружок выполнения задачи — замена стокового
/// `Checkbox(shape: CircleBorder())`, у которого не было вообще никакой
/// анимации кроме дефолтного ripple. Заливка и галочка "дорисовываются"
/// (fade+рост), не мгновенный скачок. Сдержанно — без bounce/overshoot
/// (см. эталон движения v3, `ClarifyMotion.standard`, не `.spring`).
class ClarifyCheckCircle extends StatefulWidget {
  final bool value;
  final VoidCallback? onTap;
  final double size;
  final Color borderColor;
  final Color checkedColor;
  final Color checkIconColor;
  final double borderWidth;

  const ClarifyCheckCircle({
    super.key,
    required this.value,
    required this.onTap,
    required this.borderColor,
    required this.checkedColor,
    this.size = 22,
    this.checkIconColor = Colors.white,
    this.borderWidth = 2.0,
  });

  @override
  State<ClarifyCheckCircle> createState() => _ClarifyCheckCircleState();
}

class _ClarifyCheckCircleState extends State<ClarifyCheckCircle> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _progress;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: ClarifyMotion.base, value: widget.value ? 1 : 0);
    _progress = CurvedAnimation(parent: _controller, curve: ClarifyMotion.standard);
  }

  @override
  void didUpdateWidget(covariant ClarifyCheckCircle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      widget.value ? _controller.forward() : _controller.reverse();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _progress,
        builder: (context, _) {
          final t = _progress.value.clamp(0.0, 1.0);
          return Container(
            width: widget.size,
            height: widget.size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Color.lerp(Colors.transparent, widget.checkedColor, t),
              border: Border.all(color: Color.lerp(widget.borderColor, widget.checkedColor, t)!, width: widget.borderWidth),
            ),
            child: t > 0.02
                ? Opacity(
                    opacity: t,
                    child: Icon(LucideIcons.check, size: widget.size * 0.62, color: widget.checkIconColor),
                  )
                : null,
          );
        },
      ),
    );
  }
}

/// Анимированное зачёркивание текста — линия "дорисовывается" слева направо
/// при выполнении, при отмене — растворяется (не мгновенно исчезает). Цвет
/// самого текста не анимируется (это решает вызывающий код), только линия.
class ClarifyStrikeText extends StatefulWidget {
  final String text;
  final TextStyle style;
  final bool isDone;
  final int? maxLines;
  final TextOverflow overflow;
  final Color? strikeColor;

  const ClarifyStrikeText({
    super.key,
    required this.text,
    required this.style,
    required this.isDone,
    this.maxLines = 1,
    this.overflow = TextOverflow.ellipsis,
    this.strikeColor,
  });

  @override
  State<ClarifyStrikeText> createState() => _ClarifyStrikeTextState();
}

class _ClarifyStrikeTextState extends State<ClarifyStrikeText> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _progress;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: ClarifyMotion.base, value: widget.isDone ? 1 : 0);
    _progress = CurvedAnimation(parent: _controller, curve: ClarifyMotion.standard);
  }

  @override
  void didUpdateWidget(covariant ClarifyStrikeText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isDone != widget.isDone) {
      widget.isDone ? _controller.forward() : _controller.reverse();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.strikeColor ?? widget.style.color ?? Colors.black;
    return Stack(
      alignment: Alignment.centerLeft,
      children: [
        Text(widget.text, style: widget.style, maxLines: widget.maxLines, overflow: widget.overflow),
        AnimatedBuilder(
          animation: _progress,
          builder: (context, _) {
            final t = _progress.value.clamp(0.0, 1.0);
            if (t <= 0.001) return const SizedBox.shrink();
            return Positioned.fill(
              child: Align(
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: t,
                  alignment: Alignment.centerLeft,
                  child: Container(height: 1.4, color: color),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
