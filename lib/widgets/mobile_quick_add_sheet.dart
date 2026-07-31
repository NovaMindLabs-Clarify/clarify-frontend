import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../core/config.dart';
import '../core/tags.dart';
import '../core/priority.dart';
import 'clarify_bottom_sheet.dart';
import 'clarify_button.dart';
import 'clarify_date_time_picker.dart';
import 'clarify_day_load_warning.dart';
import 'clarify_duration_chips.dart';
import 'clarify_priority_lever.dart';
import 'clarify_text_field.dart';
import '../core/localization.dart';
import '../core/theme/design_tokens.dart';

/// Мобильная версия формы быстрого добавления задачи — упрощённый набор
/// полей (заголовок, приоритет, дата/время) вместо полного десктопного
/// диалога (теги, подзадачи, повтор, исполнитель), перенос которого как есть
/// и делал мобильную версию похожей на «сжатый десктоп» (REDESIGN_V2_PLAN.md
/// §3.7).
Future<void> showMobileQuickAddSheet({
  required BuildContext context,
  required String currentLang,
  required List<Map<String, dynamic>> tasks,
  required Future<int?> Function(Map<String, dynamic> taskData)
  createTaskManually,
  required void Function(String dateStr) checkBurnoutWarning,
  required Color Function(String? priority) getPriorityColor,
  required String Function(DateTime date) formatDate,
  required VoidCallback onOpenAi,
  DateTime? preselectedDate,
}) {
  return showClarifyBottomSheet<void>(
    context: context,
    builder: (sheetContext) => _MobileQuickAddForm(
      currentLang: currentLang,
      tasks: tasks,
      createTaskManually: createTaskManually,
      checkBurnoutWarning: checkBurnoutWarning,
      getPriorityColor: getPriorityColor,
      formatDate: formatDate,
      onOpenAi: onOpenAi,
      preselectedDate: preselectedDate,
    ),
  );
}

class _MobileQuickAddForm extends StatefulWidget {
  final String currentLang;
  final List<Map<String, dynamic>> tasks;
  final Future<int?> Function(Map<String, dynamic> taskData) createTaskManually;
  final void Function(String dateStr) checkBurnoutWarning;
  final Color Function(String? priority) getPriorityColor;
  final String Function(DateTime date) formatDate;
  final VoidCallback onOpenAi;
  final DateTime? preselectedDate;

  const _MobileQuickAddForm({
    required this.currentLang,
    required this.tasks,
    required this.createTaskManually,
    required this.checkBurnoutWarning,
    required this.getPriorityColor,
    required this.formatDate,
    required this.onOpenAi,
    this.preselectedDate,
  });

  @override
  State<_MobileQuickAddForm> createState() => _MobileQuickAddFormState();
}

class _MobileQuickAddFormState extends State<_MobileQuickAddForm> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  final TextEditingController _tagsController = TextEditingController();
  final TextEditingController _subtaskController = TextEditingController();
  String _priority = 'none';
  String _recurrence = 'none';
  int _recurrenceInterval = 2;
  DateTime? _date;
  TimeOfDay? _time;
  int? _duration;
  bool _isSaving = false;
  final List<String> _subtasks = [];

  @override
  void initState() {
    super.initState();
    _date = widget.preselectedDate ?? DateTime.now();
  }

  List<String> get _tagSuggestions {
    final segments = _tagsController.text
        .split(',')
        .map((e) => e.trim())
        .toList();
    final fragment = segments.isEmpty ? '' : segments.last;
    if (fragment.isEmpty) return const [];
    final existing = segments.take(segments.length - 1).toSet();
    final knownTags = collectAllTags(widget.tasks);
    return knownTags
        .where(
          (tag) =>
              tag.toLowerCase().contains(fragment.toLowerCase()) &&
              tag.toLowerCase() != fragment.toLowerCase() &&
              !existing.contains(tag),
        )
        .take(5)
        .toList();
  }

  void _applyTagSuggestion(String tag) {
    final segments = _tagsController.text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (segments.isNotEmpty) segments.removeLast();
    segments.add(tag);
    setState(() {
      _tagsController.text = '${segments.join(', ')}, ';
      _tagsController.selection = TextSelection.collapsed(
        offset: _tagsController.text.length,
      );
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _noteController.dispose();
    _tagsController.dispose();
    _subtaskController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    if (title.isEmpty || _isSaving) return;
    setState(() => _isSaving = true);

    final date = _date;
    final newTaskId = await widget.createTaskManually({
      "title": title,
      "due_date": date != null ? widget.formatDate(date) : null,
      "due_time": _time != null
          ? "${_time!.hour.toString().padLeft(2, '0')}:${_time!.minute.toString().padLeft(2, '0')}"
          : null,
      "duration_minutes": _time != null ? _duration : null,
      "priority": _priority,
      "note": _noteController.text.trim().isNotEmpty
          ? _noteController.text.trim()
          : null,
      "tags": _tagsController.text.trim().isNotEmpty
          ? _tagsController.text.trim()
          : null,
      "recurrence": _recurrence == 'none' ? null : _recurrence,
      "recurrence_interval": _recurrence == 'custom'
          ? _recurrenceInterval
          : null,
      "is_completed": false,
      "parent_id": null,
    });

    if (newTaskId != null && _subtasks.isNotEmpty) {
      for (final subTitle in _subtasks) {
        await widget.createTaskManually({
          "title": subTitle,
          "parent_id": newTaskId,
          "is_completed": false,
        });
      }
    }

    if (mounted) Navigator.pop(context);
    if (date != null) widget.checkBurnoutWarning(widget.formatDate(date));
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    // SingleChildScrollView — раньше был голый Column без прокрутки: когда
    // клавиатура открывалась на нижних полях (Теги/Заметка/Чек-лист), их
    // просто нечем было прокрутить наверх, клавиатура перекрывала поле ввода
    // целиком. viewInsets.bottom здесь НЕ добавляется намеренно — сам
    // showModalBottomSheet уже сдвигает весь лист под клавиатуру (см.
    // clarify_bottom_sheet.dart doc-комментарий про завышенный viewInsets на
    // мобильном Safari) — повторное добавление того же отступа здесь удвоило
    // бы сдвиг. Прокрутка нужна для доступа к полям, а не для компенсации
    // высоты клавиатуры второй раз.
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        20,
        4,
        20,
        MediaQuery.of(context).padding.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Новая задача'.tr(widget.currentLang),
                  style: TextStyle(
                    fontFamily: 'Golos Text',
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: t.text,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'AI Ассистент'.tr(widget.currentLang),
                style: IconButton.styleFrom(
                  backgroundColor: t.accentSoft,
                  padding: const EdgeInsets.all(10),
                ),
                icon: Icon(LucideIcons.sparkles, color: t.accent, size: 20),
                onPressed: () {
                  Navigator.pop(context);
                  widget.onOpenAi();
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClarifyTextField(
            controller: _titleController,
            autofocus: true,
            style: TextStyle(color: t.text),
            hintText: 'Заголовок'.tr(widget.currentLang),
            onSubmitted: (_) => _save(),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text(
                'Приоритет: '.tr(widget.currentLang),
                style: TextStyle(color: t.text3, fontSize: 14),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ClarifyPriorityLever(
                  value: _priority,
                  onChanged: (val) => setState(() => _priority = val),
                  getPriorityColor: widget.getPriorityColor,
                  textMuted: t.text3,
                ),
              ),
              if (_priority != 'none') ...[
                const SizedBox(width: 4),
                Text(
                  priorityFlagLabel(_priority),
                  style: TextStyle(
                    color: widget.getPriorityColor(_priority),
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ClarifyButton(
                  icon: LucideIcons.calendar,
                  label: _date == null
                      ? 'Без даты'.tr(widget.currentLang)
                      : widget.formatDate(_date!),
                  variant: ClarifyButtonVariant.outline,
                  fullWidth: true,
                  onPressed: () async {
                    final picked = await showClarifyDatePicker(
                      context: context,
                      isDark: Theme.of(context).brightness == Brightness.dark,
                      currentLang: widget.currentLang,
                      initialDate: _date,
                    );
                    if (picked != null) setState(() => _date = picked);
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ClarifyButton(
                  icon: LucideIcons.clock,
                  label: _time == null
                      ? 'Время'.tr(widget.currentLang)
                      : _time!.format(context),
                  variant: ClarifyButtonVariant.outline,
                  fullWidth: true,
                  onPressed: () async {
                    final picked = await showClarifyTimePicker(
                      context: context,
                      isDark: Theme.of(context).brightness == Brightness.dark,
                      currentLang: widget.currentLang,
                      initialTime: _time ?? TimeOfDay.now(),
                    );
                    if (picked != null) setState(() => _time = picked);
                  },
                ),
              ),
            ],
          ),
          if (_time != null) ...[
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 6, right: 8),
                  child: Icon(LucideIcons.hourglass, size: 16, color: t.text3),
                ),
                Expanded(
                  child: ClarifyDurationChips(
                    selectedMinutes: _duration,
                    currentLang: widget.currentLang,
                    isDark: Theme.of(context).brightness == Brightness.dark,
                    onChanged: (minutes) => setState(() => _duration = minutes),
                  ),
                ),
              ],
            ),
          ],
          if (_date != null)
            Builder(
              builder: (context) {
                final total =
                    dayLoadMinutes(widget.tasks, widget.formatDate(_date!)) +
                    (_time != null ? (_duration ?? 0) : 0);
                if (total <= AppConfig.dailyLoadWarningMinutes) {
                  return const SizedBox.shrink();
                }
                return ClarifyDayLoadWarning(
                  totalMinutes: total,
                  currentLang: widget.currentLang,
                );
              },
            ),
          const SizedBox(height: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(LucideIcons.repeat, size: 18, color: t.text3),
                  const SizedBox(width: 8),
                  DropdownButton<String>(
                    value: _recurrence,
                    dropdownColor: t.surface2,
                    underline: const SizedBox(),
                    style: TextStyle(fontSize: 14, color: t.text),
                    items: [
                      DropdownMenuItem(
                        value: 'none',
                        child: Text(
                          'Без повтора'.tr(widget.currentLang),
                          style: TextStyle(color: t.text),
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'daily',
                        child: Text(
                          'Каждый день'.tr(widget.currentLang),
                          style: TextStyle(color: t.text),
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'weekdays',
                        child: Text(
                          'По будням'.tr(widget.currentLang),
                          style: TextStyle(color: t.text),
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'weekly',
                        child: Text(
                          'Каждую неделю'.tr(widget.currentLang),
                          style: TextStyle(color: t.text),
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'monthly',
                        child: Text(
                          'Каждый месяц'.tr(widget.currentLang),
                          style: TextStyle(color: t.text),
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'custom',
                        child: Text(
                          'Кастомно'.tr(widget.currentLang),
                          style: TextStyle(color: t.text),
                        ),
                      ),
                    ],
                    onChanged: (val) => setState(() => _recurrence = val!),
                  ),
                ],
              ),
              if (_recurrence == 'custom') ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const SizedBox(width: 26),
                    Text(
                      'Каждые'.tr(widget.currentLang),
                      style: TextStyle(color: t.text3, fontSize: 14),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 56,
                      child: ClarifyTextField(
                        controller: TextEditingController(
                          text: _recurrenceInterval.toString(),
                        ),
                        keyboardType: TextInputType.number,
                        style: TextStyle(color: t.text),
                        textAlign: TextAlign.center,
                        dense: true,
                        onChanged: (val) =>
                            _recurrenceInterval = int.tryParse(val) ?? 2,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'дней'.tr(widget.currentLang),
                      style: TextStyle(color: t.text3, fontSize: 14),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              ClarifyTextField(
                controller: _tagsController,
                style: TextStyle(color: t.text),
                onChanged: (_) => setState(() {}),
                labelText: 'Теги (через запятую)'.tr(widget.currentLang),
                dense: true,
              ),
              if (_tagSuggestions.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: _tagSuggestions
                        .map(
                          (tag) => ActionChip(
                            label: Text(
                              tag,
                              style: TextStyle(color: t.text, fontSize: 12),
                            ),
                            backgroundColor: t.accentSoft,
                            onPressed: () => _applyTagSuggestion(tag),
                          ),
                        )
                        .toList(),
                  ),
                ),
              const SizedBox(height: 12),
              ClarifyTextField(
                controller: _noteController,
                style: TextStyle(color: t.text),
                maxLines: 2,
                labelText: 'Заметка'.tr(widget.currentLang),
              ),
              const SizedBox(height: 12),
              Text(
                'Чек-лист (Подзадачи):'.tr(widget.currentLang),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: t.text,
                ),
              ),
              const SizedBox(height: 8),
              if (_subtasks.isNotEmpty)
                Column(
                  children: _subtasks.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final subTitle = entry.value;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: t.surfaceSunken,
                        borderRadius: BorderRadius.circular(ClarifyRadius.sm),
                        border: Border.all(color: t.border),
                      ),
                      child: Row(
                        children: [
                          Icon(LucideIcons.circle, size: 16, color: t.text3),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              subTitle,
                              style: TextStyle(color: t.text),
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              LucideIcons.x,
                              size: 16,
                              color: t.danger,
                            ),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () =>
                                setState(() => _subtasks.removeAt(idx)),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              Row(
                children: [
                  Expanded(
                    child: ClarifyTextField(
                      controller: _subtaskController,
                      style: TextStyle(color: t.text),
                      hintText: 'Добавить пункт...'.tr(widget.currentLang),
                      dense: true,
                      onSubmitted: (text) {
                        if (text.trim().isNotEmpty)
                          setState(() {
                            _subtasks.add(text.trim());
                            _subtaskController.clear();
                          });
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  IconButton(
                    style: IconButton.styleFrom(
                      backgroundColor: t.accentSoft,
                      padding: const EdgeInsets.all(12),
                    ),
                    icon: Icon(LucideIcons.plus, color: t.accent),
                    onPressed: () {
                      if (_subtaskController.text.trim().isNotEmpty)
                        setState(() {
                          _subtasks.add(_subtaskController.text.trim());
                          _subtaskController.clear();
                        });
                    },
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClarifyButton(
            label: 'Сохранить'.tr(widget.currentLang),
            variant: ClarifyButtonVariant.filled,
            fullWidth: true,
            loading: _isSaving,
            onPressed: _isSaving ? null : _save,
          ),
        ],
      ),
    );
  }
}
