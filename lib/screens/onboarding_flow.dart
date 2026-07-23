import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../core/localization.dart';
import '../core/theme/design_tokens.dart';
import '../main.dart';

/// Онбординг перед авторизацией — сплэш → карусель → welcome с «Войти»/
/// «Создать аккаунт» (REDESIGN_V3_PLAN.md §3.8/5.8). Показывается один раз,
/// флаг `has_seen_onboarding` в Hive `settings` — по образцу `kanban_status`.
///
/// НЕИЗВЕСТНОЕ/НЕПРОВЕРЕННОЕ: иллюстрации — цветные Lucide-иконки в круге, а
/// не подобранные извне SVG (unDraw/Storyset и т.п., см. §4 плана) — подбор
/// конкретных файлов требует ручной проверки лицензии пользователем, не
/// выполнялся автономно в рамках этого прохода.
class OnboardingFlow extends StatefulWidget {
  final bool isDark;
  final VoidCallback toggleTheme;
  final String currentLang;
  final Function(String) changeLang;

  const OnboardingFlow({super.key, required this.isDark, required this.toggleTheme, required this.currentLang, required this.changeLang});

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

enum _OnboardingStage { splash, slides, welcome }

class _OnboardingFlowState extends State<OnboardingFlow> with SingleTickerProviderStateMixin {
  _OnboardingStage _stage = _OnboardingStage.splash;
  final PageController _pageController = PageController();
  int _slideIndex = 0;
  late final AnimationController _splashController;

  static const _slides = [
    (icon: LucideIcons.sparkles, titleKey: 'Онбординг: заголовок 1', descKey: 'Онбординг: описание 1'),
    (icon: LucideIcons.usersRound, titleKey: 'Онбординг: заголовок 2', descKey: 'Онбординг: описание 2'),
    (icon: LucideIcons.bellRing, titleKey: 'Онбординг: заголовок 3', descKey: 'Онбординг: описание 3'),
  ];

  @override
  void initState() {
    super.initState();
    _splashController = AnimationController(vsync: this, duration: ClarifyMotion.deliberate)..forward();
    Future.delayed(const Duration(milliseconds: 1400), () {
      if (mounted) setState(() => _stage = _OnboardingStage.slides);
    });
  }

  @override
  void dispose() {
    _splashController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    final box = Hive.box('settings');
    await box.put('has_seen_onboarding', true);
    if (mounted) setState(() => _stage = _OnboardingStage.welcome);
  }

  void _openAuth(AuthMode mode) {
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => AuthScreen(isDark: widget.isDark, toggleTheme: widget.toggleTheme, currentLang: widget.currentLang, changeLang: widget.changeLang, initialMode: mode),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.isDark ? ClarifyTokens.dark : ClarifyTokens.light;

    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: ClarifyMotion.slow,
          child: switch (_stage) {
            _OnboardingStage.splash => _buildSplash(t),
            _OnboardingStage.slides => _buildSlides(t),
            _OnboardingStage.welcome => _buildWelcome(t),
          },
        ),
      ),
    );
  }

  Widget _buildSplash(ClarifyTokens t) {
    return Center(
      key: const ValueKey('splash'),
      child: FadeTransition(
        opacity: _splashController,
        child: Text('Clarify', style: TextStyle(fontFamily: 'Unbounded', fontSize: 36, fontWeight: FontWeight.w700, color: t.text)),
      ),
    );
  }

  Widget _buildSlides(ClarifyTokens t) {
    return Column(
      key: const ValueKey('slides'),
      children: [
        Align(
          alignment: Alignment.topRight,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: TextButton(onPressed: _finish, child: Text('Пропустить'.tr(widget.currentLang), style: TextStyle(color: t.text3))),
          ),
        ),
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            itemCount: _slides.length,
            onPageChanged: (i) => setState(() => _slideIndex = i),
            itemBuilder: (context, index) {
              final slide = _slides[index];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(color: t.accentSoft, shape: BoxShape.circle),
                      child: Icon(slide.icon, size: 56, color: t.accent),
                    ),
                    const SizedBox(height: 40),
                    Text(slide.titleKey.tr(widget.currentLang), textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Unbounded', fontSize: 22, fontWeight: FontWeight.w700, color: t.text)),
                    const SizedBox(height: 12),
                    Text(slide.descKey.tr(widget.currentLang), textAlign: TextAlign.center, style: TextStyle(fontSize: 15, color: t.text2, height: 1.5)),
                  ],
                ),
              );
            },
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(_slides.length, (i) => AnimatedContainer(
                duration: ClarifyMotion.base,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: i == _slideIndex ? 20 : 6,
                height: 6,
                decoration: BoxDecoration(color: i == _slideIndex ? t.accent : t.border, borderRadius: BorderRadius.circular(3)),
              )),
        ),
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Row(
            children: [
              if (_slideIndex > 0)
                TextButton(
                  onPressed: () => _pageController.previousPage(duration: ClarifyMotion.slow, curve: ClarifyMotion.standard),
                  child: Text('Назад'.tr(widget.currentLang), style: TextStyle(color: t.text2)),
                ),
              const Spacer(),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: t.accent, foregroundColor: t.onAccent, padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ClarifyRadius.pill))),
                onPressed: _slideIndex == _slides.length - 1
                    ? _finish
                    : () => _pageController.nextPage(duration: ClarifyMotion.slow, curve: ClarifyMotion.standard),
                child: Text((_slideIndex == _slides.length - 1 ? 'Начать' : 'Далее').tr(widget.currentLang), style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWelcome(ClarifyTokens t) {
    return Padding(
      key: const ValueKey('welcome'),
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Clarify', style: TextStyle(fontFamily: 'Unbounded', fontSize: 32, fontWeight: FontWeight.w700, color: t.text), textAlign: TextAlign.center),
          const SizedBox(height: 12),
          Text('Планируйте день, работайте в команде, ничего не забывайте.'.tr(widget.currentLang), textAlign: TextAlign.center, style: TextStyle(fontSize: 15, color: t.text2, height: 1.5)),
          const SizedBox(height: 48),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: t.accent, foregroundColor: t.onAccent, padding: const EdgeInsets.symmetric(vertical: 18), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ClarifyRadius.pill))),
            onPressed: () => _openAuth(AuthMode.register),
            child: Text('Создать аккаунт'.tr(widget.currentLang), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            style: OutlinedButton.styleFrom(side: BorderSide(color: t.border), padding: const EdgeInsets.symmetric(vertical: 18), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ClarifyRadius.pill))),
            onPressed: () => _openAuth(AuthMode.login),
            child: Text('Войти'.tr(widget.currentLang), style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: t.text)),
          ),
        ],
      ),
    );
  }
}
