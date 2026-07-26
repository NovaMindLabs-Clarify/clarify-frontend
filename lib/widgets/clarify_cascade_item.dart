import 'dart:async';
import 'package:flutter/material.dart';
import '../core/theme/design_tokens.dart';

/// Каскадный вход элемента списка на холодном заходе на экран
/// (REDESIGN_V4_PLAN.md §6.7) — задержка растёт с [index], только для первых
/// [_cascadeCount] позиций, дальше элементы появляются сразу без задержки
/// (иначе прокрутка длинного списка вниз ждала бы своей очереди в каскаде).
/// Однократность на "холодный заход" обеспечивается тем, что задержанный
/// анимации живут в [initState], который не перевызывается при rebuild того
/// же элемента — при условии, что вызывающая сторона передаёт `key`,
/// привязанный к идентичности данных (id задачи), а не к позиции в списке.
class ClarifyCascadeItem extends StatefulWidget {
  final int index;
  final Widget child;

  const ClarifyCascadeItem({super.key, required this.index, required this.child});

  static const int cascadeCount = 6;
  static const Duration stagger = Duration(milliseconds: 45);

  @override
  State<ClarifyCascadeItem> createState() => _ClarifyCascadeItemState();
}

class _ClarifyCascadeItemState extends State<ClarifyCascadeItem> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: ClarifyMotion.deliberate);
  late final Animation<double> _value = CurvedAnimation(parent: _controller, curve: ClarifyMotion.standard);
  bool _started = false;
  Timer? _delayTimer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    if (reduceMotion || widget.index >= ClarifyCascadeItem.cascadeCount) {
      _controller.value = 1;
      return;
    }
    _delayTimer = Timer(ClarifyCascadeItem.stagger * widget.index, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _delayTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _value,
      builder: (context, child) => Opacity(
        opacity: _value.value,
        child: Transform.translate(offset: Offset(0, (1 - _value.value) * 12), child: child),
      ),
      child: widget.child,
    );
  }
}
