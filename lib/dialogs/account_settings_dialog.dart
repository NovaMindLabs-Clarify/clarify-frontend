import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:launch_at_startup/launch_at_startup.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/config.dart';
import '../core/localization.dart';

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
  required Widget Function({
    required Widget child,
    BorderRadius? borderRadius,
    EdgeInsetsGeometry? padding,
    EdgeInsetsGeometry? margin,
    Color? customColor,
  }) buildGlassContainer,
}) {
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

  showDialog(
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
              if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Аватар обновлен!'.tr(currentLang)), backgroundColor: Colors.green));
            } catch (e) {
              if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e'.tr(currentLang)), backgroundColor: Colors.redAccent));
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
            if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Аватарка удалена!'.tr(currentLang)), backgroundColor: Colors.green));
          } catch (e) {
            if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e'.tr(currentLang)), backgroundColor: Colors.redAccent));
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
                            IconButton(icon: Icon(Icons.close, color: textMuted), onPressed: () => Navigator.pop(context))
                        ]
                      ),
                      const SizedBox(height: 24),

                      GestureDetector(
                        onTap: isLoading ? null : () {
                          bool hasAvatar = avatarUrl != null && avatarUrl!.isNotEmpty;
                          showDialog(
                            context: context,
                            builder: (dialogCtx) => AlertDialog(
                              backgroundColor: isDark ? const Color(0xFF2C2C2C) : Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              title: Text("Фото профиля".tr(currentLang), style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
                              content: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  ListTile(
                                    leading: const Icon(Icons.upload, color: Colors.blueAccent),
                                    title: Text("Загрузить новое".tr(currentLang), style: TextStyle(color: textColor)),
                                    onTap: () {
                                      Navigator.pop(dialogCtx);
                                      pickAndUpload();
                                    },
                                  ),
                                  if (hasAvatar) ...[
                                    const Divider(),
                                    ListTile(
                                      leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                      title: Text("Удалить текущее".tr(currentLang), style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
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
                              backgroundColor: isDark ? Colors.black45 : Colors.white54,
                              backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl!) : null,
                              child: avatarUrl == null
                                ? Text(fullName.isNotEmpty ? fullName[0].toUpperCase() : '?', style: TextStyle(fontSize: 32, color: textMuted))
                                : null,
                            ),
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(color: Colors.blueAccent, shape: BoxShape.circle, border: Border.all(color: glassBorderColor, width: 2)),
                              child: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
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
                              decoration: InputDecoration(labelText: "Никнейм".tr(currentLang), labelStyle: TextStyle(color: textMuted), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: glassBorderColor)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.blueAccent)), isDense: true)
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
                                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Имя сохранено!'.tr(currentLang))));
                              } catch (e) {
                                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e'.tr(currentLang)), backgroundColor: Colors.redAccent));
                              } finally {
                                setStateDialog(() => isLoading = false);
                              }
                            },
                            child: Text("Сохранить".tr(currentLang), style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold))
                          )
                        ],
                      ),
                      const SizedBox(height: 16),

                      // --- ПЕРЕКЛЮЧАТЕЛЬ АВТОЗАПУСКА ---
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.rocket_launch, color: textColor, size: 20),
                              const SizedBox(width: 8),
                              Text("Автозапуск с Windows".tr(currentLang), style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          Switch(
                            value: isAutostart,
                            activeColor: Colors.blueAccent,
                            onChanged: (val) async {
                              setStateDialog(() => isAutostart = val);
                              if (val) {
                                await launchAtStartup.enable();
                              } else {
                                await launchAtStartup.disable();
                              }
                            },
                          )
                        ]
                      ),
                      const SizedBox(height: 16),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.language, color: textColor, size: 20),
                              const SizedBox(width: 8),
                              Text("Язык".tr(currentLang), style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          Container(
                            height: 36,
                            decoration: BoxDecoration(
                              color: glassColor,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: glassBorderColor)
                            ),
                            child: ToggleButtons(
                              borderRadius: BorderRadius.circular(12),
                              borderColor: Colors.transparent, selectedBorderColor: Colors.transparent,
                              fillColor: Colors.blueAccent.withOpacity(0.2),
                              selectedColor: Colors.blueAccent, color: textMuted,
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
                          )
                        ]
                      ),
                      const SizedBox(height: 16),

                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            side: BorderSide(color: Colors.blueAccent.withOpacity(0.5)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                          ),
                          icon: const Icon(Icons.telegram, color: Colors.blueAccent, size: 20),
                          label: Text("Поддержка".tr(currentLang), style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold)),
                          onPressed: () async {
                            final Uri url = Uri.parse(AppConfig.telegramSupportUrl);
                            if (await canLaunchUrl(url)) {
                              await launchUrl(url, mode: LaunchMode.externalApplication);
                            } else {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text("Не удалось открыть Telegram".tr(currentLang)), backgroundColor: Colors.redAccent)
                                );
                              }
                            }
                          }
                        ),
                      ),

                      const SizedBox(height: 16),

                      TextField(
                        controller: TextEditingController(text: email), style: TextStyle(color: textMuted), enabled: false,
                        decoration: InputDecoration(labelText: "Email", labelStyle: TextStyle(color: textMuted), disabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: glassBorderColor.withOpacity(0.5))), filled: true, fillColor: isDark ? Colors.black.withOpacity(0.2) : Colors.black.withOpacity(0.05), isDense: true)
                      ),
                      const SizedBox(height: 24),
                      Divider(color: glassBorderColor),
                      const SizedBox(height: 16),

                      if (!isChangingPassword)
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), side: BorderSide(color: glassBorderColor), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                            icon: Icon(hasPasswordAuth ? Icons.lock_outline : Icons.vpn_key_outlined, color: textColor, size: 20),
                            label: Text(hasPasswordAuth ? "Изменить пароль".tr(currentLang) : "Установить пароль".tr(currentLang), style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
                            onPressed: () => setStateDialog(() => isChangingPassword = true)
                          ),
                        )
                      else
                        Column(
                          children: [
                            if (hasPasswordAuth) ...[
                              TextField(controller: oldPasswordController, obscureText: true, style: TextStyle(color: textColor), decoration: InputDecoration(labelText: "Текущий пароль".tr(currentLang), labelStyle: TextStyle(color: textMuted), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: glassBorderColor)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.redAccent.withOpacity(0.5))), isDense: true)),
                              const SizedBox(height: 12),
                            ],

                            TextField(controller: newPasswordController, obscureText: true, style: TextStyle(color: textColor), decoration: InputDecoration(labelText: "Новый пароль".tr(currentLang), labelStyle: TextStyle(color: textMuted), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: glassBorderColor)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.blueAccent)), isDense: true)),
                            const SizedBox(height: 12),
                            TextField(controller: confirmPasswordController, obscureText: true, style: TextStyle(color: textColor), decoration: InputDecoration(labelText: "Подтвердите пароль".tr(currentLang), labelStyle: TextStyle(color: textMuted), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: glassBorderColor)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.blueAccent)), isDense: true)),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(child: TextButton(onPressed: () => setStateDialog(() { isChangingPassword = false; oldPasswordController.clear(); newPasswordController.clear(); confirmPasswordController.clear(); }), child: Text("Отмена".tr(currentLang), style: TextStyle(color: textMuted)))),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(vertical: 14)),
                                    onPressed: isLoading ? null : () async {
                                      final oldPass = oldPasswordController.text;
                                      final newPass = newPasswordController.text;
                                      final confPass = confirmPasswordController.text;

                                      if (newPass != confPass) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Новые пароли не совпадают!'.tr(currentLang)), backgroundColor: Colors.redAccent)); return; }
                                      if (newPass.length < 6) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Минимум 6 символов!'.tr(currentLang)), backgroundColor: Colors.redAccent)); return; }

                                      setStateDialog(() => isLoading = true);
                                      try {
                                        if (hasPasswordAuth) {
                                          if (oldPass.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Введите текущий пароль!'.tr(currentLang)), backgroundColor: Colors.redAccent)); setStateDialog(() => isLoading = false); return; }
                                          if (oldPass == newPass) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Новый пароль должен отличаться!'.tr(currentLang)), backgroundColor: Colors.orangeAccent)); setStateDialog(() => isLoading = false); return; }

                                          await Supabase.instance.client.auth.signInWithPassword(email: email, password: oldPass);
                                        }

                                        await Supabase.instance.client.auth.updateUser(UserAttributes(password: newPass));

                                        setStateDialog(() { isChangingPassword = false; oldPasswordController.clear(); newPasswordController.clear(); confirmPasswordController.clear(); });

                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(hasPasswordAuth ? 'Пароль успешно изменен!'.tr(currentLang) : 'Пароль установлен! Теперь вы можете входить по Email.'.tr(currentLang)), backgroundColor: Colors.green));
                                          if (!hasPasswordAuth) Navigator.of(context).pop();
                                        }
                                      } on AuthException catch (e) {
                                        if (context.mounted) {
                                          if (e.message.contains('Invalid login credentials')) {
                                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Неверный текущий пароль!'.tr(currentLang)), backgroundColor: Colors.redAccent));
                                          } else {
                                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: ${e.message}'.tr(currentLang)), backgroundColor: Colors.redAccent));
                                          }
                                        }
                                      } catch (e) {
                                        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e'.tr(currentLang)), backgroundColor: Colors.redAccent));
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
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent.withOpacity(0.1), foregroundColor: Colors.redAccent, padding: const EdgeInsets.symmetric(vertical: 16), elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Colors.redAccent))),
                          icon: const Icon(Icons.exit_to_app, size: 20),
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
