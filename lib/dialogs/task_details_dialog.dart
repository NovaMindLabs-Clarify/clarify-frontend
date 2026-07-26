import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../widgets/clarify_surface.dart';
import '../widgets/clarify_text_field.dart';
import '../widgets/clarify_toast.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/localization.dart';
import '../core/theme/design_tokens.dart';

/// Диалог деталей задачи: чек-лист подзадач + обсуждение (комментарии).
/// Вынесено из DesktopPlannerScreen (P3.1, docs/IMPROVEMENT_PLAN.md) —
/// логика и разметка не менялись, только доступ к состоянию родителя
/// заменён на явные параметры функции.
void showTaskDetailsDialog({
  required BuildContext context,
  required Map<String, dynamic> task,
  required bool isDark,
  required Color textColor,
  required Color textMuted,
  required Color glassColor,
  required Color glassBorderColor,
  required Color cardColor,
  required Color doneCardColor,
  required Color highlightColor,
  required String currentLang,
  required List<Map<String, dynamic>> tasks,
  required Map<int, List<Map<String, dynamic>>> workspaceMembers,
  required Color Function(String? priority) getPriorityColor,
  required Future<void> Function(Map<String, dynamic> task) onToggleTask,
  required Future<void> Function(dynamic taskId) onDeleteTask,
  required Future<int?> Function(Map<String, dynamic> taskData) createTaskManually,
  required void Function(String tag) onTagTap,
  required void Function(Map<String, dynamic> task) onDuplicate,
  required void Function(Map<String, dynamic> task) onEdit,
  required Widget Function({
    required Widget child,
    BorderRadius? borderRadius,
    EdgeInsetsGeometry? padding,
    EdgeInsetsGeometry? margin,
    Color? customColor,
  }) buildGlassContainer,
}) {
  final t = context.tokens;
  // Контроллеры для подзадач и чата
  final TextEditingController subtaskController = TextEditingController();
  final TextEditingController commentController = TextEditingController();
  List<Map<String, dynamic>> comments = [];
  bool isCommentsLoaded = false;

  showClarifySurface(
    context: context,
    barrierColor: Colors.black.withOpacity(0.4),
    builder: (context) {
      return StatefulBuilder(builder: (context, setStateDialog) {

        // Загружаем комментарии (чат)
        if (!isCommentsLoaded) {
          isCommentsLoaded = true;
          Supabase.instance.client
              .from('task_comments')
              .select()
              .eq('task_id', task['id'])
              .order('created_at', ascending: true)
              .then((data) {
            if (context.mounted) {
              setStateDialog(() {
                comments = List<Map<String, dynamic>>.from(data);
              });
            }
          });
        }

        // Вычисляем подзадачи (чек-лист)
        final subtasks = tasks.where((t) => t['parent_id'] == task['id']).toList();

        return Center(
          child: Material(
            color: Colors.transparent,
            child: buildGlassContainer(
              borderRadius: ClarifyRadius.dialogShell,
              padding: const EdgeInsets.all(32),
              child: SizedBox(
                width: 450,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("Детали задачи".tr(currentLang), style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textMuted, letterSpacing: 1.2)),
                          IconButton(icon: Icon(LucideIcons.x, color: textMuted), padding: EdgeInsets.zero, constraints: const BoxConstraints(), onPressed: () => Navigator.pop(context))
                        ]
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          if (task['priority'] != null && task['priority'] != 'none') Container(margin: const EdgeInsets.only(right: 12), width: 14, height: 14, decoration: BoxDecoration(shape: BoxShape.circle, color: getPriorityColor(task['priority']), boxShadow: [BoxShadow(color: getPriorityColor(task['priority']).withOpacity(0.5), blurRadius: 8)])),
                          Expanded(child: Text(task['title'] ?? '', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: textColor))),
                        ],
                      ),
                      if (task['tags'] != null && task['tags'].toString().trim().isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          children: task['tags'].toString().split(',').map((tag) => GestureDetector(onTap: () { Navigator.pop(context); onTagTap(tag.trim()); }, child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), decoration: BoxDecoration(color: highlightColor, borderRadius: BorderRadius.circular(16), border: Border.all(color: t.accent.withValues(alpha: 0.4))), child: Text("#${tag.trim()}", style: TextStyle(fontSize: 13, color: t.accent, fontWeight: FontWeight.bold))), )).toList(),
                        )
                      ],
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: t.accentSoft, borderRadius: BorderRadius.circular(8)), child: Icon(LucideIcons.calendarDays, color: t.accent, size: 20)),
                          const SizedBox(width: 12),
                          Text("${task['due_date'] ?? 'Входящие (Без даты)'.tr(currentLang)}  •  ${task['due_time'] ?? 'Весь день'.tr(currentLang)}", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: textColor)),
                          if (task['recurrence'] != null && task['recurrence'] != 'none') ...[SizedBox(width: 12), Icon(LucideIcons.repeat, size: 18, color: t.text3)]
                        ],
                      ),

                      // ИСПОЛНИТЕЛЬ
                      if (task['assigned_to'] != null) ...[
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: t.accentSoft, borderRadius: BorderRadius.circular(8)), child: Icon(LucideIcons.user, color: t.accent, size: 20)),
                            const SizedBox(width: 12),
                            Builder(builder: (context) {
                              var members = workspaceMembers[task['workspace_id']] ?? [];
                              var member = members.firstWhere((m) => m['user_id'] == task['assigned_to'], orElse: () => <String, dynamic>{});
                              String name = member.isNotEmpty ? (member['full_name'] ?? 'Участник'.tr(currentLang)) : 'Неизвестно'.tr(currentLang);
                              return Text("${'Исполнитель: '.tr(currentLang)}$name", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: textColor));
                            }),
                          ],
                        ),
                      ],

                      if (task['note'] != null && task['note'].toString().isNotEmpty) ...[
                        const SizedBox(height: 24),
                        Container(
                          width: double.infinity, padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(color: doneCardColor, borderRadius: BorderRadius.circular(12), border: Border.all(color: glassBorderColor)),
                          child: MarkdownBody(
                            data: task['note'],
                            styleSheet: MarkdownStyleSheet(
                              p: TextStyle(color: textColor, fontSize: 15, height: 1.5),
                              strong: TextStyle(color: textColor, fontWeight: FontWeight.bold),
                              em: TextStyle(color: textColor, fontStyle: FontStyle.italic),
                              listBullet: TextStyle(color: t.accent),
                            )
                          )
                        ),
                      ],
                      const SizedBox(height: 32), Divider(color: glassBorderColor), const SizedBox(height: 16),

                      // ЧЕК-ЛИСТ (ПОДЗАДАЧИ)
                      Row(
                        children: [
                          Icon(LucideIcons.listChecks, color: t.accent), const SizedBox(width: 8),
                          Text("Чек-лист".tr(currentLang), style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)), const Spacer(),
                          if (subtasks.isNotEmpty) Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: glassColor, borderRadius: BorderRadius.circular(12)), child: Text("${subtasks.where((t) => t['is_completed'] == true).length} ${'из'.tr(currentLang)} ${subtasks.length}", style: TextStyle(color: textMuted, fontWeight: FontWeight.bold))),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (subtasks.isNotEmpty)
                        Column(
                          children: subtasks.map((subtask) {
                            bool isSubDone = subtask['is_completed'] == true;
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.symmetric(vertical: 4), decoration: BoxDecoration(color: isSubDone ? doneCardColor : cardColor, borderRadius: BorderRadius.circular(12), border: Border.all(color: glassBorderColor)),
                              child: Row(
                                children: [
                                  Checkbox(value: isSubDone, activeColor: t.accent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)), onChanged: (val) async { await onToggleTask(subtask); setStateDialog(() {}); }),
                                  Expanded(child: Text(subtask['title'], style: TextStyle(fontSize: 15, decoration: isSubDone ? TextDecoration.lineThrough : TextDecoration.none, color: isSubDone ? textMuted : textColor))),
                                  IconButton(icon: Icon(LucideIcons.x, size: 18, color: t.danger), onPressed: () async { await onDeleteTask(subtask['id']); setStateDialog(() {}); })
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(child: ClarifyTextField(controller: subtaskController, style: TextStyle(color: textColor), hintText: "Добавить пункт...".tr(currentLang), dense: true,
                            onSubmitted: (text) {
                              if (text.trim().isEmpty) return;
                              subtaskController.clear();
                              createTaskManually({"title": text.trim(), "parent_id": task['id'], "is_completed": false});
                              setStateDialog(() {});
                            })),
                          const SizedBox(width: 8),
                          IconButton(style: IconButton.styleFrom(backgroundColor: highlightColor, padding: const EdgeInsets.all(12)), icon: Icon(LucideIcons.plus, color: t.accent),
                            onPressed: () {
                              if (subtaskController.text.trim().isEmpty) return;
                              final text = subtaskController.text;
                              subtaskController.clear();
                              createTaskManually({"title": text.trim(), "parent_id": task['id'], "is_completed": false});
                              setStateDialog(() {});
                            })
                        ],
                      ),

                      // ЧАТ (ОБСУЖДЕНИЕ)
                      const SizedBox(height: 32),
                      Divider(color: glassBorderColor),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Icon(LucideIcons.messageCircle, color: t.accent),
                          const SizedBox(width: 8),
                          Text("Обсуждение".tr(currentLang), style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
                        ],
                      ),
                      const SizedBox(height: 16),

                      if (comments.isNotEmpty)
                        Container(
                          constraints: const BoxConstraints(maxHeight: 250),
                          margin: const EdgeInsets.only(bottom: 16),
                          child: SingleChildScrollView(
                            child: Column(
                              children: comments.map((c) {
                                bool isMyComment = c['user_id'] == Supabase.instance.client.auth.currentUser?.id;
                                String authorName = "Пользователь";
                                String initial = "?";
                                if (task['workspace_id'] != null) {
                                  var members = workspaceMembers[task['workspace_id']] ?? [];
                                  var member = members.firstWhere((m) => m['user_id'] == c['user_id'], orElse: () => <String, dynamic>{});
                                  if (member.isNotEmpty) {
                                    authorName = member['full_name'] ?? authorName;
                                    initial = authorName[0].toUpperCase();
                                  }
                                } else if (isMyComment) {
                                  authorName = "Я";
                                  initial = "Я";
                                }

                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: isMyComment ? MainAxisAlignment.end : MainAxisAlignment.start,
                                    children: [
                                      if (!isMyComment)
                                        Padding(
                                          padding: const EdgeInsets.only(right: 8),
                                          child: CircleAvatar(radius: 14, backgroundColor: t.tagPalette[7], child: Text(initial, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold))),
                                        ),

                                      Flexible(
                                        child: Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: isMyComment ? t.accentSoft : glassColor,
                                            borderRadius: BorderRadius.circular(12).copyWith(
                                              topLeft: !isMyComment ? const Radius.circular(0) : const Radius.circular(12),
                                              topRight: isMyComment ? const Radius.circular(0) : const Radius.circular(12),
                                            ),
                                            border: Border.all(color: isMyComment ? t.accent.withValues(alpha: 0.3) : glassBorderColor)
                                          ),
                                          child: Column(
                                            crossAxisAlignment: isMyComment ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                            children: [
                                              Text(authorName, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isMyComment ? t.accent : textMuted)),
                                              const SizedBox(height: 4),
                                              Text(c['text'] ?? '', style: TextStyle(fontSize: 14, color: textColor)),
                                            ],
                                          ),
                                        ),
                                      ),

                                      if (isMyComment)
                                        Padding(
                                          padding: const EdgeInsets.only(left: 8),
                                          child: CircleAvatar(radius: 14, backgroundColor: t.accent, child: Text(initial, style: TextStyle(color: t.onAccent, fontSize: 12, fontWeight: FontWeight.bold))),
                                        ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ),

                      Row(
                        children: [
                          Expanded(
                            child: ClarifyTextField(
                              controller: commentController,
                              style: TextStyle(color: textColor),
                              hintText: "Написать комментарий...".tr(currentLang),
                              dense: true,
                              onSubmitted: (text) async {
                                if (commentController.text.trim().isEmpty) return;
                                final submittedText = commentController.text.trim();
                                commentController.clear();

                                final user = Supabase.instance.client.auth.currentUser;
                                if (user == null) return;

                                final newComment = {
                                  'task_id': task['id'],
                                  'user_id': user.id,
                                  'text': submittedText,
                                };

                                setStateDialog(() {
                                  comments.add({...newComment, 'created_at': DateTime.now().toIso8601String()});
                                });

                                try {
                                  await Supabase.instance.client.from('task_comments').insert(newComment);
                                } catch (e) {
                                  print("Ошибка отправки комментария: $e");
                                }
                              }
                            )
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            style: IconButton.styleFrom(backgroundColor: t.accent, padding: const EdgeInsets.all(12)),
                            icon: Icon(LucideIcons.send, color: t.onAccent, size: 20),
                            onPressed: () async {
                              if (commentController.text.trim().isEmpty) return;
                              final text = commentController.text.trim();
                              commentController.clear();

                              final user = Supabase.instance.client.auth.currentUser;
                              if (user == null) return;

                              final newComment = {
                                'task_id': task['id'],
                                'user_id': user.id,
                                'text': text,
                              };

                              setStateDialog(() {
                                comments.add({...newComment, 'created_at': DateTime.now().toIso8601String()});
                              });

                              try {
                                await Supabase.instance.client.from('task_comments').insert(newComment);
                              } catch (e) {
                                print("Ошибка отправки комментария: $e");
                              }
                            }
                          )
                        ],
                      ),

                      // КНОПКИ УПРАВЛЕНИЯ ЗАДАЧЕЙ
                      const SizedBox(height: 32),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          TextButton.icon(icon: Icon(LucideIcons.trash2, color: t.danger), label: Text("Удалить".tr(currentLang), style: TextStyle(color: t.danger)), onPressed: () { Navigator.of(context).pop(); onDeleteTask(task['id']); }),
                          Row(
                            children: [
                              TextButton.icon(icon: Icon(LucideIcons.copy, color: t.accent), label: Text("Дублировать".tr(currentLang), style: TextStyle(color: t.accent)), onPressed: () { onDuplicate(task); Navigator.of(context).pop(); ClarifyToast.show(context, "Кликни на плюсик любого дня".tr(currentLang), variant: ClarifyToastVariant.info); }),
                              const SizedBox(width: 8),
                              ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: t.accent, foregroundColor: t.onAccent, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), icon: const Icon(LucideIcons.pencil, size: 18), label: Text("Изменить".tr(currentLang), style: TextStyle(fontWeight: FontWeight.bold)), onPressed: () { ClarifySurfaceTransitionOut.markCollapseOnClose(context); Navigator.of(context).pop(); onEdit(task); }),
                            ]
                          )
                        ]
                      )
                    ],
                  ),
                ),
              )
            ),
          ),
        );
      });
    }
  );
}
