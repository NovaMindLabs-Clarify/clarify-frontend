import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../core/localization.dart';
import '../core/quick_parse.dart';
import '../core/theme/design_tokens.dart';

/// Быстрое добавление задачи одной строкой (C1 из docs/AUDIT_2026-09-04.md).
///
/// Строка разбирается ЛОКАЛЬНО и мгновенно (core/quick_parse.dart), без похода
/// к ИИ: /tasks/parse отвечает секунды, а быстрый ввод, который думает три
/// секунды, быстрым уже не является.
///
/// Ключевое в поведении — распознанное показывается ДО сохранения, отдельными
/// подписями под полем. Любой разбор строки иногда ошибается («купить хлеб в 15
/// магазине»), и единственная честная защита от этого — показать человеку, что
/// именно понято, пока он ещё не нажал Enter. Поэтому подписи не украшение: без
/// них правило «лучше не распознать, чем распознать неверно» пришлось бы
/// доводить до абсурда, а с ними разбор может позволить себе быть полезным.
class ClarifyQuickAdd extends StatefulWidget {
  final String currentLang;
  final double scale;

  /// Тег раздела, если задачу добавляют внутри проекта — подставляется, когда
  /// в строке тега нет.
  final String? defaultTag;

  /// Дата раздела, если он привязан к дню («Мой день») — подставляется, когда
  /// в строке даты нет.
  final DateTime? defaultDate;

  final Future<void> Function(QuickParseResult parsed) onSubmit;

  const ClarifyQuickAdd({
    super.key,
    required this.currentLang,
    required this.scale,
    required this.onSubmit,
    this.defaultTag,
    this.defaultDate,
  });

  @override
  State<ClarifyQuickAdd> createState() => _ClarifyQuickAddState();
}

class _ClarifyQuickAddState extends State<ClarifyQuickAdd> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  QuickParseResult _parsed = const QuickParseResult(title: '');
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    setState(() => _parsed = parseQuickTask(value));
  }

  Future<void> _submit() async {
    final parsed = parseQuickTask(_controller.text);
    if (parsed.title.trim().isEmpty || _saving) return;

    setState(() => _saving = true);
    try {
      await widget.onSubmit(QuickParseResult(
        title: parsed.title,
        // Раздел подставляет своё только там, где человек ничего не сказал.
        date: parsed.date ?? widget.defaultDate,
        time: parsed.time,
        tag: parsed.tag ?? widget.defaultTag,
        priority: parsed.priority,
        tokens: parsed.tokens,
      ));
      if (!mounted) return;
      _controller.clear();
      setState(() => _parsed = const QuickParseResult(title: ''));
      // Фокус остаётся в поле: быстрый ввод — это про «одну за другой».
      _focusNode.requestFocus();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _dateLabel(DateTime date) {
    final today = DateTime.now();
    final dayOnly = DateTime(today.year, today.month, today.day);
    final diff = DateTime(date.year, date.month, date.day).difference(dayOnly).inDays;
    if (diff == 0) return 'сегодня'.tr(widget.currentLang);
    if (diff == 1) return 'завтра'.tr(widget.currentLang);
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final s = widget.scale;

    final DateTime? effectiveDate = _parsed.date ?? widget.defaultDate;
    final String? effectiveTag = _parsed.tag ?? widget.defaultTag;

    final chips = <Widget>[
      if (effectiveDate != null)
        _Chip(icon: LucideIcons.calendar, label: _dateLabel(effectiveDate), color: t.text2, scale: s),
      if (_parsed.time != null)
        _Chip(icon: LucideIcons.clock, label: _parsed.time!, color: t.text2, scale: s),
      if (effectiveTag != null)
        _Chip(icon: LucideIcons.hash, label: effectiveTag, color: t.text2, scale: s),
      if (_parsed.priority != null)
        _Chip(
          icon: LucideIcons.flag,
          label: _priorityLabel(_parsed.priority!),
          color: _priorityColor(_parsed.priority!, t),
          scale: s,
        ),
    ];

    return Padding(
      padding: EdgeInsets.fromLTRB(24, 0, 24, chips.isEmpty ? 12 : 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.plus, size: 16 * s, color: t.text3),
              SizedBox(width: 10 * s),
              Expanded(
                child: Shortcuts(
                  shortcuts: const {
                    SingleActivator(LogicalKeyboardKey.enter): _SubmitIntent(),
                  },
                  child: Actions(
                    actions: {
                      _SubmitIntent: CallbackAction<_SubmitIntent>(
                        onInvoke: (_) {
                          _submit();
                          return null;
                        },
                      ),
                    },
                    child: TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      onChanged: _onChanged,
                      onSubmitted: (_) => _submit(),
                      style: TextStyle(color: t.text, fontSize: 14.5 * s),
                      cursorColor: t.accent,
                      decoration: InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        hintText: 'Новая задача — например: завтра в 15:00 позвонить #работа'
                            .tr(widget.currentLang),
                        hintStyle: TextStyle(color: t.text3, fontSize: 14.5 * s),
                      ),
                    ),
                  ),
                ),
              ),
              if (_saving)
                SizedBox(
                  width: 14 * s,
                  height: 14 * s,
                  child: CircularProgressIndicator(strokeWidth: 2, color: t.text3),
                ),
            ],
          ),
          if (chips.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(left: 26 * s, top: 6 * s),
              child: Wrap(spacing: 8 * s, runSpacing: 4 * s, children: chips),
            ),
          Padding(
            padding: EdgeInsets.only(top: 8 * s),
            child: Divider(height: 1, color: t.border),
          ),
        ],
      ),
    );
  }

  String _priorityLabel(String priority) {
    switch (priority) {
      case 'red':
        return 'срочно'.tr(widget.currentLang);
      case 'orange':
        return 'важно'.tr(widget.currentLang);
      case 'blue':
        return 'обычный'.tr(widget.currentLang);
      default:
        return 'потом'.tr(widget.currentLang);
    }
  }

  Color _priorityColor(String priority, ClarifyTokens t) {
    switch (priority) {
      case 'red':
        return t.danger;
      case 'orange':
        return t.warning;
      case 'blue':
        return t.accent;
      default:
        return t.text3;
    }
  }
}

class _SubmitIntent extends Intent {
  const _SubmitIntent();
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final double scale;

  const _Chip({
    required this.icon,
    required this.label,
    required this.color,
    required this.scale,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12 * scale, color: color),
        SizedBox(width: 4 * scale),
        Text(label, style: TextStyle(fontSize: 12 * scale, color: color, fontWeight: FontWeight.w600)),
      ],
    );
  }
}
