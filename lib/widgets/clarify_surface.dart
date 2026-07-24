import 'dart:ui' show SemanticsHitTestBehavior, lerpDouble;
import 'package:flutter/material.dart';
import '../core/last_tap_tracker.dart';
import '../core/theme/design_tokens.dart';

/// Замена [showDialog] с собственным переходом (масштаб + fade по
/// ClarifyMotion) вместо дефолтного Material-fade — см.
/// docs/REDESIGN_V2_PLAN.md §3.2/§5.3. Построено на [RawDialogRoute] —
/// том же примитиве, на котором держится [DialogRoute]/[showDialog], — так
/// что барьер, safe area и поведение с клавиатурой не отличаются, меняется
/// только transitionBuilder. Прямая замена: тот же набор параметров.
///
/// Окно "вылетает" из точки последнего тапа (см. [LastTapTracker]) — единый
/// стиль для всех диалогов приложения, а не только для одной кнопки: точка
/// клика ловится глобально в [LastTapTrackerScope] (main.dart), явно
/// передавать [originOffset] нужно только если реального тапа не было
/// (например, диалог открыт по хоткею). Сознательно НЕ через Hero — попытка
/// сделать этот же эффект Hero'ем между кнопкой и диалогом раньше падала
/// рантайм-ошибкой "A Hero widget cannot be the descendant of another Hero
/// widget", и без живой отладки причину было не подтвердить; этот вариант
/// достигает того же визуального результата обычным Transform, не
/// завязанным на Hero-машинерию сопоставления тегов между роутами —
/// структурно не может упасть так же.
Future<T?> showClarifySurface<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
  Color? barrierColor,
  Offset? originOffset,
}) {
  final effectiveOrigin = originOffset ?? LastTapTracker.position;
  final collapseOnClose = _CollapseFlag();
  return Navigator.of(context, rootNavigator: true).push<T>(
    RawDialogRoute<T>(
      barrierDismissible: barrierDismissible,
      barrierColor: barrierColor ?? Colors.black.withValues(alpha: 0.45),
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      // 180мс (base) хватало для простого fade+scale-от-центра, но для
      // полёта от кнопки (часто в углу/сбоку) до центра экрана — большая
      // дистанция — это читалось как рывок/скачок, а не плавный перелёт.
      // deliberate (420мс) только когда реально летим из точки; обычный
      // fallback-диалог (без известной точки клика) остаётся на прежней длительности.
      transitionDuration: effectiveOrigin == null ? ClarifyMotion.base : ClarifyMotion.deliberate,
      pageBuilder: (context, animation, secondaryAnimation) {
        return Semantics(
          hitTestBehavior: SemanticsHitTestBehavior.opaque,
          child: SafeArea(
            child: ClarifySurfaceTransitionOut(
              onMarkCollapse: () => collapseOnClose.value = true,
              child: Builder(builder: builder),
            ),
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(parent: animation, curve: ClarifyMotion.standard);
        if (collapseOnClose.value) {
          // Переход в другое окно (напр. "Изменить" → редактирование задачи):
          // схлопывается на месте и растворяется, а не летит обратно к точке
          // открытия — иначе взгляд спорил бы между двумя одновременными
          // перелётами (эта модалка назад, новая — с кнопки перехода).
          return FadeTransition(
            opacity: curved,
            child: ScaleTransition(scale: Tween<double>(begin: 0.05, end: 1.0).animate(curved), child: child),
          );
        }
        if (effectiveOrigin == null) {
          return FadeTransition(
            opacity: curved,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.96, end: 1.0).animate(curved),
              child: child,
            ),
          );
        }
        // Непрозрачность нарастает быстрее (первая половина анимации), чем
        // едет/растёт сам диалог — иначе полупрозрачный силуэт долго летит
        // через весь экран, что тоже читается как "криво". К моменту, когда
        // движение/масштаб ещё продолжаются, окно уже полностью видно.
        final opacityCurved = CurvedAnimation(parent: animation, curve: const Interval(0.0, 0.5, curve: Curves.easeOut));
        return AnimatedBuilder(
          animation: curved,
          builder: (context, child) {
            final t = curved.value.clamp(0.0, 1.0);
            final screenCenter = MediaQuery.sizeOf(context).center(Offset.zero);
            final beginOffset = effectiveOrigin - screenCenter;
            final scale = lerpDouble(0.2, 1.0, t)!;
            return Opacity(
              opacity: opacityCurved.value.clamp(0.0, 1.0),
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

class _CollapseFlag {
  bool value = false;
}

/// Помечает следующее закрытие текущего [showClarifySurface] как переход в
/// другое окно, а не обычный dismiss (крестик/клик по фону/удаление) —
/// см. [_CollapseFlag] в [showClarifySurface].
class ClarifySurfaceTransitionOut extends InheritedWidget {
  final VoidCallback onMarkCollapse;

  const ClarifySurfaceTransitionOut({super.key, required this.onMarkCollapse, required super.child});

  static void markCollapseOnClose(BuildContext context) {
    context.findAncestorWidgetOfExactType<ClarifySurfaceTransitionOut>()?.onMarkCollapse();
  }

  @override
  bool updateShouldNotify(covariant ClarifySurfaceTransitionOut oldWidget) => false;
}
