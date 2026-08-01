import 'dart:ui';
import 'package:flutter/material.dart';
import '../core/theme/design_tokens.dart';

/// Единый рецепт стекла — см. docs/REDESIGN_V2_PLAN.md §5.2. Сильнее размытие,
/// чем было (24 вместо 18 — меньше просвечивает шум фоновой текстуры), плюс
/// тонкий верхний блик, имитирующий specular-эффект Liquid Glass. Один рецепт
/// для сайдбара/панелей на десктопе и нижней панели на мобильном — не два
/// разных языка на разных платформах.
///
/// **v2 (REDESIGN_V4_PLAN.md §6.1)**: область применения сужена — только для
/// временно всплывающих поверхностей (командная палитра, модалки, floating
/// AI-панель), не для сайдбара/карточек по умолчанию (те переходят на
/// непрозрачные `surface`/`surface2`/`surfaceSunken` + тень). Сам виджет не
/// меняется, меняется правило о том, где его вызывать — миграция существующих
/// мест вызова происходит в последующих этапах (§6.2/§6.3), не здесь.
class ClarifyGlass extends StatelessWidget {
  final Widget child;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? customColor;
  final double blurSigma;
  final bool showHighlight;

  const ClarifyGlass({
    super.key,
    required this.child,
    this.borderRadius,
    this.padding,
    this.margin,
    this.customColor,
    this.blurSigma = 24,
    this.showHighlight = true,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final radius = borderRadius ?? BorderRadius.circular(ClarifyRadius.md);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fillColor = customColor ?? t.surface.withValues(alpha: isDark ? 0.55 : 0.7);

    return Container(
      margin: margin,
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          child: AnimatedContainer(
            duration: ClarifyMotion.completion,
            curve: ClarifyMotion.standard,
            decoration: BoxDecoration(
              color: fillColor,
              borderRadius: radius,
              border: Border.all(color: t.border, width: 1),
            ),
            child: Stack(
              children: [
                Padding(padding: padding ?? EdgeInsets.zero, child: child),
                if (showHighlight)
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: IgnorePointer(
                      child: Container(
                        height: 1,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.white.withValues(alpha: 0),
                              Colors.white.withValues(alpha: isDark ? 0.35 : 0.55),
                              Colors.white.withValues(alpha: 0),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
