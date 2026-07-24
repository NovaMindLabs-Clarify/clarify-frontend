import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../widgets/clarify_surface.dart';
import '../widgets/clarify_toast.dart';
import 'package:launch_at_startup/launch_at_startup.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/config.dart';
import '../core/localization.dart';
import '../core/theme/design_tokens.dart';
import '../widgets/clarify_settings_card.dart';

/// Диалог настроек аккаунта: аватар, имя, автозапуск, язык, смена пароля,
/// выход. Вынесено из DesktopPlannerScreen (P3.1, docs/IMPROVEMENT_PLAN.md) —
/// логика и разметка не менялись, только доступ к состоянию родителя
/// заменён на явные параметры функции.
void showAccountSettingsDialog({
  required BuildContext context,
  required bool isDark,
  required Color textColor,
  required Color textMuted,
  required Color glassColor,
  required Color glassBorderColor,
  required Color highlightColor,
  required String currentLang,
  required Function(String lang) changeLang,
  required VoidCallback onProfileChanged,
  bool isMobileContext = false,
  required Widget Function({
    required Widget child,
    BorderRadius? borderRadius,
    EdgeInsetsGeometry? padding,
    EdgeInsetsGeometry? margin,
    Color? customColor,
  }) buildGlassContainer,
}) {
  final t = context.tokens;
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) return;

  String fullName = user.userMetadata?['full_name'] ?? '';
  String? avatarUrl = user.userMetadata?['avatar_url'];
  final email = user.email ?? '';

  final providers = user.appMetadata['providers'] as List<dynamic>? ?? [];
  final hasPasswordAuth = providers.contains('email');

  final nameController = TextEditingController(text: fullName);
  final oldPasswordController = TextEditingController();
  final newPasswordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  bool isLoading = false;
  bool isChangingPassword = false;
  bool isAutostart = false; // Состояние автозапуска
  bool showPlanDetails = false;
  bool showCalendars = false;
  String? friendCode;
  bool friendCodeFetchStarted = false;

  showClarifySurface(
    context: context,
    barrierColor: Colors.black.withOpacity(0.4),
    builder: (context) {
      return StatefulBuilder(builder: (context, setStateDialog) {

        // Получаем актуальный статус автозагрузки при открытии
        launchAtStartup.isEnabled().then((value) {
          if (context.mounted && isAutostart != value) {
            setStateDialog(() => isAutostart = value);
          }
        });

        // Код друга (SOCIAL_PLAN.md §4.1) — запрашиваем один раз за открытие диалога.
        if (!friendCodeFetchStarted) {
          friendCodeFetchStarted = true;
          Supabase.instance.client.rpc('ensure_profile').then((row) {
            if (context.mounted) setStateDialog(() => friendCode = row['friend_code'] as String?);
          }).catchError((_) {});
        }

        Future<void> pickAndUpload() async {
          FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
          if (result != null && result.files.single.bytes != null) {
            setStateDialog(() => isLoading = true);
            try {
              final bytes = result.files.single.bytes!;
              final ext = result.files.single.extension ?? 'png';
              final fileName = '${user.id}_${DateTime.now().millisecondsSinceEpoch}.$ext';

              await Supabase.instance.client.storage.from('avatars').uploadBinary(fileName, bytes);
              final newUrl = Supabase.instance.client.storage.from('avatars').getPublicUrl(fileName);

              await Supabase.instance.client.auth.updateUser(UserAttributes(data: {'avatar_url': newUrl}));

              setStateDialog(() => avatarUrl = newUrl);
              onProfileChanged();
              if (context.mounted) ClarifyToast.show(context, 'Аватар обновлен!'.tr(currentLang), variant: ClarifyToastVariant.success);
            } catch (e) {
              if (context.mounted) ClarifyToast.show(context, "${'Ошибка: '.tr(currentLang)}$e", variant: ClarifyToastVariant.danger);
            } finally {
              setStateDialog(() => isLoading = false);
            }
          }
        }

        Future<void> deleteAvatar() async {
          setStateDialog(() => isLoading = true);
          try {
            await Supabase.instance.client.auth.updateUser(UserAttributes(data: {'avatar_url': null}));
            setStateDialog(() => avatarUrl = null);
            onProfileChanged();
            if (context.mounted) ClarifyToast.show(context, 'Аватарка удалена!'.tr(currentLang), variant: ClarifyToastVariant.success);
          } catch (e) {
            if (context.mounted) ClarifyToast.show(context, "${'Ошибка: '.tr(currentLang)}$e", variant: ClarifyToastVariant.danger);
          } finally {
            setStateDialog(() => isLoading = false);
          }
        }

        return Center(
          child: Material(
            color: Colors.transparent,
            child: buildGlassContainer(
              padding: const EdgeInsets.all(32),
              child: SizedBox(
                width: 400,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("Настройки".tr(currentLang), style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor)),
                          if (isLoading)
                            const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          else
                            IconButton(icon: Icon(LucideIcons.x, color: textMuted), onPressed: () => Navigator.pop(context))
                        ]
                      ),
                      const SizedBox(height: 24),

                      GestureDetector(
                        onTap: isLoading ? null : () {
                          bool hasAvatar = avatarUrl != null && avatarUrl!.isNotEmpty;
                          showClarifySurface(
                            context: context,
                            builder: (dialogCtx) => AlertDialog(
                              backgroundColor: t.surface2,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              title: Text("Фото профиля".tr(currentLang), style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
                              content: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  ListTile(
                                    leading: Icon(LucideIcons.upload, color: t.accent),
                                    title: Text("Загрузить новое".tr(currentLang), style: TextStyle(color: textColor)),
                                    onTap: () {
                                      Navigator.pop(dialogCtx);
                                      pickAndUpload();
                                    },
                                  ),
                                  if (hasAvatar) ...[
                                    const Divider(),
                                    ListTile(
                                      leading: Icon(LucideIcons.trash2, color: t.danger),
                                      title: Text("Удалить текущее".tr(currentLang), style: TextStyle(color: t.danger, fontWeight: FontWeight.bold)),
                                      onTap: () {
                                        Navigator.pop(dialogCtx);
                                        deleteAvatar();
                                      },
                                    ),
                                  ]
                                ],
                              ),
                            )
                          );
                        },
                        child: Stack(
                          alignment: Alignment.bottomRight,
                          children: [
                            CircleAvatar(
                              radius: 45,
                              backgroundColor: t.surfaceSunken,
                              backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl!) : null,
                              child: avatarUrl == null
                                ? Text(fullName.isNotEmpty ? fullName[0].toUpperCase() : '?', style: TextStyle(fontSize: 32, color: textMuted))
                                : null,
                            ),
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(color: t.accent, shape: BoxShape.circle, border: Border.all(color: glassBorderColor, width: 2)),
                              child: Icon(LucideIcons.camera, size: 16, color: t.onAccent),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),

                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: nameController, style: TextStyle(color: textColor),
                              decoration: InputDecoration(labelText: "Никнейм".tr(currentLang), labelStyle: TextStyle(color: textMuted), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: glassBorderColor)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: t.accent)), isDense: true)
                            ),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: highlightColor, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16)),
                            onPressed: isLoading ? null : () async {
                              if (nameController.text.trim().isEmpty) return;
                              setStateDialog(() => isLoading = true);
                              try {
                                await Supabase.instance.client.auth.updateUser(UserAttributes(data: {'full_name': nameController.text.trim()}));
                                onProfileChanged();
                                if (context.mounted) ClarifyToast.show(context, 'Имя сохранено!'.tr(currentLang), variant: ClarifyToastVariant.success);
                              } catch (e) {
                                if (context.mounted) ClarifyToast.show(context, "${'Ошибка: '.tr(currentLang)}$e", variant: ClarifyToastVariant.danger);
                              } finally {
                                setStateDialog(() => isLoading = false);
                              }
                            },
                            child: Text("Сохранить".tr(currentLang), style: TextStyle(color: t.accent, fontWeight: FontWeight.bold))
                          )
                        ],
                      ),
                      const SizedBox(height: 16),

                      // --- КОД ДРУГА --- SOCIAL_PLAN.md §4.1: поиск/добавление в друзья по
                      // короткому публичному коду вместо email.
                      ClarifySettingsCard(
                        icon: LucideIcons.userRound,
                        title: "Код друга".tr(currentLang),
                        trailing: friendCode == null
                            ? SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: textMuted))
                            : InkWell(
                                borderRadius: BorderRadius.circular(8),
                                onTap: () {
                                  Clipboard.setData(ClipboardData(text: friendCode!));
                                  ClarifyToast.show(context, 'Код скопирован!'.tr(currentLang), variant: ClarifyToastVariant.success);
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(friendCode!, style: TextStyle(color: t.accent, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                                      const SizedBox(width: 6),
                                      Icon(LucideIcons.copy, size: 14, color: t.accent),
                                    ],
                                  ),
                                ),
                              ),
                      ),
                      const SizedBox(height: 12),

                      // --- ПЕРЕКЛЮЧАТЕЛЬ АВТОЗАПУСКА --- только на десктопе, на мобильном
                      // (PWA) автозапуск с Windows бессмысленен (REDESIGN_V3_PLAN.md §3.14/5.14).
                      if (!isMobileContext) ...[
                        ClarifySettingsCard(
                          icon: LucideIcons.rocket,
                          title: "Автозапуск с Windows".tr(currentLang),
                          trailing: Switch(
                            value: isAutostart,
                            activeColor: t.accent,
                            onChanged: (val) async {
                              setStateDialog(() => isAutostart = val);
                              if (val) {
                                await launchAtStartup.enable();
                              } else {
                                await launchAtStartup.disable();
                              }
                            },
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],

                      ClarifySettingsCard(
                        icon: LucideIcons.globe,
                        title: "Язык".tr(currentLang),
                        trailing: Container(
                          height: 36,
                          decoration: BoxDecoration(
                            color: glassColor,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: glassBorderColor)
                          ),
                          child: ToggleButtons(
                            borderRadius: BorderRadius.circular(12),
                            borderColor: Colors.transparent, selectedBorderColor: Colors.transparent,
                            fillColor: t.accentSoft,
                            selectedColor: t.accent, color: textMuted,
                            constraints: const BoxConstraints(minHeight: 36, minWidth: 48),
                            isSelected: [currentLang == 'ru', currentLang == 'en'],
                            onPressed: (index) {
                              changeLang(index == 0 ? 'ru' : 'en');
                              Navigator.pop(context);
                            },
                            children: const [
                              Text("RU", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              Text("EN", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // --- ПЛАН: текущий тариф + сравнение Free/Pro ---
                      // Только каркас — реальной оплаты нет, см. REDESIGN_V2_PLAN.md §4.
                      ClarifySettingsCard(
                        icon: LucideIcons.crown,
                        iconColor: t.warning,
                        title: "План".tr(currentLang),
                        onTap: () => setStateDialog(() => showPlanDetails = !showPlanDetails),
                        isExpanded: showPlanDetails,
                        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(color: t.accentSoft, borderRadius: BorderRadius.circular(999)),
                            child: Text("Free", style: TextStyle(color: t.accent, fontSize: 12, fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(width: 6),
                          Icon(showPlanDetails ? LucideIcons.chevronUp : LucideIcons.chevronDown, color: textMuted, size: 18),
                        ]),
                        expandedChild: Column(
                          children: [
                            Divider(color: t.border, height: 17),
                            _PlanRow(label: "AI-запросы в месяц".tr(currentLang), free: "50", pro: "Без лимита".tr(currentLang), textColor: textColor, textMuted: textMuted),
                            _PlanRow(label: "Участников в команде".tr(currentLang), free: "3", pro: "Без лимита".tr(currentLang), textColor: textColor, textMuted: textMuted),
                            _PlanRow(label: "Синхронизация с Яндекс.Календарём".tr(currentLang), freeCheck: false, textColor: textColor, textMuted: textMuted, accent: t.accent, danger: t.danger),
                            _PlanRow(label: "Расширенная статистика".tr(currentLang), freeCheck: false, textColor: textColor, textMuted: textMuted, accent: t.accent, danger: t.danger),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(backgroundColor: t.accent, foregroundColor: t.onAccent, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                                onPressed: () => ClarifyToast.show(context, "Оплата Pro скоро будет доступна".tr(currentLang), variant: ClarifyToastVariant.info),
                                child: Text("Оформить Pro — 199 ₽/мес".tr(currentLang), style: const TextStyle(fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // --- КАЛЕНДАРИ: внешние интеграции (P2.4 IMPROVEMENT_PLAN.md) ---
                      ClarifySettingsCard(
                        icon: LucideIcons.calendarSync,
                        title: "Календари".tr(currentLang),
                        onTap: () => setStateDialog(() => showCalendars = !showCalendars),
                        isExpanded: showCalendars,
                        trailing: Icon(showCalendars ? LucideIcons.chevronUp : LucideIcons.chevronDown, color: textMuted, size: 18),
                        expandedChild: Column(
                          children: [
                            Divider(color: t.border, height: 17),
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(LucideIcons.calendarDays, color: textColor, size: 22),
                              title: Text("Яндекс.Календарь".tr(currentLang), style: TextStyle(color: textColor, fontWeight: FontWeight.w600)),
                              subtitle: Text("Требует Pro".tr(currentLang), style: TextStyle(color: textMuted, fontSize: 12.5)),
                              trailing: OutlinedButton(
                                style: OutlinedButton.styleFrom(side: BorderSide(color: glassBorderColor), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999))),
                                onPressed: () => ClarifyToast.show(context, "Интеграция скоро будет доступна".tr(currentLang), variant: ClarifyToastVariant.info),
                                child: Text("Подключить".tr(currentLang), style: TextStyle(color: textColor)),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            side: BorderSide(color: t.accent.withValues(alpha: 0.5)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                          ),
                          icon: Icon(LucideIcons.send, color: t.accent, size: 20),
                          label: Text("Поддержка".tr(currentLang), style: TextStyle(color: t.accent, fontWeight: FontWeight.bold)),
                          onPressed: () async {
                            final Uri url = Uri.parse(AppConfig.telegramSupportUrl);
                            if (await canLaunchUrl(url)) {
                              await launchUrl(url, mode: LaunchMode.externalApplication);
                            } else {
                              if (context.mounted) {
                                ClarifyToast.show(context, "Не удалось открыть Telegram".tr(currentLang), variant: ClarifyToastVariant.danger);
                              }
                            }
                          }
                        ),
                      ),

                      const SizedBox(height: 16),

                      TextField(
                        controller: TextEditingController(text: email), style: TextStyle(color: textMuted), enabled: false,
                        decoration: InputDecoration(labelText: "Email", labelStyle: TextStyle(color: textMuted), disabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: glassBorderColor.withValues(alpha: 0.5))), filled: true, fillColor: t.surfaceSunken, isDense: true)
                      ),
                      const SizedBox(height: 24),
                      Divider(color: glassBorderColor),
                      const SizedBox(height: 16),

                      if (!isChangingPassword)
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), side: BorderSide(color: glassBorderColor), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                            icon: Icon(hasPasswordAuth ? LucideIcons.lock : LucideIcons.key, color: textColor, size: 20),
                            label: Text(hasPasswordAuth ? "Изменить пароль".tr(currentLang) : "Установить пароль".tr(currentLang), style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
                            onPressed: () => setStateDialog(() => isChangingPassword = true)
                          ),
                        )
                      else
                        Column(
                          children: [
                            if (hasPasswordAuth) ...[
                              TextField(controller: oldPasswordController, obscureText: true, style: TextStyle(color: textColor), decoration: InputDecoration(labelText: "Текущий пароль".tr(currentLang), labelStyle: TextStyle(color: textMuted), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: glassBorderColor)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: t.accent)), isDense: true)),
                              const SizedBox(height: 12),
                            ],

                            TextField(controller: newPasswordController, obscureText: true, style: TextStyle(color: textColor), decoration: InputDecoration(labelText: "Новый пароль".tr(currentLang), labelStyle: TextStyle(color: textMuted), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: glassBorderColor)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: t.accent)), isDense: true)),
                            const SizedBox(height: 12),
                            TextField(controller: confirmPasswordController, obscureText: true, style: TextStyle(color: textColor), decoration: InputDecoration(labelText: "Подтвердите пароль".tr(currentLang), labelStyle: TextStyle(color: textMuted), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: glassBorderColor)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: t.accent)), isDense: true)),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(child: TextButton(onPressed: () => setStateDialog(() { isChangingPassword = false; oldPasswordController.clear(); newPasswordController.clear(); confirmPasswordController.clear(); }), child: Text("Отмена".tr(currentLang), style: TextStyle(color: textMuted)))),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(backgroundColor: t.accent, foregroundColor: t.onAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(vertical: 14)),
                                    onPressed: isLoading ? null : () async {
                                      final oldPass = oldPasswordController.text;
                                      final newPass = newPasswordController.text;
                                      final confPass = confirmPasswordController.text;

                                      if (newPass != confPass) { ClarifyToast.show(context, 'Новые пароли не совпадают!'.tr(currentLang), variant: ClarifyToastVariant.danger); return; }
                                      if (newPass.length < 6) { ClarifyToast.show(context, 'Минимум 6 символов!'.tr(currentLang), variant: ClarifyToastVariant.danger); return; }

                                      setStateDialog(() => isLoading = true);
                                      try {
                                        if (hasPasswordAuth) {
                                          if (oldPass.isEmpty) { ClarifyToast.show(context, 'Введите текущий пароль!'.tr(currentLang), variant: ClarifyToastVariant.danger); setStateDialog(() => isLoading = false); return; }
                                          if (oldPass == newPass) { ClarifyToast.show(context, 'Новый пароль должен отличаться!'.tr(currentLang), variant: ClarifyToastVariant.warning); setStateDialog(() => isLoading = false); return; }

                                          await Supabase.instance.client.auth.signInWithPassword(email: email, password: oldPass);
                                        }

                                        await Supabase.instance.client.auth.updateUser(UserAttributes(password: newPass));

                                        setStateDialog(() { isChangingPassword = false; oldPasswordController.clear(); newPasswordController.clear(); confirmPasswordController.clear(); });

                                        if (context.mounted) {
                                          ClarifyToast.show(context, hasPasswordAuth ? 'Пароль успешно изменен!'.tr(currentLang) : 'Пароль установлен! Теперь вы можете входить по Email.'.tr(currentLang), variant: ClarifyToastVariant.success);
                                          if (!hasPasswordAuth) Navigator.of(context).pop();
                                        }
                                      } on AuthException catch (e) {
                                        if (context.mounted) {
                                          if (e.message.contains('Invalid login credentials')) {
                                            ClarifyToast.show(context, 'Неверный текущий пароль!'.tr(currentLang), variant: ClarifyToastVariant.danger);
                                          } else {
                                            ClarifyToast.show(context, "${'Ошибка: '.tr(currentLang)}${e.message}", variant: ClarifyToastVariant.danger);
                                          }
                                        }
                                      } catch (e) {
                                        if (context.mounted) ClarifyToast.show(context, "${'Ошибка: '.tr(currentLang)}$e", variant: ClarifyToastVariant.danger);
                                      } finally {
                                        setStateDialog(() => isLoading = false);
                                      }
                                    },
                                    child: Text("Сохранить".tr(currentLang), style: TextStyle(fontWeight: FontWeight.bold))
                                  )
                                ),
                              ]
                            )
                          ]
                        ),

                      const SizedBox(height: 24),

                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: t.dangerSoft, foregroundColor: t.danger, padding: const EdgeInsets.symmetric(vertical: 16), elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: t.danger))),
                          icon: const Icon(LucideIcons.logOut, size: 20),
                          label: Text("Выйти из аккаунта".tr(currentLang), style: TextStyle(fontWeight: FontWeight.bold)),
                          onPressed: () async {
                            if (context.mounted) Navigator.of(context).pop();
                            await Supabase.instance.client.auth.signOut();
                          }
                        ),
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

/// Строка сравнения тарифов Free/Pro. Либо текстовые значения (free/pro),
/// либо галочка/крестик через [freeCheck] — Pro в этом режиме всегда даёт то,
/// чего нет на Free (иначе строка не имела бы смысла в таблице сравнения).
class _PlanRow extends StatelessWidget {
  final String label;
  final String? free;
  final String? pro;
  final bool freeCheck;
  final Color textColor;
  final Color textMuted;
  final Color? accent;
  final Color? danger;

  const _PlanRow({
    required this.label,
    this.free,
    this.pro,
    this.freeCheck = true,
    required this.textColor,
    required this.textMuted,
    this.accent,
    this.danger,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final accentColor = accent ?? t.accent;
    final dangerColor = danger ?? t.danger;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(flex: 3, child: Text(label, style: TextStyle(color: textColor, fontSize: 13))),
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.center,
              child: free != null
                  ? Text(free!, style: TextStyle(color: textMuted, fontSize: 13, fontWeight: FontWeight.w600))
                  : Icon(freeCheck ? LucideIcons.check : LucideIcons.x, size: 16, color: freeCheck ? accentColor : dangerColor),
            ),
          ),
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.center,
              child: pro != null
                  ? Text(pro!, style: TextStyle(color: accentColor, fontSize: 13, fontWeight: FontWeight.w700))
                  : Icon(LucideIcons.check, size: 16, color: accentColor),
            ),
          ),
        ],
      ),
    );
  }
}
