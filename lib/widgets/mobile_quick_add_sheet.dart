import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'clarify_bottom_sheet.dart';
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
  final Future<int?> Function(Map<String, dynamic> taskData) createTaskManually;
  final void Function(String dateStr) checkBurnoutWarning;
  final Color Function(String? priority) getPriorityColor;
  final String Function(DateTime date) formatDate;
  final DateTime? preselectedDate;

  const _MobileQuickAddForm({
    required this.currentLang,
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
  String _priority = 'none';
  DateTime? _date;
  TimeOfDay? _time;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _date = widget.preselectedDate ?? DateTime.now();
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    if (title.isEmpty || _isSaving) return;
    setState(() => _isSaving = true);

    final date = _date;
    await widget.createTaskManually({
      "title": title,
      "due_date": date != null ? widget.formatDate(date) : null,
      "due_time": _time != null
          ? "${_time!.hour.toString().padLeft(2, '0')}:${_time!.minute.toString().padLeft(2, '0')}"
          : null,
      "priority": _priority,
      "is_completed": false,
      "parent_id": null,
    });

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
              Text('Приоритет:'.tr(widget.currentLang), style: TextStyle(color: t.text3, fontSize: 14)),
              const SizedBox(width: 10),
              ...['none', 'red', 'orange', 'blue', 'gray'].map((pVal) {
                final color = pVal == 'none' ? Colors.transparent : widget.getPriorityColor(pVal);
                final isSelected = _priority == pVal;
                return GestureDetector(
                  onTap: () => setState(() => _priority = pVal),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(color: isSelected ? t.text : t.border, width: isSelected ? 2 : 1),
                    ),
                    child: isSelected && pVal == 'none' ? Icon(LucideIcons.x, size: 14, color: t.text3) : null,
                  ),
                );
              }),
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
                    final picked = await showDatePicker(context: context, initialDate: _date ?? DateTime.now(), firstDate: DateTime(2000), lastDate: DateTime(2101));
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
                    final picked = await showTimePicker(context: context, initialTime: TimeOfDay.now());
                    if (picked != null) setState(() => _time = picked);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
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
