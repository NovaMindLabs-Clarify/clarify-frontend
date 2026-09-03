import 'package:flutter/material.dart';
import '../core/theme/design_tokens.dart';

/// Плавный переезд строк, когда меняется ПОРЯДОК уже существующих элементов
/// списка (фидбек 2026-09-03: отмеченная выполненной задача мгновенно
/// оказывалась внизу, а соседи так же мгновенно смыкались — движение читалось
/// как рывок, а не как перестановка).
///
/// Приём — FLIP: элемент помнит, где он был в прошлом кадре; после
/// перестроения он уже стоит на новом месте, и мы рисуем его СМЕЩЁННЫМ назад,
/// в старую точку, а оттуда анимируем смещение к нулю. Поэтому работает при
/// разной высоте строк — в отличие от расчёта "индекс × высота элемента",
/// который у карточек задач (бейджи, заметка, чек-лист — всё меняет высоту)
/// был бы неверным.
///
/// Смещение рисуется трансформацией, на раскладку оно не влияет: соседи
/// занимают освободившееся место сразу и едут своей такой же анимацией,
/// поэтому "поднимаются наверх" они синхронно с тем, как уезжает вниз
/// отмеченная задача.
class ClarifyReorderFlow extends StatefulWidget {
  /// Каждый элемент ОБЯЗАН нести key, привязанный к идентичности данных (id
  /// задачи), а не к позиции: по нему Flutter переиспользует состояние
  /// элемента при перестановке — без этого "прежнее положение" помнил бы не
  /// тот элемент, и вместо переезда получилась бы дрожь всего списка.
  final List<Widget> children;

  const ClarifyReorderFlow({super.key, required this.children});

  @override
  State<ClarifyReorderFlow> createState() => _ClarifyReorderFlowState();
}

class _ClarifyReorderFlowState extends State<ClarifyReorderFlow> {
  final GlobalKey _contentKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    return _FlowScope(
      contentKey: _contentKey,
      child: Column(
        key: _contentKey,
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final child in widget.children)
            _FlipItem(key: child.key ?? UniqueKey(), child: child),
        ],
      ),
    );
  }
}

/// Даёт элементам общую точку отсчёта — сам контейнер списка. Мерить
/// положение в глобальных координатах нельзя: при прокрутке они меняются у
/// всех элементов сразу, и каждый скролл выглядел бы как перестановка.
class _FlowScope extends InheritedWidget {
  final GlobalKey contentKey;

  const _FlowScope({required this.contentKey, required super.child});

  static _FlowScope? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_FlowScope>();

  @override
  bool updateShouldNotify(_FlowScope oldWidget) => oldWidget.contentKey != contentKey;
}

class _FlipItem extends StatefulWidget {
  final Widget child;

  const _FlipItem({required Key key, required this.child}) : super(key: key);

  @override
  State<_FlipItem> createState() => _FlipItemState();
}

class _FlipItemState extends State<_FlipItem> with SingleTickerProviderStateMixin {
  /// Переезд дальше этого расстояния не анимируется: смысл анимации — показать
  /// связь между "было" и "стало", а строка, ползущая через пол-экрана мимо
  /// десятка чужих карточек, эту связь наоборот теряет (и надолго перекрывает
  /// соседей). Такие случаи отрабатывают как раньше — сменой позиции сразу.
  static const double _maxTravel = 1200;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: ClarifyMotion.deliberate,
  );
  late final Animation<double> _progress = CurvedAnimation(
    parent: _controller,
    curve: ClarifyMotion.standard,
  );

  double? _lastOffset;
  double _travelFrom = 0;

  @override
  void initState() {
    super.initState();
    _controller.value = 1; // покоящееся состояние — смещение ноль
    WidgetsBinding.instance.addPostFrameCallback(_measure);
  }

  @override
  void didUpdateWidget(_FlipItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback(_measure);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _measure(Duration _) {
    if (!mounted) return;
    final box = context.findRenderObject() as RenderBox?;
    final content = _FlowScope.of(context)?.contentKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize || content == null || !content.attached) return;

    final offset = box.localToGlobal(Offset.zero, ancestor: content).dy;
    final previous = _lastOffset;
    _lastOffset = offset;

    // Первое измерение (элемент только появился) — ехать неоткуда: вход
    // элемента в список анимирует ClarifyCascadeItem, это не наша забота.
    if (previous == null) return;

    final travel = previous - offset;
    if (travel.abs() < 1 || travel.abs() > _maxTravel) return;
    if (MediaQuery.of(context).disableAnimations) return;

    setState(() => _travelFrom = travel);
    _controller.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _progress,
      builder: (context, child) => Transform.translate(
        offset: Offset(0, _travelFrom * (1 - _progress.value)),
        child: child,
      ),
      child: widget.child,
    );
  }
}
