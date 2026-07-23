import 'package:flutter/material.dart';
import '../core/theme/design_tokens.dart';

/// Нефото-текстура под рабочими экранами десктопа (REDESIGN_V3_PLAN.md §3.1/5.1) —
/// возвращает `BackdropFilter` в [ClarifyGlass] то, что реально размывать, не
/// повторяя фото-фон v1 (спорил с UI, см. DESIGN_SYSTEM.md §5). 2-3 мягких
/// цветовых пятна на очень медленном дрифте — статичнее, чем любой UI-переход,
/// поэтому не через `ClarifyMotion`, а отдельный долгий `AnimationController`.
class AmbientBackground extends StatefulWidget {
  final bool isDark;
  final Widget child;

  const AmbientBackground({super.key, required this.isDark, required this.child});

  @override
  State<AmbientBackground> createState() => _AmbientBackgroundState();
}

class _AmbientBackgroundState extends State<AmbientBackground> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 50))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.isDark ? ClarifyTokens.dark : ClarifyTokens.light;
    final double alpha = widget.isDark ? 0.14 : 0.07;
    final reduceMotion = MediaQuery.of(context).disableAnimations;

    final blobs = [
      (color: t.accent, begin: const Alignment(-0.9, -0.8), end: const Alignment(-0.6, -0.5)),
      (color: t.tagPalette[2], begin: const Alignment(0.9, -0.6), end: const Alignment(0.7, -0.9)),
      (color: t.tagPalette[4], begin: const Alignment(0.2, 1.0), end: const Alignment(-0.1, 0.7)),
    ];

    return Stack(
      fit: StackFit.expand,
      children: [
        Container(color: t.bg),
        if (reduceMotion)
          for (final blob in blobs)
            Align(alignment: blob.begin, child: _Blob(color: blob.color, alpha: alpha))
        else
          AnimatedBuilder(
            animation: _controller,
            builder: (context, _) => Stack(
              fit: StackFit.expand,
              children: [
                for (final blob in blobs)
                  Align(
                    alignment: Alignment.lerp(blob.begin, blob.end, _controller.value)!,
                    child: _Blob(color: blob.color, alpha: alpha),
                  ),
              ],
            ),
          ),
        widget.child,
      ],
    );
  }
}

class _Blob extends StatelessWidget {
  final Color color;
  final double alpha;

  const _Blob({required this.color, required this.alpha});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: 700,
        height: 700,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color.withValues(alpha: alpha), color.withValues(alpha: 0)],
          ),
        ),
      ),
    );
  }
}
