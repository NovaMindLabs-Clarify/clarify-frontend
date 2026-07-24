import 'package:flutter/material.dart';
import '../core/theme/design_tokens.dart';

/// Обёртка вокруг строки задачи: схлопывание высоты + fade перед реальным
/// удалением из данных — вместо резкого исчезновения строки из списка. Тот
/// же приём, что использует стандартный remove-билдер AnimatedList во
/// Flutter (SizeTransition + FadeTransition на одной анимации).
class ClarifyCollapsingTaskRow extends StatefulWidget {
  final Widget child;

  const ClarifyCollapsingTaskRow({super.key, required this.child});

  @override
  State<ClarifyCollapsingTaskRow> createState() =>
      _ClarifyCollapsingTaskRowState();

  /// Запускает схлопывание ближайшей обёртки-предка и вызывает [onCollapsed]
  /// по завершении анимации — вызывать вместо прямого удаления, чтобы задача
  /// убиралась из данных только после того, как строка исчезла с экрана.
  static void collapseThenRun(BuildContext context, VoidCallback onCollapsed) {
    final state = context
        .findAncestorStateOfType<_ClarifyCollapsingTaskRowState>();
    if (state == null) {
      onCollapsed();
      return;
    }
    state._collapse(onCollapsed);
  }
}

class _ClarifyCollapsingTaskRowState extends State<ClarifyCollapsingTaskRow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: ClarifyMotion.base,
  );
  late final Animation<double> _sizeAndOpacity =
      Tween<double>(begin: 1.0, end: 0.0).animate(
        CurvedAnimation(parent: _controller, curve: ClarifyMotion.standard),
      );

  Future<void> _collapse(VoidCallback onCollapsed) async {
    if (MediaQuery.of(context).disableAnimations) {
      onCollapsed();
      return;
    }
    await _controller.forward();
    if (mounted) onCollapsed();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizeTransition(
      sizeFactor: _sizeAndOpacity,
      child: FadeTransition(opacity: _sizeAndOpacity, child: widget.child),
    );
  }
}
