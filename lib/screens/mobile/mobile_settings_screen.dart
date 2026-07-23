import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
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
                  Icon(LucideIcons.chevronRight, color: t.text3),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),

        _SectionLabel(text: 'Обзор'.tr(currentLang)),
        _SettingsTile(icon: LucideIcons.chartBar, label: 'Статистика'.tr(currentLang), onTap: onOpenStatistics),

        const SizedBox(height: 20),
        _SectionLabel(text: 'Тариф'.tr(currentLang)),
        _SettingsTile(
          icon: LucideIcons.crown,
          label: 'Управление подпиской'.tr(currentLang),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => _PlanPage(currentLang: currentLang))),
        ),

        const SizedBox(height: 20),
        _SectionLabel(text: 'Интеграции'.tr(currentLang)),
        _SettingsTile(
          icon: LucideIcons.calendarSync,
          label: 'Календари'.tr(currentLang),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => _CalendarsPage(currentLang: currentLang))),
        ),

        const SizedBox(height: 20),
        _SectionLabel(text: 'Оформление'.tr(currentLang)),
        _SettingsSwitchTile(
          icon: isDark ? LucideIcons.moon : LucideIcons.sun,
          label: 'Тёмная тема'.tr(currentLang),
          value: isDark,
          onChanged: (_) => toggleTheme(),
        ),
        _LanguageTile(currentLang: currentLang, changeLang: changeLang),
      ],
    );
  }
}

class _PlanPage extends StatelessWidget {
  final String currentLang;
  const _PlanPage({required this.currentLang});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(backgroundColor: t.bg, elevation: 0, foregroundColor: t.text, title: Text('Тариф'.tr(currentLang), style: const TextStyle(fontFamily: 'Golos Text', fontWeight: FontWeight.w700))),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: t.accentSoft, borderRadius: BorderRadius.circular(999)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(LucideIcons.crown, size: 14, color: t.accent),
              const SizedBox(width: 6),
              Text('Текущий тариф: Free'.tr(currentLang), style: TextStyle(color: t.accent, fontSize: 12.5, fontWeight: FontWeight.w700)),
            ]),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: t.surface, borderRadius: BorderRadius.circular(ClarifyRadius.md)),
            child: Column(children: [
              Row(children: [
                const Expanded(flex: 3, child: SizedBox()),
                Expanded(flex: 2, child: Center(child: Text('Free', style: TextStyle(color: t.text3, fontWeight: FontWeight.w700, fontSize: 12.5)))),
                Expanded(flex: 2, child: Center(child: Text('Pro', style: TextStyle(color: t.accent, fontWeight: FontWeight.w700, fontSize: 12.5)))),
              ]),
              const Divider(height: 20),
              _PlanCompareRow(t: t, label: 'AI-запросы в месяц'.tr(currentLang), free: '50', pro: '∞'),
              _PlanCompareRow(t: t, label: 'Участников в команде'.tr(currentLang), free: '3', pro: '∞'),
              _PlanCompareRow(t: t, label: 'Яндекс.Календарь'.tr(currentLang), free: null, pro: null),
              _PlanCompareRow(t: t, label: 'Расширенная статистика'.tr(currentLang), free: null, pro: null),
            ]),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: t.accent, foregroundColor: t.onAccent, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ClarifyRadius.md))),
              onPressed: () => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Оплата Pro скоро будет доступна'.tr(currentLang)))),
              child: Text('Оформить Pro — 199 ₽/мес'.tr(currentLang), style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanCompareRow extends StatelessWidget {
  final ClarifyTokens t;
  final String label;
  final String? free;
  final String? pro;
  const _PlanCompareRow({required this.t, required this.label, this.free, this.pro});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Expanded(flex: 3, child: Text(label, style: TextStyle(color: t.text, fontSize: 13))),
        Expanded(flex: 2, child: Center(child: free != null ? Text(free!, style: TextStyle(color: t.text3, fontWeight: FontWeight.w600, fontSize: 13)) : Icon(LucideIcons.x, size: 15, color: t.danger))),
        Expanded(flex: 2, child: Center(child: pro != null ? Text(pro!, style: TextStyle(color: t.accent, fontWeight: FontWeight.w700, fontSize: 13)) : Icon(LucideIcons.check, size: 15, color: t.accent))),
      ]),
    );
  }
}

class _CalendarsPage extends StatelessWidget {
  final String currentLang;
  const _CalendarsPage({required this.currentLang});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(backgroundColor: t.bg, elevation: 0, foregroundColor: t.text, title: Text('Календари'.tr(currentLang), style: const TextStyle(fontFamily: 'Golos Text', fontWeight: FontWeight.w700))),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Material(
            color: t.surface,
            borderRadius: BorderRadius.circular(ClarifyRadius.md),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(children: [
                Icon(LucideIcons.calendarDays, color: t.text2, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Яндекс.Календарь'.tr(currentLang), style: TextStyle(color: t.text, fontWeight: FontWeight.w600, fontSize: 14.5)),
                    const SizedBox(height: 2),
                    Text('Требует Pro'.tr(currentLang), style: TextStyle(color: t.text3, fontSize: 12)),
                  ]),
                ),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(side: BorderSide(color: t.border), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999))),
                  onPressed: () => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Интеграция скоро будет доступна'.tr(currentLang)))),
                  child: Text('Подключить'.tr(currentLang), style: TextStyle(color: t.text)),
                ),
              ]),
            ),
          ),
        ],
      ),
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
                Icon(LucideIcons.chevronRight, size: 18, color: t.text3),
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
          Icon(LucideIcons.globe, size: 20, color: t.text2),
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
