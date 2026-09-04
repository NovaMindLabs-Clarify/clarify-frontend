import 'package:flutter/material.dart';
import '../core/theme/design_tokens.dart';
import 'clarify_press_glow.dart';

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
  final bool loading;
  final bool fullWidth;

  const ClarifyButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.variant = ClarifyButtonVariant.outline,
    this.scale = 1.0,
    this.loading = false,
    this.fullWidth = false,
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

    final style =
        ElevatedButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: fg,
          disabledBackgroundColor: bg,
          disabledForegroundColor: fg.withValues(alpha: 0.4),
          elevation: 0,
          padding: EdgeInsets.symmetric(
            horizontal: 18 * scale,
            vertical: 11 * scale,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(ClarifyRadius.pill),
            side: BorderSide(color: borderColor),
          ),
          textStyle: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14 * scale,
          ),
          // Явный hover/press overlay акцентным цветом — без него Material сам
          // берёт цвет из foregroundColor (t.text: почти чёрный в светлой теме,
          // почти белый в тёмной), и на прозрачном фоне outline-кнопки в светлой
          // теме это давало низкоконтрастную мутную заливку поверх и без того
          // полупрозрачной обводки (t.borderStrong: ~18% альфы) — контур на
          // hover визуально "плыл". Акцентный оттенок с фиксированной альфой
          // одинаково читаем в обеих темах.
        ).copyWith(
          overlayColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed)) {
              return t.accent.withValues(alpha: 0.16);
            }
            if (states.contains(WidgetState.hovered)) {
              return t.accent.withValues(alpha: 0.08);
            }
            if (states.contains(WidgetState.focused)) {
              return t.accent.withValues(alpha: 0.08);
            }
            return Colors.transparent;
          }),
        );
    // ClarifyPressGlow оборачивает кнопку в Stack (alignment: center) —
    // Stack даёт непозиционированным детям loose-констрейнты независимо от
    // своих собственных tight-констрейнтов, поэтому Column(stretch) её не
    // растягивает, как растянул бы голый ElevatedButton. minimumSize с
    // double.infinity — стандартный флаттеровский приём, работает и без tight
    // ширины от родителя.
    final effectiveStyle = fullWidth
        ? style.copyWith(
            minimumSize: WidgetStateProperty.all(const Size(double.infinity, 0)),
          )
        : style;

    // clipBehavior: без него hover/pressed-заливка ElevatedButton иногда не
    // обрезается по скруглению pill-формы и на границе видны острые углы —
    // баг именно в этом, не в цветах/форме самой кнопки.
    final glowColor = variant == ClarifyButtonVariant.danger
        ? t.danger
        : t.accent;
    final effectiveOnPressed = loading ? null : onPressed;
    final spinner = SizedBox(
      width: 16 * scale,
      height: 16 * scale,
      child: CircularProgressIndicator(strokeWidth: 2, color: fg),
    );
    if (icon == null) {
      return ClarifyPressGlow(
        color: glowColor,
        spread: 14 * scale,
        child: ElevatedButton(
          style: effectiveStyle,
          clipBehavior: Clip.antiAlias,
          onPressed: effectiveOnPressed,
          child: loading ? spinner : Text(label),
        ),
      );
    }
    return ClarifyPressGlow(
      color: glowColor,
      spread: 14 * scale,
      child: ElevatedButton.icon(
        style: style,
        clipBehavior: Clip.antiAlias,
        onPressed: effectiveOnPressed,
        icon: loading ? spinner : Icon(icon, size: 18 * scale),
        label: Text(label, overflow: TextOverflow.ellipsis),
      ),
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
    final button = ClarifyPressGlow(
      color: color ?? t.accent,
      spread: 10 * scale,
      child: IconButton(
        icon: Icon(icon, size: 22 * scale, color: color ?? t.text2),
        onPressed: onPressed,
        splashRadius: 20 * scale,
      ),
    );
    if (tooltip == null) return button;
    return Tooltip(message: tooltip!, child: button);
  }
}
