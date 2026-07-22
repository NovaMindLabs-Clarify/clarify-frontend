import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/localization.dart';
import '../core/theme/design_tokens.dart';

/// Диалоги управления проектами (папками) и командами (воркспейсами).
/// Вынесено из DesktopPlannerScreen (P3.1, docs/IMPROVEMENT_PLAN.md) — логика
/// и разметка не менялись, только доступ к состоянию родителя заменён на
/// явные параметры функций.

void showAddFolderDialog({
  required BuildContext context,
  required bool isDark,
  required Color textColor,
  required Color textMuted,
  required Color glassBorderColor,
  required String currentLang,
  required void Function(String folderName) onFolderAdded,
}) {
  final t = context.tokens;
  final ctrl = TextEditingController();
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: t.surface2,
      title: Text("Новый проект".tr(currentLang), style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
      content: TextField(controller: ctrl, style: TextStyle(color: textColor), decoration: InputDecoration(hintText: "Название папки".tr(currentLang), hintStyle: TextStyle(color: textMuted), enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: glassBorderColor)))),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text("Отмена".tr(currentLang), style: TextStyle(color: textMuted))),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: t.accent, foregroundColor: t.onAccent),
          onPressed: () {
            if (ctrl.text.trim().isNotEmpty) {
              onFolderAdded(ctrl.text.trim());
            }
            Navigator.pop(context);
          },
          child: Text("Создать".tr(currentLang)),
        ),
      ],
    ),
  );
}

void showCreateWorkspaceDialog({
  required BuildContext context,
  required bool isDark,
  required double scale,
  required Color textColor,
  required Color textMuted,
  required Color glassBorderColor,
  required String currentLang,
  required Future<void> Function() onWorkspaceCreated,
}) {
  final t = context.tokens;
  final ctrl = TextEditingController();
  bool isCreating = false;
  final s = scale;

  showDialog(
    context: context,
    barrierColor: Colors.black.withOpacity(0.4),
    builder: (context) => StatefulBuilder(builder: (context, setStateDialog) {
      return AlertDialog(
        backgroundColor: t.surface2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20 * s)),
        title: Text("Новая команда".tr(currentLang), style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: ctrl,
          style: TextStyle(color: textColor),
          autofocus: true,
          decoration: InputDecoration(
            hintText: "Название (например, Альфа-Проект)".tr(currentLang),
            hintStyle: TextStyle(color: textMuted),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: glassBorderColor)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Отмена".tr(currentLang), style: TextStyle(color: textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: t.accent, foregroundColor: t.onAccent),
            onPressed: isCreating ? null : () async {
              if (ctrl.text.trim().isEmpty) return;
              setStateDialog(() => isCreating = true);

              final user = Supabase.instance.client.auth.currentUser;
              try {
                // 1. Создаем воркспейс
                final newWorkspace = await Supabase.instance.client
                    .from('workspaces')
                    .insert({
                      'name': ctrl.text.trim(),
                      'owner_id': user!.id,
                    })
                    .select()
                    .single();

                // 2. Добавляем себя как владельца
                await Supabase.instance.client
                    .from('workspace_members')
                    .insert({
                      'workspace_id': newWorkspace['id'],
                      'user_id': user.id,
                      'role': 'owner',
                    });

                await onWorkspaceCreated(); // Обновляем список команд
                if (context.mounted) Navigator.pop(context);
              } catch (e) {
                print("Ошибка создания команды: $e");
                if (context.mounted) setStateDialog(() => isCreating = false);
              }
            },
            child: isCreating
                ? SizedBox(width: 16 * s, height: 16 * s, child: CircularProgressIndicator(color: t.onAccent, strokeWidth: 2))
                : Text("Создать".tr(currentLang)),
          ),
        ],
      );
    }),
  );
}

void showInviteMemberDialog({
  required BuildContext context,
  required int workspaceId,
  required bool isDark,
  required double scale,
  required Color textColor,
  required Color textMuted,
  required Color glassBorderColor,
  required String currentLang,
}) {
  final t = context.tokens;
  final emailCtrl = TextEditingController();
  bool isSending = false;
  final s = scale;

  showDialog(
    context: context,
    barrierColor: Colors.black.withOpacity(0.4),
    builder: (context) => StatefulBuilder(builder: (context, setStateDialog) {
      return AlertDialog(
        backgroundColor: t.surface2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20 * s)),
        title: Text("Пригласить коллегу".tr(currentLang), style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Введите Email пользователя. Он уже должен быть зарегистрирован в Clarify.", style: TextStyle(color: textMuted, fontSize: 13 * s)),
            SizedBox(height: 16 * s),
            TextField(
              controller: emailCtrl,
              style: TextStyle(color: textColor),
              autofocus: true,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                hintText: "email@example.com",
                hintStyle: TextStyle(color: textMuted),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: glassBorderColor)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Отмена".tr(currentLang), style: TextStyle(color: textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: t.accent, foregroundColor: t.onAccent),
            onPressed: isSending ? null : () async {
              if (emailCtrl.text.trim().isEmpty) return;
              if (!emailCtrl.text.contains('@')) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Введите корректный Email')));
                return;
              }

              setStateDialog(() => isSending = true);

              try {
                // Вызываем нашу SQL функцию через RPC
                final response = await Supabase.instance.client.rpc(
                  'invite_user_by_email',
                  params: {
                    'invitee_email': emailCtrl.text.trim(),
                    'ws_id': workspaceId,
                  },
                );

                if (context.mounted) {
                  Navigator.pop(context);
                  // Показываем ответ от базы данных (Успех или Ошибка)
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(response.toString()),
                      backgroundColor: response.toString().startsWith('Успех') ? t.success : t.danger,
                    ),
                  );
                }
              } catch (e) {
                print("Ошибка приглашения: $e");
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка сети: $e')));
                  setStateDialog(() => isSending = false);
                }
              }
            },
            child: isSending
                ? SizedBox(width: 16 * s, height: 16 * s, child: CircularProgressIndicator(color: t.onAccent, strokeWidth: 2))
                : Text("Пригласить".tr(currentLang), style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      );
    }),
  );
}
