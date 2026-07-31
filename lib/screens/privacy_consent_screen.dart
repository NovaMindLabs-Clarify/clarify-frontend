import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../core/localization.dart';
import '../core/privacy_policy_text.dart';
import '../core/theme/design_tokens.dart';
import '../dialogs/privacy_policy_dialog.dart';
import '../widgets/clarify_button.dart';
import '../widgets/clarify_glass.dart';
import '../widgets/clarify_task_checkbox.dart';

/// Блокирующий гейт согласия с политикой конфиденциальности — юридически
/// обязателен: приложение запрашивает email/имя/аватар/сообщения, и до этого
/// экрана (см. main.dart, home: ... перед проверкой _isAuthenticated) не
/// должно быть доступно ничего другого. Версия принятой политики хранится в
/// Hive, а не просто bool — при существенном обновлении текста
/// (kPrivacyPolicyVersion) экран покажется заново даже тем, кто уже
/// соглашался с прошлой версией.
class PrivacyConsentScreen extends StatefulWidget {
  final bool isDark;
  final String currentLang;
  final VoidCallback onAccepted;

  const PrivacyConsentScreen({
    super.key,
    required this.isDark,
    required this.currentLang,
    required this.onAccepted,
  });

  @override
  State<PrivacyConsentScreen> createState() => _PrivacyConsentScreenState();
}

class _PrivacyConsentScreenState extends State<PrivacyConsentScreen> {
  bool _agreed = false;

  void _accept() {
    final box = Hive.box('settings');
    box.put('privacy_policy_accepted_version', kPrivacyPolicyVersion);
    box.put('privacy_policy_accepted_at', DateTime.now().toIso8601String());
    widget.onAccepted();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.isDark ? ClarifyTokens.dark : ClarifyTokens.light;
    final lang = widget.currentLang;

    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
            child: SizedBox(
              width: 440,
              child: ClarifyGlass(
                borderRadius: BorderRadius.circular(24),
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(LucideIcons.shieldCheck, size: 44, color: t.accent),
                    const SizedBox(height: 16),
                    Text(
                      'Прежде чем продолжить'.tr(lang),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: t.text,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Clarify хранит ваши задачи, сообщения и данные аккаунта. Ознакомьтесь с политикой конфиденциальности, прежде чем начать пользоваться приложением.'
                          .tr(lang),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: t.text2,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 20),
                    ClarifyButton(
                      label: 'Читать политику полностью'.tr(lang),
                      icon: LucideIcons.fileText,
                      variant: ClarifyButtonVariant.outline,
                      fullWidth: true,
                      onPressed: () => showPrivacyPolicyDialog(
                        context: context,
                        isDark: widget.isDark,
                        currentLang: lang,
                      ),
                    ),
                    const SizedBox(height: 20),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => setState(() => _agreed = !_agreed),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: ClarifyCheckCircle(
                              value: _agreed,
                              onTap: null,
                              borderColor: t.border,
                              checkedColor: t.accent,
                              checkIconColor: t.onAccent,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Я прочитал(а) и принимаю политику конфиденциальности'
                                  .tr(lang),
                              style: TextStyle(color: t.text, fontSize: 13.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    ClarifyButton(
                      label: 'Принять и продолжить'.tr(lang),
                      variant: ClarifyButtonVariant.filled,
                      fullWidth: true,
                      onPressed: _agreed ? _accept : null,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
