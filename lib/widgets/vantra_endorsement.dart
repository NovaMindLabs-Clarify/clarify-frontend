import 'package:flutter/material.dart';

import '../core/theme/design_tokens.dart';
import 'clarify_pressable.dart';

/// Знак VANTRA — рамка из четырёх уголков, у которой правый верхний смещён.
///
/// Как и знак Clarify, нарисован кодом: контуров четыре, они прямоугольные,
/// зависимость ради них не нужна. Геометрия ровно из
/// `brand/vantra/mark-dark.svg`, система координат 111×111.
///
/// Гайд запрещает зеркалить и поворачивать смещённый угол — он всегда правый
/// верхний, — поэтому масштаб только пропорциональный.
class VantraMark extends StatelessWidget {
  final double size;
  final Color color;

  const VantraMark({super.key, required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(painter: _VantraMarkPainter(color)),
      ),
    );
  }
}

class _VantraMarkPainter extends CustomPainter {
  final Color color;

  const _VantraMarkPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.shortestSide / 111.0;
    canvas.save();
    canvas.scale(k);

    final paint = Paint()
      ..color = color
      ..isAntiAlias = true
      ..style = PaintingStyle.fill;

    // Четыре уголка. Правый верхний сдвинут вверх — это и есть примета знака,
    // менять её нельзя.
    void corner(List<Offset> points) {
      final path = Path()..moveTo(points.first.dx, points.first.dy);
      for (final p in points.skip(1)) {
        path.lineTo(p.dx, p.dy);
      }
      path.close();
      canvas.drawPath(path, paint);
    }

    corner(const [Offset(0, 43), Offset(0, 11), Offset(32, 11), Offset(32, 22), Offset(11, 22), Offset(11, 43)]);
    corner(const [Offset(111, 32), Offset(111, 0), Offset(79, 0), Offset(79, 11), Offset(100, 11), Offset(100, 32)]);
    corner(const [Offset(0, 79), Offset(0, 111), Offset(32, 111), Offset(32, 100), Offset(11, 100), Offset(11, 79)]);
    corner(const [Offset(100, 79), Offset(100, 111), Offset(68, 111), Offset(68, 100), Offset(89, 100), Offset(89, 79)]);

    canvas.restore();
  }

  @override
  bool shouldRepaint(_VantraMarkPainter old) => old.color != color;
}

/// Строка «by VANTRA» — единственное место в приложении, где показывается
/// бренд студии (BRAND.md §4: внутри интерфейса Clarify бренда Vantra нет
/// вообще, кроме экрана «О приложении»).
///
/// Цвет приглушённый и намеренно НЕ акцентный: на территории продукта бренд
/// всегда тише продукта.
class VantraEndorsement extends StatelessWidget {
  final double scale;
  final VoidCallback? onTap;

  const VantraEndorsement({super.key, this.scale = 1.0, this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final muted = t.text3;

    final row = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'by',
          style: TextStyle(fontSize: 13 * scale, color: muted),
        ),
        SizedBox(width: 8 * scale),
        VantraMark(size: 13 * scale, color: muted),
        SizedBox(width: 7 * scale),
        Text(
          'VANTRA',
          style: TextStyle(
            fontSize: 13 * scale,
            color: muted,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.6 * scale,
          ),
        ),
      ],
    );

    if (onTap == null) return Semantics(label: 'by VANTRA', child: row);
    return Semantics(
      label: 'by VANTRA',
      button: true,
      child: ClarifyPressable(onTap: onTap!, child: row),
    );
  }
}
