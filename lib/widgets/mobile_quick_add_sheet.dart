import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../core/tags.dart';
import '../core/priority.dart';
import 'clarify_bottom_sheet.dart';
import 'clarify_date_time_picker.dart';
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
  required Future<int?> Function(Map<String, dynamic> taskData) createTaskManually,
  required void Function(String dateStr) checkBurnoutWarning,
  required Color Function(String? priority) getPriorityColor,
  required String Function(DateTime date) formatDate,
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
  final DateTime? preselectedDate;

  const _MobileQuickAddForm({
    required this.currentLang,
    required this.tasks,
    required this.createTaskManually,
    required this.checkBurnoutWarning,
    required this.getPriorityColor,
    required this.formatDate,
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
  bool _isSaving = false;
  bool _expanded = false;
  final List<String> _subtasks = [];

  @override
  void initState() {
    super.initState();
    _date = widget.preselectedDate ?? DateTime.now();
  }

  List<String> get _tagSuggestions {
    final segments = _tagsController.text.split(',').map((e) => e.trim()).toList();
    final fragment = segments.isEmpty ? '' : segments.last;
    if (fragment.isEmpty) return const [];
    final existing = segments.take(segments.length - 1).toSet();
    final knownTags = collectAllTags(widget.tasks);
    return knownTags.where((tag) => tag.toLowerCase().contains(fragment.toLowerCase()) && tag.toLowerCase() != fragment.toLowerCase() && !existing.contains(tag)).take(5).toList();
  }

  void _applyTagSuggestion(String tag) {
    final segments = _tagsController.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    if (segments.isNotEmpty) segments.removeLast();
    segments.add(tag);
    setState(() {
      _tagsController.text = '${segments.join(', ')}, ';
      _tagsController.selection = TextSelection.collapsed(offset: _tagsController.text.length);
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
      "priority": _priority,
      "note": _noteController.text.trim().isNotEmpty ? _noteController.text.trim() : null,
      "tags": _tagsController.text.trim().isNotEmpty ? _tagsController.text.trim() : null,
      "recurrence": _recurrence == 'none' ? null : _recurrence,
      "recurrence_interval": _recurrence == 'custom' ? _recurrenceInterval : null,
      "is_completed": false,
      "parent_id": null,
    });

    if (newTaskId != null && _subtasks.isNotEmpty) {
      for (final subTitle in _subtasks) {
        await widget.createTaskManually({"title": subTitle, "parent_id": newTaskId, "is_completed": false});
      }
    }

    if (mounted) Navigator.pop(context);
    if (date != null) widget.checkBurnoutWarning(widget.formatDate(date));
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 4, 20, MediaQuery.of(context).padding.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Новая задача'.tr(widget.currentLang),
            style: TextStyle(fontFamily: 'Golos Text', fontSize: 18, fontWeight: FontWeight.w700, color: t.text),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _titleController,
            autofocus: true,
            style: TextStyle(color: t.text),
            decoration: InputDecoration(
              hintText: 'Заголовок'.tr(widget.currentLang),
              hintStyle: TextStyle(color: t.text3),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(ClarifyRadius.md), borderSide: BorderSide(color: t.border)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(ClarifyRadius.md), borderSide: BorderSide(color: t.border)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(ClarifyRadius.md), borderSide: BorderSide(color: t.accent, width: 2)),
            ),
            onSubmitted: (_) => _save(),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text('Приоритет: '.tr(widget.currentLang), style: TextStyle(color: t.text3, fontSize: 14)),
              const SizedBox(width: 10),
              ...['none', 'red', 'orange', 'blue', 'gray'].map((pVal) {
                final color = pVal == 'none' ? Colors.transparent : widget.getPriorityColor(pVal);
                final isSelected = _priority == pVal;
                final label = priorityFlagLabel(pVal);
                return GestureDetector(
                  onTap: () => setState(() => _priority = pVal),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: pVal == 'none' ? Colors.transparent : color.withValues(alpha: 0.16),
                      shape: BoxShape.circle,
                      border: Border.all(color: isSelected ? t.text : t.border, width: isSelected ? 2 : 1),
                    ),
                    alignment: Alignment.center,
                    child: pVal == 'none'
                        ? Icon(LucideIcons.x, size: 14, color: t.text3)
                        : label.isEmpty
                            ? null
                            : Icon(LucideIcons.flag, size: 14, color: color),
                  ),
                );
              }),
              if (_priority != 'none') ...[
                const SizedBox(width: 4),
                Text(priorityFlagLabel(_priority), style: TextStyle(color: widget.getPriorityColor(_priority), fontWeight: FontWeight.bold, fontSize: 13)),
              ],
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: Icon(LucideIcons.calendar, size: 18, color: t.text),
                  label: Text(_date == null ? 'Без даты'.tr(widget.currentLang) : widget.formatDate(_date!), style: TextStyle(color: t.text)),
                  style: OutlinedButton.styleFrom(side: BorderSide(color: t.border), padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ClarifyRadius.md))),
                  onPressed: () async {
                    final picked = await showClarifyDatePicker(context: context, isDark: Theme.of(context).brightness == Brightness.dark, currentLang: widget.currentLang, initialDate: _date);
                    if (picked != null) setState(() => _date = picked);
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  icon: Icon(LucideIcons.clock, size: 18, color: t.text),
                  label: Text(_time == null ? 'Время'.tr(widget.currentLang) : _time!.format(context), style: TextStyle(color: t.text)),
                  style: OutlinedButton.styleFrom(side: BorderSide(color: t.border), padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ClarifyRadius.md))),
                  onPressed: () async {
                    final picked = await showClarifyTimePicker(context: context, isDark: Theme.of(context).brightness == Brightness.dark, currentLang: widget.currentLang, initialTime: _time ?? TimeOfDay.now());
                    if (picked != null) setState(() => _time = picked);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          InkWell(
            borderRadius: BorderRadius.circular(ClarifyRadius.sm),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Ещё'.tr(widget.currentLang), style: TextStyle(color: t.accent, fontWeight: FontWeight.w600, fontSize: 14)),
                  Icon(_expanded ? LucideIcons.chevronUp : LucideIcons.chevronDown, size: 18, color: t.accent),
                ],
              ),
            ),
          ),
          // Внутренний рост шторки при раскрытии — само открытие шторки (container
          // transform из FAB) этим не затрагивается, растёт только содержимое
          // (REDESIGN_V3_PLAN.md §3.16/5.15).
          AnimatedSize(
            duration: ClarifyMotion.base,
            curve: ClarifyMotion.standard,
            alignment: Alignment.topCenter,
            child: !_expanded
                ? const SizedBox(width: double.infinity)
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
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
                              DropdownMenuItem(value: 'none', child: Text('Без повтора'.tr(widget.currentLang), style: TextStyle(color: t.text))),
                              DropdownMenuItem(value: 'daily', child: Text('Каждый день'.tr(widget.currentLang), style: TextStyle(color: t.text))),
                              DropdownMenuItem(value: 'weekdays', child: Text('По будням'.tr(widget.currentLang), style: TextStyle(color: t.text))),
                              DropdownMenuItem(value: 'weekly', child: Text('Каждую неделю'.tr(widget.currentLang), style: TextStyle(color: t.text))),
                              DropdownMenuItem(value: 'monthly', child: Text('Каждый месяц'.tr(widget.currentLang), style: TextStyle(color: t.text))),
                              DropdownMenuItem(value: 'custom', child: Text('Кастомно'.tr(widget.currentLang), style: TextStyle(color: t.text))),
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
                            Text('Каждые'.tr(widget.currentLang), style: TextStyle(color: t.text3, fontSize: 14)),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 56,
                              child: TextField(
                                controller: TextEditingController(text: _recurrenceInterval.toString()),
                                keyboardType: TextInputType.number,
                                style: TextStyle(color: t.text),
                                decoration: InputDecoration(isDense: true, contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: t.border))),
                                onChanged: (val) => _recurrenceInterval = int.tryParse(val) ?? 2,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text('дней'.tr(widget.currentLang), style: TextStyle(color: t.text3, fontSize: 14)),
                          ],
                        ),
                      ],
                      const SizedBox(height: 12),
                      TextField(
                        controller: _tagsController,
                        style: TextStyle(color: t.text),
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          labelText: 'Теги (через запятую)'.tr(widget.currentLang),
                          labelStyle: TextStyle(color: t.text3),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(ClarifyRadius.md), borderSide: BorderSide(color: t.border)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(ClarifyRadius.md), borderSide: BorderSide(color: t.accent)),
                          isDense: true,
                        ),
                      ),
                      if (_tagSuggestions.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: _tagSuggestions.map((tag) => ActionChip(
                              label: Text(tag, style: TextStyle(color: t.text, fontSize: 12)),
                              backgroundColor: t.accentSoft,
                              onPressed: () => _applyTagSuggestion(tag),
                            )).toList(),
                          ),
                        ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _noteController,
                        style: TextStyle(color: t.text),
                        maxLines: 2,
                        decoration: InputDecoration(
                          labelText: 'Заметка'.tr(widget.currentLang),
                          labelStyle: TextStyle(color: t.text3),
                          alignLabelWithHint: true,
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(ClarifyRadius.md), borderSide: BorderSide(color: t.border)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(ClarifyRadius.md), borderSide: BorderSide(color: t.accent)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text('Чек-лист (Подзадачи):'.tr(widget.currentLang), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: t.text)),
                      const SizedBox(height: 8),
                      if (_subtasks.isNotEmpty)
                        Column(
                          children: _subtasks.asMap().entries.map((entry) {
                            final idx = entry.key;
                            final subTitle = entry.value;
                            return Container(
                              margin: const EdgeInsets.only(bottom: 6),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(color: t.surfaceSunken, borderRadius: BorderRadius.circular(ClarifyRadius.sm), border: Border.all(color: t.border)),
                              child: Row(
                                children: [
                                  Icon(LucideIcons.circle, size: 16, color: t.text3),
                                  const SizedBox(width: 8),
                                  Expanded(child: Text(subTitle, style: TextStyle(color: t.text))),
                                  IconButton(icon: Icon(LucideIcons.x, size: 16, color: t.danger), padding: EdgeInsets.zero, constraints: const BoxConstraints(), onPressed: () => setState(() => _subtasks.removeAt(idx))),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _subtaskController,
                              style: TextStyle(color: t.text),
                              decoration: InputDecoration(
                                hintText: 'Добавить пункт...'.tr(widget.currentLang),
                                hintStyle: TextStyle(color: t.text3),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(ClarifyRadius.md), borderSide: BorderSide(color: t.border)),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(ClarifyRadius.md), borderSide: BorderSide(color: t.border)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                isDense: true,
                              ),
                              onSubmitted: (text) { if (text.trim().isNotEmpty) setState(() { _subtasks.add(text.trim()); _subtaskController.clear(); }); },
                            ),
                          ),
                          const SizedBox(width: 10),
                          IconButton(
                            style: IconButton.styleFrom(backgroundColor: t.accentSoft, padding: const EdgeInsets.all(12)),
                            icon: Icon(LucideIcons.plus, color: t.accent),
                            onPressed: () { if (_subtaskController.text.trim().isNotEmpty) setState(() { _subtasks.add(_subtaskController.text.trim()); _subtaskController.clear(); }); },
                          ),
                        ],
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: t.accent, foregroundColor: t.onAccent, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ClarifyRadius.md))),
              onPressed: _isSaving ? null : _save,
              child: _isSaving
                  ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: t.onAccent, strokeWidth: 2))
                  : Text('Сохранить'.tr(widget.currentLang), style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}
