import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../core/localization.dart';
import '../core/theme/design_tokens.dart';
import '../widgets/clarify_button.dart';
import '../widgets/clarify_illustrations.dart';
import '../main.dart';
import '../widgets/clarify_mark.dart';

/// Онбординг перед авторизацией — сплэш → карусель → welcome с «Войти»/
/// «Создать аккаунт» (REDESIGN_V3_PLAN.md §3.8/5.8). Показывается один раз,
/// флаг `has_seen_onboarding` в Hive `settings` — по образцу `kanban_status`.
///
/// Иллюстрации — процедурные `ClarifyIllustration` (REDESIGN_V4_PLAN.md §6.8),
/// не подобранные извне SVG (unDraw/Storyset и т.п.) — решение принято, чтобы
/// не зависеть от ручной проверки лицензии стороннего ассета.
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
    (illustration: ClarifyIllustrationType.aiSpark, titleKey: 'Онбординг: заголовок 1', descKey: 'Онбординг: описание 1'),
    (illustration: ClarifyIllustrationType.teamOrbit, titleKey: 'Онбординг: заголовок 2', descKey: 'Онбординг: описание 2'),
    (illustration: ClarifyIllustrationType.bellPulse, titleKey: 'Онбординг: заголовок 3', descKey: 'Онбординг: описание 3'),
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClarifyMark(size: 56, color: t.text, decorative: true),
            const SizedBox(height: 16),
            Text('Clarify', style: TextStyle(fontFamily: 'Unbounded', fontSize: 36, fontWeight: FontWeight.w700, color: t.text)),
          ],
        ),
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
            child: ClarifyButton(
              label: 'Пропустить'.tr(widget.currentLang),
              variant: ClarifyButtonVariant.ghost,
              onPressed: _finish,
            ),
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
                    ClarifyIllustration(type: slide.illustration, size: 140),
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
                ClarifyButton(
                  label: 'Назад'.tr(widget.currentLang),
                  variant: ClarifyButtonVariant.ghost,
                  onPressed: () => _pageController.previousPage(duration: ClarifyMotion.slow, curve: ClarifyMotion.standard),
                ),
              const Spacer(),
              ClarifyButton(
                label: (_slideIndex == _slides.length - 1 ? 'Начать' : 'Далее').tr(widget.currentLang),
                variant: ClarifyButtonVariant.filled,
                onPressed: _slideIndex == _slides.length - 1
                    ? _finish
                    : () => _pageController.nextPage(duration: ClarifyMotion.slow, curve: ClarifyMotion.standard),
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
          ClarifyButton(
            label: 'Создать аккаунт'.tr(widget.currentLang),
            variant: ClarifyButtonVariant.filled,
            fullWidth: true,
            onPressed: () => _openAuth(AuthMode.register),
          ),
          const SizedBox(height: 12),
          ClarifyButton(
            label: 'Войти'.tr(widget.currentLang),
            variant: ClarifyButtonVariant.outline,
            fullWidth: true,
            onPressed: () => _openAuth(AuthMode.login),
          ),
        ],
      ),
    );
  }
}
