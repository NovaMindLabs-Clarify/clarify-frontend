import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../widgets/clarify_surface.dart';
import '../widgets/clarify_toast.dart';
import '../widgets/clarify_date_time_picker.dart';
import '../core/config.dart';
import '../core/localization.dart';
import '../core/theme/design_tokens.dart';

/// Диалог редактирования существующей задачи. Вынесено из
/// DesktopPlannerScreen (P3.1, docs/IMPROVEMENT_PLAN.md) — логика и разметка
/// не менялись (кроме текста лимита — см. ниже), только доступ к состоянию
/// родителя заменён на явные параметры функции.
void showEditTaskDialog({
  required BuildContext context,
  required Map<String, dynamic> task,
  required bool isDark,
  required Color textColor,
  required Color textMuted,
  required Color glassBorderColor,
  required String currentLang,
  required List<Map<String, dynamic>> tasks,
  required Map<int, List<Map<String, dynamic>>> workspaceMembers,
  required Future<void> Function(dynamic taskId, Map<String, dynamic> taskData) updateTaskData,
  required Color Function(String? priority) getPriorityColor,
  required String Function(DateTime date) formatDate,
  required DateTime? Function(String dateStr) parseDate,
  required Widget Function({
    required Widget child,
    BorderRadius? borderRadius,
    EdgeInsetsGeometry? padding,
    EdgeInsetsGeometry? margin,
    Color? customColor,
  }) buildGlassContainer,
}) {
  final t = context.tokens;
  final TextEditingController titleController = TextEditingController(text: task['title']);
  final TextEditingController noteController = TextEditingController(text: task['note'] ?? '');
  final TextEditingController tagsController = TextEditingController(text: task['tags'] ?? '');
  String selectedPriority = task['priority'] ?? 'none';
  String selectedRecurrence = task['recurrence'] ?? 'none';
  String? selectedAssigneeId = task['assigned_to'];
  DateTime? selectedDate = task['due_date'] != null ? parseDate(task['due_date']) : null;
  TimeOfDay? selectedTime;
  if (task['due_time'] != null && task['due_time'].toString().contains(':')) {
    final parts = task['due_time'].split(':');
    selectedTime = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }
  void localShiftDate(int days, int months, StateSetter setStateDialog) {
    DateTime baseDate = selectedDate ?? DateTime.now();
    setStateDialog(() => selectedDate = DateTime(baseDate.year, baseDate.month + months, baseDate.day + days));
  }

  bool isSaving = false;

  showClarifySurface(
    context: context,
    barrierColor: Colors.black.withOpacity(0.4),
    builder: (context) {
      return StatefulBuilder(builder: (context, setStateDialog) {
        return Center(
          child: Material(
            color: Colors.transparent,
            child: buildGlassContainer(
              padding: const EdgeInsets.all(24),
              child: SizedBox(
                width: 450,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("Редактировать".tr(currentLang), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: textColor)),
                          IconButton(icon: Icon(LucideIcons.x, color: textMuted), onPressed: () => Navigator.pop(context))
                        ]
                      ),
                      const SizedBox(height: 16),
                      TextField(controller: titleController, style: TextStyle(color: textColor, fontSize: 16), decoration: InputDecoration(labelText: "Заголовок".tr(currentLang), labelStyle: TextStyle(color: textMuted), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: glassBorderColor)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: t.accent)))),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(color: t.surfaceSunken, borderRadius: BorderRadius.circular(ClarifyRadius.md), border: Border.all(color: t.border)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                      Row(
                        children: [
                          Text("Приоритет: ".tr(currentLang), style: TextStyle(color: textMuted, fontSize: 14)),
                          const SizedBox(width: 8),
                          ...['none', 'red', 'orange', 'blue', 'gray'].map((pVal) {
                            Color btnColor = pVal == 'none' ? Colors.transparent : getPriorityColor(pVal);
                            bool isSelected = selectedPriority == pVal;
                            return GestureDetector(
                              onTap: () => setStateDialog(() => selectedPriority = pVal),
                              child: Container(
                                margin: const EdgeInsets.only(right: 8), width: 26, height: 26,
                                decoration: BoxDecoration(color: btnColor, shape: BoxShape.circle, border: isSelected ? Border.all(color: textColor, width: 2) : Border.all(color: glassBorderColor, width: 1)),
                                child: isSelected && pVal == 'none' ? Icon(LucideIcons.x, size: 14, color: textMuted) : null,
                              ),
                            );
                          }),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(child: OutlinedButton.icon(icon: Icon(LucideIcons.calendar, size: 18, color: textColor), label: Text(selectedDate == null ? "Без даты".tr(currentLang) : formatDate(selectedDate!), style: TextStyle(color: textColor)), style: OutlinedButton.styleFrom(side: BorderSide(color: glassBorderColor), padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), onPressed: () async { final picked = await showClarifyDatePicker(context: context, isDark: isDark, initialDate: selectedDate); if (picked != null) setStateDialog(() => selectedDate = picked); })),
                          const SizedBox(width: 12),
                          Expanded(child: OutlinedButton.icon(icon: Icon(LucideIcons.clock, size: 18, color: textColor), label: Text(selectedTime == null ? "Время".tr(currentLang) : selectedTime!.format(context), style: TextStyle(color: textColor)), style: OutlinedButton.styleFrom(side: BorderSide(color: glassBorderColor), padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), onPressed: () async { final picked = await showClarifyTimePicker(context: context, isDark: isDark, initialTime: selectedTime ?? TimeOfDay.now()); if (picked != null) setStateDialog(() => selectedTime = picked); })),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          TextButton(onPressed: () => localShiftDate(1, 0, setStateDialog), child: Text("+1 День".tr(currentLang))),
                          TextButton(onPressed: () => localShiftDate(7, 0, setStateDialog), child: Text("+1 Неделя".tr(currentLang))),
                          TextButton(onPressed: () => setStateDialog(() => selectedDate = null), child: Text("Убрать".tr(currentLang), style: TextStyle(color: t.danger))),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(LucideIcons.repeat, size: 18, color: textMuted),
                          const SizedBox(width: 8),
                          DropdownButton<String>(
                            value: selectedRecurrence, dropdownColor: t.surface2, underline: const SizedBox(), style: TextStyle(fontSize: 14, color: textColor),
                            items: [
                              DropdownMenuItem(value: 'none', child: Text("Без повтора".tr(currentLang), style: TextStyle(color: textColor))),
                              DropdownMenuItem(value: 'daily', child: Text("Каждый день".tr(currentLang), style: TextStyle(color: textColor))),
                              DropdownMenuItem(value: 'weekly', child: Text("Каждую неделю".tr(currentLang), style: TextStyle(color: textColor))),
                              DropdownMenuItem(value: 'monthly', child: Text("Каждый месяц".tr(currentLang), style: TextStyle(color: textColor))),
                            ],
                            onChanged: (val) => setStateDialog(() => selectedRecurrence = val!),
                          )
                        ],
                      ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                        decoration: BoxDecoration(color: t.surfaceSunken, borderRadius: BorderRadius.circular(ClarifyRadius.md), border: Border.all(color: t.border)),
                        child: Column(
                          children: [
                            TextField(controller: tagsController, style: TextStyle(color: textColor), decoration: InputDecoration(labelText: "Теги".tr(currentLang), labelStyle: TextStyle(color: textMuted), border: InputBorder.none, isDense: true)),
                            Divider(color: t.border, height: 1),
                            TextField(controller: noteController, style: TextStyle(color: textColor), maxLines: 2, decoration: InputDecoration(labelText: "Заметка".tr(currentLang), labelStyle: TextStyle(color: textMuted), alignLabelWithHint: true, border: InputBorder.none)),
                          ],
                        ),
                      ),

                      if (task['workspace_id'] != null) ...[
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          dropdownColor: t.surface2,
                          decoration: InputDecoration(
                            labelText: "Назначить на...".tr(currentLang),
                            labelStyle: TextStyle(color: textMuted),
                            prefixIcon: Icon(LucideIcons.user, color: t.accent, size: 20),
                            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: glassBorderColor)),
                          ),
                          value: selectedAssigneeId,
                          items: [
                            DropdownMenuItem(value: null, child: Text("Никто", style: TextStyle(color: textColor))),
                            ...(workspaceMembers[task['workspace_id']] ?? []).map((m) => DropdownMenuItem(
                              value: m['user_id'] as String,
                              child: Text(m['full_name'] ?? 'Участник', style: TextStyle(color: textColor)),
                            )),
                          ],
                          onChanged: (val) => setStateDialog(() => selectedAssigneeId = val),
                        ),
                      ],

                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(onPressed: () => Navigator.pop(context), child: Text("Отмена".tr(currentLang), style: TextStyle(color: textMuted))),
                          const SizedBox(width: 12),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: t.accent, foregroundColor: t.onAccent, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                            onPressed: isSaving ? null : () async {
                              if (titleController.text.trim().isEmpty) return;

                              setStateDialog(() => isSaving = true);

                              final newDateStr = selectedDate != null ? formatDate(selectedDate!) : null;

                              if (newDateStr != null && newDateStr != task['due_date']) {
                                final dayCount = tasks.where((t) => t['due_date'] == newDateStr && t['parent_id'] == null).length;
                                if (dayCount >= AppConfig.dailyTaskLimit) {
                                  ClarifyToast.show(context, "Достигнут лимит (${AppConfig.dailyTaskLimit}) на день!".tr(currentLang), variant: ClarifyToastVariant.danger);
                                  setStateDialog(() => isSaving = false);
                                  return;
                                }
                              }

                              await updateTaskData(task['id'], {
                                "title": titleController.text.trim(),
                                "due_date": newDateStr,
                                "due_time": selectedTime != null ? "${selectedTime!.hour.toString().padLeft(2, '0')}:${selectedTime!.minute.toString().padLeft(2, '0')}" : null,
                                "note": noteController.text.trim().isNotEmpty ? noteController.text.trim() : null,
                                "priority": selectedPriority,
                                "tags": tagsController.text.trim().isNotEmpty ? tagsController.text.trim() : null,
                                "recurrence": selectedRecurrence == 'none' ? null : selectedRecurrence,
                                "is_completed": task['is_completed'] ?? false,
                                "parent_id": task['parent_id'],
                                "assigned_to": selectedAssigneeId,
                              });

                              if (context.mounted) Navigator.of(context).pop();
                              if (context.mounted) setStateDialog(() => isSaving = false);
                            },
                            child: isSaving
                                ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: t.onAccent, strokeWidth: 2))
                                : Text("Сохранить".tr(currentLang), style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ],
                      )
                    ],
                  ),
                ),
              )
            ),
          ),
        );
      });
    },
  );
}
