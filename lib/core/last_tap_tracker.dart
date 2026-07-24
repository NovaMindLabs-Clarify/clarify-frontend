import 'package:flutter/widgets.dart';

/// Экранная позиция последнего тапа — источник "точки вылета" для
/// showClarifySurface(), чтобы диалоги по всему приложению открывались из
/// места клика единообразно, без ручной разметки (GlobalKey) под каждую
/// кнопку отдельно (REDESIGN_V3_PLAN.md: "единый стиль анимаций").
class LastTapTracker {
  LastTapTracker._();
  static Offset? position;
}

/// Оборачивает поддерево, обновляя [LastTapTracker.position] на каждом
/// нажатии. HitTestBehavior.translucent — только слушает, не участвует в
/// gesture arena и не мешает обычным тапам/скроллу под собой.
class LastTapTrackerScope extends StatelessWidget {
  final Widget child;

  const LastTapTrackerScope({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (event) => LastTapTracker.position = event.position,
      child: child,
    );
  }
}
