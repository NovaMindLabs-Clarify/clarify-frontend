import 'package:flutter/material.dart';
import '../core/theme/design_tokens.dart';

/// Один язык кнопок на весь интерфейс — см. docs/DESIGN_SYSTEM.md §3.
/// Раньше в шапке одновременно уживались стекло/заливка/обводка/голая иконка;
/// теперь только эти четыре варианта, все radius: pill.
enum ClarifyButtonVariant { filled, outline, ghost, danger }

class ClarifyButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final ClarifyButtonVariant variant;
  final double scale;

  const ClarifyButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.variant = ClarifyButtonVariant.outline,
    this.scale = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final Color bg;
    final Color fg;
    final Color borderColor;
    switch (variant) {
      case ClarifyButtonVariant.filled:
        bg = t.accent;
        fg = t.onAccent;
        borderColor = Colors.transparent;
        break;
      case ClarifyButtonVariant.outline:
        bg = Colors.transparent;
        fg = t.text;
        borderColor = t.borderStrong;
        break;
      case ClarifyButtonVariant.ghost:
        bg = Colors.transparent;
        fg = t.text2;
        borderColor = Colors.transparent;
        break;
      case ClarifyButtonVariant.danger:
        bg = Colors.transparent;
        fg = t.danger;
        borderColor = t.danger;
        break;
    }

    final style = ElevatedButton.styleFrom(
      backgroundColor: bg,
      foregroundColor: fg,
      disabledBackgroundColor: bg,
      disabledForegroundColor: fg.withValues(alpha: 0.4),
      elevation: 0,
      padding: EdgeInsets.symmetric(horizontal: 18 * scale, vertical: 11 * scale),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(ClarifyRadius.pill),
        side: BorderSide(color: borderColor),
      ),
      textStyle: TextStyle(fontWeight: FontWeight.w600, fontSize: 14 * scale),
    );

    if (icon == null) {
      return ElevatedButton(style: style, onPressed: onPressed, child: Text(label));
    }
    return ElevatedButton.icon(
      style: style,
      onPressed: onPressed,
      icon: Icon(icon, size: 18 * scale),
      label: Text(label, overflow: TextOverflow.ellipsis),
    );
  }
}

/// Голая иконка без подложки — для второстепенных действий шапки (обновить, тема, пульс команды).
/// [color] — только для семантического переопределения (напр. warning-статус офлайна);
/// по умолчанию нейтральный `text2`, не выдуманный акцент.
class ClarifyIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final Color? color;
  final double scale;

  const ClarifyIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.color,
    this.scale = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final button = IconButton(
      icon: Icon(icon, size: 22 * scale, color: color ?? t.text2),
      onPressed: onPressed,
      splashRadius: 20 * scale,
    );
    if (tooltip == null) return button;
    return Tooltip(message: tooltip!, child: button);
  }
}
