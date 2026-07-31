import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../core/localization.dart';
import '../core/privacy_policy_text.dart';
import '../core/theme/design_tokens.dart';
import '../widgets/clarify_glass.dart';
import '../widgets/clarify_surface.dart';

/// Полный текст политики конфиденциальности — читалка на весь текст.
/// Используется и с экрана согласия при первом входе (PrivacyConsentScreen),
/// и из «Настроек» для повторного просмотра в любой момент.
void showPrivacyPolicyDialog({
  required BuildContext context,
  required bool isDark,
  required String currentLang,
}) {
  final t = isDark ? ClarifyTokens.dark : ClarifyTokens.light;

  Widget buildBody(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Политика конфиденциальности'.tr(currentLang),
                style: TextStyle(
                  color: t.text,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
            IconButton(
              icon: Icon(LucideIcons.x, color: t.text2),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Flexible(
          child: SingleChildScrollView(
            child: MarkdownBody(
              data: currentLang == 'ru' ? kPrivacyPolicyRu : kPrivacyPolicyEn,
              styleSheet: MarkdownStyleSheet(
                h1: TextStyle(
                  color: t.text,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
                h2: TextStyle(
                  color: t.text,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
                p: TextStyle(color: t.text2, fontSize: 14, height: 1.5),
                strong: TextStyle(color: t.text, fontWeight: FontWeight.bold),
                listBullet: TextStyle(color: t.accent),
              ),
            ),
          ),
        ),
      ],
    );
  }

  showClarifyResponsiveSurface(
    context: context,
    builder: (context) {
      if (isClarifyDialogMobile(context)) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            4,
            20,
            MediaQuery.of(context).padding.bottom + 20,
          ),
          child: SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.85,
            child: buildBody(context),
          ),
        );
      }
      return Center(
        child: Material(
          color: Colors.transparent,
          child: ClarifyGlass(
            borderRadius: ClarifyRadius.dialogShell,
            padding: const EdgeInsets.all(24),
            child: SizedBox(
              width: 560,
              height: MediaQuery.sizeOf(context).height * 0.8,
              child: buildBody(context),
            ),
          ),
        ),
      );
    },
  );
}
