import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/theme/design_tokens.dart';

/// Поле ввода без рамки-контейнера — статичная тонкая нижняя линия как
/// базовая подсказка границы, поверх неё при фокусе "дорисовывается" акцентная
/// линия слева направо (тот же приём, что и в анимации зачёркивания задачи —
/// см. ClarifyStrikeText), не мгновенный скачок цвета/рамки. См.
/// REDESIGN_V4_PLAN.md §6.3.
class ClarifyTextField extends StatefulWidget {
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String? hintText;
  final String? labelText;
  final TextStyle? style;
  final TextAlign textAlign;
  final TextCapitalization textCapitalization;
  final TextInputType? keyboardType;
  final bool obscureText;
  final bool autofocus;
  final bool enabled;
  final int? maxLines;
  final int? minLines;
  final int? maxLength;
  final bool showCounter;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool dense;
  final EdgeInsetsGeometry? contentPadding;

  const ClarifyTextField({
    super.key,
    this.controller,
    this.focusNode,
    this.hintText,
    this.labelText,
    this.style,
    this.textAlign = TextAlign.start,
    this.textCapitalization = TextCapitalization.none,
    this.keyboardType,
    this.obscureText = false,
    this.autofocus = false,
    this.enabled = true,
    this.maxLines = 1,
    this.minLines,
    this.maxLength,
    this.showCounter = false,
    this.prefixIcon,
    this.suffixIcon,
    this.inputFormatters,
    this.onChanged,
    this.onSubmitted,
    this.dense = false,
    this.contentPadding,
  });

  @override
  State<ClarifyTextField> createState() => _ClarifyTextFieldState();
}

class _ClarifyTextFieldState extends State<ClarifyTextField> with SingleTickerProviderStateMixin {
  late final AnimationController _line;
  FocusNode? _ownFocusNode;
  FocusNode get _focusNode => widget.focusNode ?? (_ownFocusNode ??= FocusNode());

  @override
  void initState() {
    super.initState();
    _line = AnimationController(vsync: this, duration: ClarifyMotion.base, value: _focusNode.hasFocus ? 1 : 0);
    _focusNode.addListener(_handleFocusChange);
  }

  void _handleFocusChange() {
    final duration = MediaQuery.of(context).disableAnimations ? Duration.zero : ClarifyMotion.base;
    _line.animateTo(_focusNode.hasFocus ? 1 : 0, duration: duration, curve: ClarifyMotion.standard);

    // Поле внутри прокручиваемого контейнера (напр. мобильная форма "Новая
    // задача" в SingleChildScrollView) само по себе НЕ гарантирует, что при
    // появлении клавиатуры сфокусированное поле останется видно — раньше это
    // отдавалось на откуп нативному scroll-into-view браузера, что на мобильном
    // Safari/PWA ненадёжно. Явный ensureVisible работает независимо от
    // платформы. Задержка на кадр — чтобы сработать уже после того, как
    // Scrollable узнает о новых viewInsets от клавиатуры.
    if (_focusNode.hasFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && Scrollable.maybeOf(context) != null) {
          Scrollable.ensureVisible(context, alignment: 0.2, duration: ClarifyMotion.base, curve: ClarifyMotion.standard);
        }
      });
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChange);
    _ownFocusNode?.dispose();
    _line.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final style = widget.style ?? TextStyle(color: t.text, fontSize: 16);

    return Container(
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: t.border))),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          TextField(
            controller: widget.controller,
            focusNode: _focusNode,
            style: style,
            textAlign: widget.textAlign,
            textCapitalization: widget.textCapitalization,
            keyboardType: widget.keyboardType,
            obscureText: widget.obscureText,
            autofocus: widget.autofocus,
            enabled: widget.enabled,
            maxLines: widget.obscureText ? 1 : widget.maxLines,
            minLines: widget.minLines,
            maxLength: widget.maxLength,
            inputFormatters: widget.inputFormatters,
            onChanged: widget.onChanged,
            onSubmitted: widget.onSubmitted,
            decoration: InputDecoration(
              hintText: widget.hintText,
              hintStyle: TextStyle(color: t.text3),
              labelText: widget.labelText,
              labelStyle: TextStyle(color: t.text3),
              floatingLabelStyle: TextStyle(color: t.accent),
              counterText: widget.showCounter ? null : (widget.maxLength != null ? '' : null),
              prefixIcon: widget.prefixIcon,
              suffixIcon: widget.suffixIcon,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              disabledBorder: InputBorder.none,
              isDense: widget.dense,
              contentPadding: widget.contentPadding ??
                  (widget.dense ? const EdgeInsets.symmetric(vertical: 8) : const EdgeInsets.symmetric(vertical: 10)),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: -1,
            child: AnimatedBuilder(
              animation: _line,
              builder: (context, _) => Align(
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: _line.value.clamp(0.0, 1.0),
                  child: Container(height: 2, color: t.accent),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
