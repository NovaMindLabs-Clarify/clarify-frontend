import 'package:flutter/material.dart';

/// Знак Clarify — сквиркл, разрезанный вертикально, половины разведены по
/// вертикали в разные стороны.
///
/// Нарисован кодом, а не подключён из SVG. Причины:
///   * пакета для SVG в проекте нет вообще, а тянуть зависимость ради двух
///     контуров — плохой обмен;
///   * знак обязан наследовать цвет от родителя (в гайде это `currentColor`),
///     иначе смена акцента пользователем его не перекрасит. У картинки цвет
///     фиксирован, у нарисованного контура — нет;
///   * никакого разбора файла в рантайме и никакого асинхронного появления.
///
/// Геометрия — ровно из `brand/clarify/mark-currentcolor.svg`, система
/// координат 64×64. Менять её нельзя (см. CLARIFY-MARK.md §4): радиус силуэта
/// 12, радиус кромок реза 4, зазор 10, сдвиг половин ±6 — левая вверх, правая
/// вниз.
class ClarifyMark extends StatelessWidget {
  /// Сторона квадрата. Минимум по гайду — 16; ниже зазор схлопывается, и
  /// вместо знака нужно ставить иконку с плашкой.
  final double size;

  /// null — берётся цвет текста родителя, как `currentColor` в вебе.
  final Color? color;

  /// Декоративное употребление — тогда экранный диктор знак не читает.
  final bool decorative;

  const ClarifyMark({
    super.key,
    this.size = 24,
    this.color,
    this.decorative = false,
  });

  @override
  Widget build(BuildContext context) {
    final resolved = color ??
        DefaultTextStyle.of(context).style.color ??
        IconTheme.of(context).color ??
        Theme.of(context).colorScheme.onSurface;

    final painted = SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _ClarifyMarkPainter(resolved)),
    );

    if (decorative) return ExcludeSemantics(child: painted);
    return Semantics(label: 'Clarify', image: true, child: painted);
  }
}

class _ClarifyMarkPainter extends CustomPainter {
  final Color color;

  const _ClarifyMarkPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    // Исходник задан в квадрате 64×64 — масштабируем целиком, чтобы пропорции
    // не могли исказиться по одной оси (это прямо запрещено гайдом).
    final k = size.shortestSide / 64.0;
    canvas.save();
    canvas.scale(k);

    final paint = Paint()
      ..color = color
      ..isAntiAlias = true
      ..style = PaintingStyle.fill;

    // Левая половина: круглая слева (радиус 12), срезанная справа (радиус 4).
    // Сдвиг вверх на 6.
    canvas.drawRRect(
      RRect.fromLTRBAndCorners(
        4, 2.5, 27, 49.5,
        topLeft: const Radius.circular(12),
        bottomLeft: const Radius.circular(12),
        topRight: const Radius.circular(4),
        bottomRight: const Radius.circular(4),
      ),
      paint,
    );

    // Правая половина — зеркально, сдвиг вниз на 6.
    canvas.drawRRect(
      RRect.fromLTRBAndCorners(
        37, 14.5, 60, 61.5,
        topLeft: const Radius.circular(4),
        bottomLeft: const Radius.circular(4),
        topRight: const Radius.circular(12),
        bottomRight: const Radius.circular(12),
      ),
      paint,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(_ClarifyMarkPainter old) => old.color != color;
}
