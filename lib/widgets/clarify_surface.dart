import 'dart:ui' show SemanticsHitTestBehavior;
import 'package:flutter/material.dart';
import '../core/theme/design_tokens.dart';

/// Замена [showDialog] с собственным переходом (масштаб + fade по
/// ClarifyMotion) вместо дефолтного Material-fade — см.
/// docs/REDESIGN_V2_PLAN.md §3.2/§5.3. Построено на [RawDialogRoute] —
/// том же примитиве, на котором держится [DialogRoute]/[showDialog], — так
/// что барьер, safe area и поведение с клавиатурой не отличаются, меняется
/// только transitionBuilder. Прямая замена: тот же набор параметров.
Future<T?> showClarifySurface<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
  Color? barrierColor,
}) {
  return Navigator.of(context, rootNavigator: true).push<T>(
    RawDialogRoute<T>(
      barrierDismissible: barrierDismissible,
      barrierColor: barrierColor ?? Colors.black.withValues(alpha: 0.45),
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      transitionDuration: ClarifyMotion.base,
      pageBuilder: (context, animation, secondaryAnimation) {
        return Semantics(
          hitTestBehavior: SemanticsHitTestBehavior.opaque,
          child: SafeArea(child: Builder(builder: builder)),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(parent: animation, curve: ClarifyMotion.standard);
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.96, end: 1.0).animate(curved),
            child: child,
          ),
        );
      },
    ),
  );
}
