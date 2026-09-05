import 'package:flutter/material.dart';

import '../core/theme/design_tokens.dart';

/// Подложка строки в прокручиваемом списке — вместо стекла.
///
/// Строки друзей и переписок были обёрнуты в ClarifyGlass, то есть в
/// `BackdropFilter`. Не экран целиком — КАЖДАЯ СТРОКА отдельно. Размытие
/// требует прочитать то, что под ним, и отрисовать в отдельный слой, и делает
/// это заново на каждом кадре прокрутки: сколько строк на экране, столько
/// проходов. Это самая дорогая операция из всех, что есть в интерфейсе, и на
/// iOS Safari в PWA особенно.
///
/// Показательно, что из нижней панели навигации размытие уже убрали ровно по
/// этой причине (mobile_planner_shell.dart) — вывод сделали, но только для
/// одной панели, а списки остались.
///
/// Визуально разница почти незаметна: полупрозрачная заливка поверх фона
/// приложения читается так же, а стоит в разы дешевле. Стекло остаётся там,
/// где оно уместно и где его один слой на экран: панели и сайдбар.
class ClarifyListCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry? padding;

  const ClarifyListCard({
    super.key,
    required this.child,
    this.margin,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(ClarifyRadius.md),
        border: Border.all(color: t.border),
      ),
      child: child,
    );
  }
}
