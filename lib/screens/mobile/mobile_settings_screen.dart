import 'package:flutter/material.dart';
import '../../core/localization.dart';
import '../../core/theme/design_tokens.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// "Настройки" — по образцу Structured: сгруппированный список, а не
/// свалка "Ещё". Статистика — внутри, отдельным пунктом, не в нижней
/// навигации (там ей не хватило бы места среди 4 основных назначений).
class MobileSettingsScreen extends StatelessWidget {
  final String currentLang;
  final String userInitial;
  final String userFullName;
  final bool isDark;
  final VoidCallback onOpenAccountSettings;
  final VoidCallback onOpenStatistics;
  final VoidCallback toggleTheme;
  final Function(String lang) changeLang;

  const MobileSettingsScreen({
    super.key,
    required this.currentLang,
    required this.userInitial,
    required this.userFullName,
    required this.isDark,
    required this.onOpenAccountSettings,
    required this.onOpenStatistics,
    required this.toggleTheme,
    required this.changeLang,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final email = Supabase.instance.client.auth.currentUser?.email ?? '';

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
      children: [
        Text('Настройки'.tr(currentLang), style: TextStyle(fontFamily: 'Golos Text', fontSize: 22, fontWeight: FontWeight.w700, color: t.text)),
        const SizedBox(height: 16),

        Material(
          color: t.surface,
          borderRadius: BorderRadius.circular(ClarifyRadius.md),
          child: InkWell(
            borderRadius: BorderRadius.circular(ClarifyRadius.md),
            onTap: onOpenAccountSettings,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  CircleAvatar(radius: 24, backgroundColor: t.accentSoft, child: Text(userInitial, style: TextStyle(color: t.accent, fontWeight: FontWeight.bold, fontSize: 18))),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(userFullName.isNotEmpty ? userFullName : 'Без имени'.tr(currentLang), style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: t.text)),
                        if (email.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(email, style: TextStyle(fontSize: 12.5, color: t.text3)),
                        ],
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: t.text3),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),

        _SectionLabel(text: 'Обзор'.tr(currentLang)),
        _SettingsTile(icon: Icons.bar_chart_outlined, label: 'Статистика'.tr(currentLang), onTap: onOpenStatistics),

        const SizedBox(height: 20),
        _SectionLabel(text: 'Оформление'.tr(currentLang)),
        _SettingsSwitchTile(
          icon: isDark ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
          label: 'Тёмная тема'.tr(currentLang),
          value: isDark,
          onChanged: (_) => toggleTheme(),
        ),
        _LanguageTile(currentLang: currentLang, changeLang: changeLang),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(text.toUpperCase(), style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: t.text3, letterSpacing: 0.6)),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _SettingsTile({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: t.surface,
        borderRadius: BorderRadius.circular(ClarifyRadius.md),
        child: InkWell(
          borderRadius: BorderRadius.circular(ClarifyRadius.md),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            child: Row(
              children: [
                Icon(icon, size: 20, color: t.text2),
                const SizedBox(width: 12),
                Expanded(child: Text(label, style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: t.text))),
                Icon(Icons.chevron_right, size: 18, color: t.text3),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SettingsSwitchTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _SettingsSwitchTile({required this.icon, required this.label, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        decoration: BoxDecoration(color: t.surface, borderRadius: BorderRadius.circular(ClarifyRadius.md)),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(
          children: [
            Icon(icon, size: 20, color: t.text2),
            const SizedBox(width: 12),
            Expanded(child: Text(label, style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: t.text))),
            Switch(value: value, activeColor: t.accent, onChanged: onChanged),
          ],
        ),
      ),
    );
  }
}

class _LanguageTile extends StatelessWidget {
  final String currentLang;
  final Function(String lang) changeLang;
  const _LanguageTile({required this.currentLang, required this.changeLang});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      decoration: BoxDecoration(color: t.surface, borderRadius: BorderRadius.circular(ClarifyRadius.md)),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Icon(Icons.language, size: 20, color: t.text2),
          const SizedBox(width: 12),
          Expanded(child: Text('Язык'.tr(currentLang), style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: t.text))),
          _LangButton(label: 'RU', active: currentLang == 'ru', onTap: () => changeLang('ru')),
          const SizedBox(width: 6),
          _LangButton(label: 'EN', active: currentLang == 'en', onTap: () => changeLang('en')),
        ],
      ),
    );
  }
}

class _LangButton extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _LangButton({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ClarifyRadius.sm),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: active ? t.accentSoft : Colors.transparent, borderRadius: BorderRadius.circular(ClarifyRadius.sm)),
        child: Text(label, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: active ? t.accent : t.text3)),
      ),
    );
  }
}
