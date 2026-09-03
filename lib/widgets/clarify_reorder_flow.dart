import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import '../core/theme/design_tokens.dart';

/// Показывает смену ПОРЯДКА строк списка как одно связное движение, а не как
/// мгновенную перерисовку (фидбек 2026-09-03).
///
/// Как это выглядит: уезжающая строка схлопывается по высоте на своём старом
/// месте — соседи при этом плавно поднимаются, потому что это настоящая
/// анимация раскладки, а не сдвиг картинки поверх неё, — и следом
/// раскрывается на новом месте.
///
/// Почему не «строка едет по экрану на новое место»: первая версия делала
/// именно так (запоминала прежнее положение и анимировала смещение). Она
/// разваливалась о реальность списка задач — он перестраивается несколько раз
/// на один клик (оптимистичное обновление, ответ сервера, realtime-фетч), и
/// каждое перестроение превращалось в новый заезд поверх незакончившегося
/// предыдущего. Здесь анимация привязана не к кадрам, а к самому факту
/// перестановки: лишние перестроения с тем же порядком её не трогают вовсе.
///
/// Вторая причина: место назначения у выполненной задачи — низ списка, часто
/// за пределами экрана. Ехать туда «мимо» десятка чужих карточек долго и
/// бессмысленно, а схлопывание на месте читается одинаково хорошо и когда
/// цель видна, и когда нет.
class ClarifyReorderFlow extends StatefulWidget {
  /// Каждый элемент ОБЯЗАН нести key, привязанный к идентичности данных (id
  /// задачи), а не к позиции: по нему и определяется, что именно переехало.
  final List<Widget> children;

  const ClarifyReorderFlow({super.key, required this.children});

  @override
  State<ClarifyReorderFlow> createState() => _ClarifyReorderFlowState();
}

class _ClarifyReorderFlowState extends State<ClarifyReorderFlow>
    with TickerProviderStateMixin {
  /// Порядок, который сейчас на экране. Отстаёт от widget.children ровно на
  /// время схлопывания уезжающей строки.
  late List<Key> _renderOrder;

  /// Порядок, в который мы едем прямо сейчас. Нужен именно как поле, а не как
  /// локальная переменная: пока идёт анимация, родитель успевает перестроить
  /// список несколько раз (ответ сервера, realtime-фетч, обычный setState
  /// экрана), и каждый такой rebuild приходит сюда с тем же самым новым
  /// порядком. Без сравнения с _pendingOrder это выглядело для нас как
  /// «порядок опять поменялся» — анимация обрывалась и порядок принимался
  /// мгновенно. Со стороны: строка резко прыгала на новое место, а соседи так
  /// же резко смыкались.
  List<Key>? _pendingOrder;

  Key? _leavingKey;
  Key? _enteringKey;

  late final AnimationController _leave = AnimationController(
    vsync: this,
    duration: ClarifyMotion.slow,
  );
  late final AnimationController _enter = AnimationController(
    vsync: this,
    duration: ClarifyMotion.slow,
    value: 1,
  );

  @override
  void initState() {
    super.initState();
    _renderOrder = _keysOf(widget.children);
    _leave.value = 1; // 1 — строка на своём месте в полную высоту
  }

  @override
  void dispose() {
    _leave.dispose();
    _enter.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(ClarifyReorderFlow oldWidget) {
    super.didUpdateWidget(oldWidget);

    final nextOrder = _keysOf(widget.children);
    if (listEquals(nextOrder, _renderOrder)) {
      // Перестановку успели отменить, пока строка схлопывалась (например,
      // задачу тут же сняли с отметки) — ехать больше некуда, возвращаем
      // строку на место.
      if (_pendingOrder != null) _adopt(nextOrder);
      return;
    }

    // Тот же самый порядок, в который мы уже едем: это просто очередная
    // перерисовка родителя (ответ сервера, realtime-фетч, любой setState
    // экрана), а не новая перестановка. Анимацию не трогаем — содержимое
    // строк при этом всё равно обновится, оно берётся из свежих детей.
    if (listEquals(nextOrder, _pendingOrder)) return;

    // Список пополнился или похудел — это не перестановка. Появление новой
    // строки анимирует ClarifyCascadeItem, удаление — ClarifyCollapsingTaskRow
    // на стороне карточки; лезть сюда со своей анимацией не нужно.
    final sameSet = nextOrder.length == _renderOrder.length &&
        nextOrder.toSet().containsAll(_renderOrder);
    if (!sameSet) {
      _adopt(nextOrder);
      return;
    }

    // Уже что-то анимируем — не наслаиваем второе движение поверх первого,
    // просто принимаем последний известный порядок.
    if (_leave.isAnimating || _enter.isAnimating) {
      _adopt(nextOrder);
      return;
    }

    final moved = _singleMovedKey(_renderOrder, nextOrder);
    if (moved == null || MediaQuery.of(context).disableAnimations) {
      _adopt(nextOrder);
      return;
    }

    _startLeave(moved, nextOrder);
  }

  void _adopt(List<Key> order) {
    setState(() {
      _renderOrder = order;
      _pendingOrder = null;
      _leavingKey = null;
      _enteringKey = null;
      _leave.value = 1;
      _enter.value = 1;
    });
  }

  void _startLeave(Key moved, List<Key> nextOrder) {
    setState(() {
      _pendingOrder = nextOrder;
      _leavingKey = moved;
      _enteringKey = null;
    });
    _leave.value = 1;
    _leave.reverse().whenComplete(() {
      if (!mounted) return;
      setState(() {
        _renderOrder = nextOrder;
        _leavingKey = null;
        _enteringKey = moved;
        _leave.value = 1;
      });
      _enter.forward(from: 0).whenComplete(() {
        if (!mounted) return;
        setState(() {
          _enteringKey = null;
          _pendingOrder = null;
        });
      });
    });
  }

  List<Key> _keysOf(List<Widget> children) => [
        for (final child in children) child.key ?? UniqueKey(),
      ];

  /// Ключ единственной переехавшей строки — или null, если перестановка
  /// сложнее (например, сменилась сортировка целиком): анимировать «переезд»
  /// там нечего, порядок принимается сразу.
  Key? _singleMovedKey(List<Key> from, List<Key> to) {
    for (final key in from) {
      if (from.indexOf(key) == to.indexOf(key)) continue;
      final withoutFrom = [...from]..remove(key);
      final withoutTo = [...to]..remove(key);
      if (listEquals(withoutFrom, withoutTo)) return key;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final byKey = {
      for (final child in widget.children) child.key: child,
    };

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final key in _renderOrder)
          if (byKey[key] case final child?)
            KeyedSubtree(key: key, child: _wrap(key, child)),
      ],
    );
  }

  Widget _wrap(Key key, Widget child) {
    if (key == _leavingKey) return _collapsing(_leave, child);
    if (key == _enteringKey) return _collapsing(_enter, child);
    return child;
  }

  /// Схлопывание/раскрытие по высоте с параллельным затуханием — тот же приём,
  /// что у ClarifyCollapsingTaskRow при удалении задачи, чтобы уход строки из
  /// списка везде выглядел одинаково.
  Widget _collapsing(Animation<double> animation, Widget child) {
    final curved = CurvedAnimation(parent: animation, curve: ClarifyMotion.standard);
    return SizeTransition(
      sizeFactor: curved,
      // Схлопывание прижато к верху строки: низ уезжает вверх, и соседи снизу
      // поднимаются одним движением. По центру строка складывалась бы внутрь
      // себя, и подъём соседей читался бы как отдельный рывок.
      alignment: Alignment.topCenter,
      child: FadeTransition(opacity: curved, child: child),
    );
  }
}
