import 'dart:ui' show SemanticsHitTestBehavior;
import 'package:flutter/material.dart';
import '../core/theme/design_tokens.dart';
import 'clarify_bottom_sheet.dart';

/// Замена [showDialog] с собственным переходом (слайд снизу + fade по
/// ClarifyMotion) вместо дефолтного Material-fade — см.
/// docs/REDESIGN_V2_PLAN.md §3.2/§5.3. Построено на [RawDialogRoute] —
/// том же примитиве, на котором держится [DialogRoute]/[showDialog], — так
/// что барьер, safe area и поведение с клавиатурой не отличаются, меняется
/// только transitionBuilder. Прямая замена: тот же набор параметров.
///
/// Окно выезжает снизу вверх — единый стиль для всех диалогов приложения.
/// [originOffset] пока не используется новой анимацией, оставлен в сигнатуре
/// ради обратной совместимости с существующими вызовами.
Future<T?> showClarifySurface<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
  Color? barrierColor,
  Offset? originOffset,
}) {
  final collapseOnClose = _CollapseFlag();
  final reduceMotion = MediaQuery.of(context).disableAnimations;
  return Navigator.of(context, rootNavigator: true).push<T>(
    RawDialogRoute<T>(
      barrierDismissible: barrierDismissible,
      barrierColor: barrierColor ?? Colors.black.withValues(alpha: 0.45),
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      // При "Меньше анимаций" — мгновенно, без слайда.
      transitionDuration: reduceMotion ? Duration.zero : ClarifyMotion.base,
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
          // схлопывается на месте и растворяется, а не выезжает заново снизу —
          // иначе взгляд спорил бы между закрытием этой модалки и выездом новой.
          return FadeTransition(
            opacity: curved,
            child: ScaleTransition(scale: Tween<double>(begin: 0.05, end: 1.0).animate(curved), child: child),
          );
        }
        // Непрозрачность нарастает быстрее (первая половина анимации), чем
        // едет сам диалог — иначе полупрозрачный силуэт долго едет наверх,
        // что читается как "криво". К моменту, когда движение ещё
        // продолжается, окно уже полностью видно.
        final opacityCurved = CurvedAnimation(parent: animation, curve: const Interval(0.0, 0.5, curve: Curves.easeOut));
        return FadeTransition(
          opacity: opacityCurved,
          child: SlideTransition(
            position: Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(curved),
            child: child,
          ),
        );
      },
    ),
  );
}

/// Для карточных диалогов задачи (детали/редактирование/добавление) — на
/// мобильном настоящий bottom sheet вместо центрированной карточки: во всю
/// ширину экрана, от самого низа, почти до верха, скруглены только верхние
/// углы, свайп вниз закрывает — всё это [showClarifyBottomSheet] уже даёт "из
/// коробки" через стоковый showModalBottomSheet, включая drag-to-dismiss. На
/// десктопе — прежний [showClarifySurface] с плавающей карточкой по центру.
/// [builder] должен вернуть "голый" контент без обёртки Center/Material/
/// buildGlassContainer — про это (и про подбор ширины/паддинга) сам решает
/// вызывающий код в зависимости от [isClarifyDialogMobile], сюда попадает уже
/// готовый виджет.
Future<T?> showClarifyResponsiveSurface<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
  Color? barrierColor,
}) {
  if (isClarifyDialogMobile(context)) {
    return showClarifyBottomSheet<T>(context: context, builder: builder);
  }
  return showClarifySurface<T>(context: context, builder: builder, barrierDismissible: barrierDismissible, barrierColor: barrierColor);
}

/// Порог, по которому карточные диалоги задачи решают — bottom sheet
/// (мобильный) или плавающая карточка по центру (десктоп). Тот же
/// [ClarifyBreakpoints.mobile], что и у остальной адаптивной раскладки.
bool isClarifyDialogMobile(BuildContext context) => MediaQuery.sizeOf(context).width < ClarifyBreakpoints.mobile;

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
