import 'dart:ui' show SemanticsHitTestBehavior, lerpDouble;
import 'package:flutter/material.dart';
import '../core/theme/design_tokens.dart';

/// Замена [showDialog] с собственным переходом (масштаб + fade по
/// ClarifyMotion) вместо дефолтного Material-fade — см.
/// docs/REDESIGN_V2_PLAN.md §3.2/§5.3. Построено на [RawDialogRoute] —
/// том же примитиве, на котором держится [DialogRoute]/[showDialog], — так
/// что барьер, safe area и поведение с клавиатурой не отличаются, меняется
/// только transitionBuilder. Прямая замена: тот же набор параметров.
///
/// [originOffset] — если задан (точка на экране, откуда открывают, например
/// центр FAB), окно "вылетает" из неё: масштаб+смещение вместо простого
/// fade+scale от центра. Сознательно НЕ через Hero — попытка сделать этот же
/// эффект Hero'ем между FAB и диалогом раньше падала рантайм-ошибкой
/// "A Hero widget cannot be the descendant of another Hero widget", и без
/// живой отладки причину было не подтвердить; этот вариант достигает того же
/// визуального результата обычным Transform, не завязанным на Hero-машинерию
/// сопоставления тегов между роутами — структурно не может упасть так же.
Future<T?> showClarifySurface<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
  Color? barrierColor,
  Offset? originOffset,
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
        if (originOffset == null) {
          return FadeTransition(
            opacity: curved,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.96, end: 1.0).animate(curved),
              child: child,
            ),
          );
        }
        return AnimatedBuilder(
          animation: curved,
          builder: (context, child) {
            final t = curved.value.clamp(0.0, 1.0);
            final screenCenter = MediaQuery.sizeOf(context).center(Offset.zero);
            final beginOffset = originOffset - screenCenter;
            final scale = lerpDouble(0.15, 1.0, t)!;
            return Opacity(
              opacity: t,
              child: Transform.translate(
                offset: beginOffset * (1 - t),
                child: Transform.scale(scale: scale, child: child),
              ),
            );
          },
          child: child,
        );
      },
    ),
  );
}
