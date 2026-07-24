import 'package:flutter/material.dart';
import '../widgets/clarify_surface.dart';
import '../widgets/clarify_toast.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/localization.dart';
import '../core/theme/design_tokens.dart';

/// Диалоги управления проектами (папками) и командами (воркспейсами).
/// Вынесено из DesktopPlannerScreen (P3.1, docs/IMPROVEMENT_PLAN.md) — логика
/// и разметка не менялись, только доступ к состоянию родителя заменён на
/// явные параметры функций.

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

  showClarifySurface(
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

  showClarifySurface(
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
            Text("Введите Email пользователя. Он уже должен быть зарегистрирован в Clarify.".tr(currentLang), style: TextStyle(color: textMuted, fontSize: 13 * s)),
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
                ClarifyToast.show(context, 'Введите корректный Email', variant: ClarifyToastVariant.warning);
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
                  ClarifyToast.show(
                    context,
                    response.toString(),
                    variant: response.toString().startsWith('Успех') ? ClarifyToastVariant.success : ClarifyToastVariant.danger,
                  );
                }
              } catch (e) {
                print("Ошибка приглашения: $e");
                if (context.mounted) {
                  ClarifyToast.show(context, 'Ошибка сети: $e', variant: ClarifyToastVariant.danger);
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

/// Удаление всей команды (владелец/admin) или выход из неё (остальные участники)
/// — см. REDESIGN_V3_PLAN.md §3.12/5.12. RPC-функции определены в
/// `backend/clarify-backend/sql/workspace_delete_leave.sql` (применяются вручную
/// через Supabase SQL Editor — в репозитории нет системы миграций Supabase).
void showLeaveOrDeleteWorkspaceDialog({
  required BuildContext context,
  required int workspaceId,
  required bool canDelete,
  required Color textColor,
  required Color textMuted,
  required String currentLang,
  required Future<void> Function() onDone,
}) {
  final t = context.tokens;
  bool isLoading = false;

  showClarifySurface(
    context: context,
    barrierColor: Colors.black.withOpacity(0.4),
    builder: (context) => StatefulBuilder(builder: (context, setStateDialog) {
      return AlertDialog(
        backgroundColor: t.surface2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          canDelete ? "Удалить команду?".tr(currentLang) : "Выйти из команды?".tr(currentLang),
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
        ),
        content: Text(
          canDelete
              ? "Команда и все её задачи будут удалены безвозвратно.".tr(currentLang)
              : "Вы потеряете доступ к задачам и участникам этой команды.".tr(currentLang),
          style: TextStyle(color: textMuted, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Отмена".tr(currentLang), style: TextStyle(color: textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: t.danger, foregroundColor: t.onAccent),
            onPressed: isLoading ? null : () async {
              setStateDialog(() => isLoading = true);
              try {
                final response = await Supabase.instance.client.rpc(
                  canDelete ? 'delete_workspace' : 'leave_workspace',
                  params: {'ws_id': workspaceId},
                );
                if (context.mounted) Navigator.pop(context);
                await onDone();
                if (context.mounted) {
                  ClarifyToast.show(
                    context,
                    response.toString(),
                    variant: response.toString().startsWith('Успех') ? ClarifyToastVariant.success : ClarifyToastVariant.danger,
                  );
                }
              } catch (e) {
                print("Ошибка удаления/выхода из команды: $e");
                if (context.mounted) {
                  ClarifyToast.show(context, 'Ошибка сети: $e', variant: ClarifyToastVariant.danger);
                  setStateDialog(() => isLoading = false);
                }
              }
            },
            child: isLoading
                ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: t.onAccent, strokeWidth: 2))
                : Text(canDelete ? "Удалить".tr(currentLang) : "Выйти".tr(currentLang), style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      );
    }),
  );
}
