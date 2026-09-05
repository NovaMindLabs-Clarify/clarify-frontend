import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/config.dart';
import '../core/localization.dart';
import '../core/theme/design_tokens.dart';
import '../services/update_service.dart';
import 'clarify_button.dart';
import 'clarify_mark.dart';
import 'vantra_endorsement.dart';

/// Экран «О приложении».
///
/// Появился вместе с фирменным стилем. По гайду VANTRA бренд-родитель на
/// территории продукта не показывается НИГДЕ — ни в сайдбаре, ни в настройках,
/// ни в пустых состояниях. Ровно одно исключение: этот экран. Значит, без него
/// эндорсменту студии просто негде жить.
///
/// Здесь же версия сборки — до этого узнать, какая версия установлена, из
/// самого приложения было нельзя, и на вопрос «что у тебя стоит» человек не мог
/// ответить.
class AboutScreen extends StatefulWidget {
  final String currentLang;
  final double scale;

  const AboutScreen({super.key, required this.currentLang, this.scale = 1.0});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  String? _version;

  @override
  void initState() {
    super.initState();
    UpdateService.currentVersion().then((v) {
      if (mounted) setState(() => _version = v);
    });
  }

  Future<void> _open(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  /// Масштаб по ТЕКУЩЕЙ ширине, а не по десктопному окну.
  ///
  /// Экран общий для ПК и телефона, а `scale` приходит из
  /// DesktopPlannerScreen, где считается как ширина/1920 и на телефоне упирается
  /// в нижнюю границу 0.4 — весь текст становился в два с половиной раза
  /// мельче задуманного. Та же ошибка была в корзине и поймана живым фидбеком
  /// 06.09.2026.
  double _scaleFor(double width) => width < 700 ? 1.0 : widget.scale;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final s = _scaleFor(MediaQuery.sizeOf(context).width);

    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(24 * s),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Знак цветом текста, а не акцентом: акцент принадлежит действиям.
            ClarifyMark(size: 72 * s, color: t.text),
            SizedBox(height: 18 * s),
            Text(
              'Clarify',
              style: TextStyle(
                fontFamily: 'Unbounded',
                fontSize: 28 * s,
                fontWeight: FontWeight.w700,
                color: t.text,
              ),
            ),
            SizedBox(height: 6 * s),
            Text(
              'Планировщик задач'.tr(widget.currentLang),
              style: TextStyle(fontSize: 14 * s, color: t.text3),
            ),
            SizedBox(height: 16 * s),
            Text(
              // Пока версия не прочитана — прочерк, а не «1.0.0» заглушкой:
              // неверная версия хуже отсутствующей, по ней принимают решения.
              _version == null
                  ? '—'
                  : '${'Версия'.tr(widget.currentLang)} $_version',
              style: TextStyle(
                fontSize: 13 * s,
                color: t.text3,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),

            SizedBox(height: 28 * s),
            // Единственное место во всём приложении, где показывается бренд
            // студии (BRAND.md §4).
            VantraEndorsement(
              scale: s,
              onTap: () => _open(AppConfig.siteUrl),
            ),

            SizedBox(height: 28 * s),
            Wrap(
              spacing: 10 * s,
              runSpacing: 10 * s,
              alignment: WrapAlignment.center,
              children: [
                ClarifyButton(
                  label: 'Поддержка'.tr(widget.currentLang),
                  icon: LucideIcons.messageCircle,
                  scale: s,
                  onPressed: () => _open(AppConfig.telegramSupportUrl),
                ),
                ClarifyButton(
                  label: 'Сайт'.tr(widget.currentLang),
                  icon: LucideIcons.globe,
                  scale: s,
                  onPressed: () => _open(AppConfig.siteUrl),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
