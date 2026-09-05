import 'dart:math';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../core/theme/design_tokens.dart';

/// Набор акцентных монохромных мини-иллюстраций для пустых состояний,
/// онбординга и достижений (REDESIGN_V4_PLAN.md §6.8) — поверх Lucide как
/// рабочего набора иконок, не замена ему. Осознанное решение вместо внешних
/// SVG (unDraw/Storyset): подбор конкретных файлов требует ручной проверки
/// лицензии, недоступной в безнадзорном прогоне — вместо этого асимметричный
/// "блоб"-фон рисуется процедурно (детерминированно по [ClarifyIllustrationType],
/// без анимации/дрожания между перерисовками) вокруg существующего Lucide-глифа.
enum ClarifyIllustrationType {
  aiSpark,
  teamOrbit,
  bellPulse,
  sunHorizon,
  checklistFold,
  inboxEmpty,
  folderGlow,
  trophyShine,
  trashEmpty,
}

class ClarifyIllustration extends StatelessWidget {
  final ClarifyIllustrationType type;
  final double size;
  final Color? color;

  const ClarifyIllustration({super.key, required this.type, this.size = 96, this.color});

  static const Map<ClarifyIllustrationType, IconData> _glyphs = {
    ClarifyIllustrationType.aiSpark: LucideIcons.sparkles,
    ClarifyIllustrationType.teamOrbit: LucideIcons.usersRound,
    ClarifyIllustrationType.bellPulse: LucideIcons.bellRing,
    ClarifyIllustrationType.sunHorizon: LucideIcons.sun,
    ClarifyIllustrationType.checklistFold: LucideIcons.listChecks,
    ClarifyIllustrationType.inboxEmpty: LucideIcons.inbox,
    ClarifyIllustrationType.folderGlow: LucideIcons.folderKanban,
    ClarifyIllustrationType.trophyShine: LucideIcons.award,
    // Своя иллюстрация, а не inboxEmbty: пустая корзина показывала тот же
    // лоток, что и «Входящие», и два разных раздела выглядели одинаково
    // (живой фидбек 05.09.2026).
    ClarifyIllustrationType.trashEmpty: LucideIcons.trash2,
  };

  @override
  Widget build(BuildContext context) {
    final accent = color ?? context.tokens.accent;
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _BlobPainter(seed: type.index, color: accent),
        child: Center(child: Icon(_glyphs[type], size: size * 0.4, color: accent)),
      ),
    );
  }
}

/// Асимметричный "блоб"-фон — та же логика анти-дефолтного силуэта (§5), что
/// уже применяется к диалогам/панелям, распространённая на иллюстрации.
/// [seed] фиксирует форму навсегда для конкретного типа иллюстрации — форма
/// не должна "прыгать" между перерисовками одного и того же виджета.
class _BlobPainter extends CustomPainter {
  final int seed;
  final Color color;

  _BlobPainter({required this.seed, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final baseRadius = size.width / 2;
    final random = Random(seed);

    const pointCount = 9;
    final pts = <Offset>[
      for (var i = 0; i < pointCount; i++)
        center + Offset.fromDirection((i / pointCount) * 2 * pi, baseRadius * (0.8 + random.nextDouble() * 0.2)),
    ];

    final path = Path()..moveTo((pts.first.dx + pts.last.dx) / 2, (pts.first.dy + pts.last.dy) / 2);
    for (var i = 0; i < pts.length; i++) {
      final next = pts[(i + 1) % pts.length];
      final mid = Offset((pts[i].dx + next.dx) / 2, (pts[i].dy + next.dy) / 2);
      path.quadraticBezierTo(pts[i].dx, pts[i].dy, mid.dx, mid.dy);
    }
    path.close();
    canvas.drawPath(path, Paint()..color = color.withValues(alpha: 0.12));

    final dotPaint = Paint()..color = color.withValues(alpha: 0.35);
    for (var i = 0; i < 3; i++) {
      final angle = random.nextDouble() * 2 * pi;
      final dist = baseRadius * (0.7 + random.nextDouble() * 0.15);
      canvas.drawCircle(center + Offset.fromDirection(angle, dist), size.width * (0.035 + i * 0.012), dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _BlobPainter oldDelegate) => oldDelegate.color != color || oldDelegate.seed != seed;
}
