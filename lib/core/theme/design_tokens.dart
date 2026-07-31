import 'package:flutter/material.dart';

/// Цвет/типографика/отступы/движение Clarify.
/// Источник правды: docs/DESIGN_SYSTEM.md — значения ниже обязаны совпадать 1:1.
class ClarifyTokens extends ThemeExtension<ClarifyTokens> {
  final Color bg;
  final Color surface;
  final Color surface2;
  final Color surfaceSunken;
  final Color border;
  final Color borderStrong;
  final Color text;
  final Color text2;
  final Color text3;
  final Color accent;
  final Color accentHover;
  final Color accentSoft;
  final Color onAccent;
  final Color danger;
  final Color dangerSoft;
  final Color warning;
  final Color warningSoft;
  final Color success;
  final Color successSoft;

  /// Назначаемые метки команд/проектов — не системный акцент, выбирается пользователем.
  final List<Color> tagPalette;

  const ClarifyTokens({
    required this.bg,
    required this.surface,
    required this.surface2,
    required this.surfaceSunken,
    required this.border,
    required this.borderStrong,
    required this.text,
    required this.text2,
    required this.text3,
    required this.accent,
    required this.accentHover,
    required this.accentSoft,
    required this.onAccent,
    required this.danger,
    required this.dangerSoft,
    required this.warning,
    required this.warningSoft,
    required this.success,
    required this.successSoft,
    required this.tagPalette,
  });

  static const List<Color> _tagPalette = [
    Color(0xFF4F46E5), // индиго
    Color(0xFF9333EA), // фиолетовый
    Color(0xFFDB2777), // розовый
    Color(0xFF0891B2), // бирюзовый
    Color(0xFF059669), // изумрудный
    Color(0xFFCA8A04), // янтарный
    Color(0xFFEA580C), // терракотовый
    Color(0xFF475569), // сланцевый
  ];

  static const light = ClarifyTokens(
    bg: Color(0xFFF6F6FB),
    surface: Color(0xFFFFFFFF),
    surface2: Color(0xFFFAFAFF),
    surfaceSunken: Color(0xFFEEEEF6),
    border: Color(0x1A1E1B4B),
    borderStrong: Color(0x2E1E1B4B),
    text: Color(0xFF16151F),
    text2: Color(0xFF57566B),
    text3: Color(0xFF8C8BA1),
    accent: Color(0xFF4F46E5),
    accentHover: Color(0xFF4338CA),
    accentSoft: Color(0x174F46E5),
    onAccent: Color(0xFFFFFFFF),
    danger: Color(0xFFDC2626),
    dangerSoft: Color(0x1ADC2626),
    warning: Color(0xFFD97706),
    warningSoft: Color(0x1FD97706),
    // Затемнён с исходного #16A34A — тот не проходил WCAG AA как текст (3.30:1 < 4.5:1).
    success: Color(0xFF15803D),
    successSoft: Color(0x1A15803D),
    tagPalette: _tagPalette,
  );

  static const dark = ClarifyTokens(
    bg: Color(0xFF0A0A10),
    surface: Color(0xFF14141F),
    surface2: Color(0xFF191927),
    surfaceSunken: Color(0xFF0F0F17),
    border: Color(0x14FFFFFF),
    borderStrong: Color(0x29FFFFFF),
    text: Color(0xFFF1F1F7),
    text2: Color(0xFFA6A5BD),
    text3: Color(0xFF6E6D85),
    accent: Color(0xFF818CF8),
    accentHover: Color(0xFFA5ABF6),
    accentSoft: Color(0x24818CF8),
    // Тёмный текст на светлом accent — белый даёт только 2.98:1 (не проходит AA), тёмный даёт 6.29:1.
    onAccent: Color(0xFF14141F),
    danger: Color(0xFFF87171),
    dangerSoft: Color(0x24F87171),
    warning: Color(0xFFFBBF24),
    warningSoft: Color(0x24FBBF24),
    success: Color(0xFF4ADE80),
    successSoft: Color(0x244ADE80),
    tagPalette: _tagPalette,
  );

  @override
  ClarifyTokens copyWith({
    Color? bg,
    Color? surface,
    Color? surface2,
    Color? surfaceSunken,
    Color? border,
    Color? borderStrong,
    Color? text,
    Color? text2,
    Color? text3,
    Color? accent,
    Color? accentHover,
    Color? accentSoft,
    Color? onAccent,
    Color? danger,
    Color? dangerSoft,
    Color? warning,
    Color? warningSoft,
    Color? success,
    Color? successSoft,
    List<Color>? tagPalette,
  }) {
    return ClarifyTokens(
      bg: bg ?? this.bg,
      surface: surface ?? this.surface,
      surface2: surface2 ?? this.surface2,
      surfaceSunken: surfaceSunken ?? this.surfaceSunken,
      border: border ?? this.border,
      borderStrong: borderStrong ?? this.borderStrong,
      text: text ?? this.text,
      text2: text2 ?? this.text2,
      text3: text3 ?? this.text3,
      accent: accent ?? this.accent,
      accentHover: accentHover ?? this.accentHover,
      accentSoft: accentSoft ?? this.accentSoft,
      onAccent: onAccent ?? this.onAccent,
      danger: danger ?? this.danger,
      dangerSoft: dangerSoft ?? this.dangerSoft,
      warning: warning ?? this.warning,
      warningSoft: warningSoft ?? this.warningSoft,
      success: success ?? this.success,
      successSoft: successSoft ?? this.successSoft,
      tagPalette: tagPalette ?? this.tagPalette,
    );
  }

  /// Пересчитывает акцент-зависимые поля из одного [accent] — для пресетов
  /// цвета в настройках, без ручного подбора hover/soft/onAccent под каждый.
  ClarifyTokens withAccent(Color accent) {
    return copyWith(
      accent: accent,
      accentHover: Color.lerp(accent, Colors.black, 0.12),
      accentSoft: accent.withOpacity(0.12),
      onAccent: accent.computeLuminance() > 0.45 ? const Color(0xFF14141F) : Colors.white,
    );
  }

  @override
  ClarifyTokens lerp(ThemeExtension<ClarifyTokens>? other, double t) {
    if (other is! ClarifyTokens) return this;
    return ClarifyTokens(
      bg: Color.lerp(bg, other.bg, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surface2: Color.lerp(surface2, other.surface2, t)!,
      surfaceSunken: Color.lerp(surfaceSunken, other.surfaceSunken, t)!,
      border: Color.lerp(border, other.border, t)!,
      borderStrong: Color.lerp(borderStrong, other.borderStrong, t)!,
      text: Color.lerp(text, other.text, t)!,
      text2: Color.lerp(text2, other.text2, t)!,
      text3: Color.lerp(text3, other.text3, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentHover: Color.lerp(accentHover, other.accentHover, t)!,
      accentSoft: Color.lerp(accentSoft, other.accentSoft, t)!,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      dangerSoft: Color.lerp(dangerSoft, other.dangerSoft, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      warningSoft: Color.lerp(warningSoft, other.warningSoft, t)!,
      success: Color.lerp(success, other.success, t)!,
      successSoft: Color.lerp(successSoft, other.successSoft, t)!,
      tagPalette: t < 0.5 ? tagPalette : other.tagPalette,
    );
  }
}

/// Отступы — шкала 4/8. Одинаковы в обеих темах, поэтому не часть ThemeExtension.
class ClarifySpacing {
  ClarifySpacing._();
  static const double s1 = 4;
  static const double s2 = 8;
  static const double s3 = 12;
  static const double s4 = 16;
  static const double s5 = 24;
  static const double s6 = 32;
  static const double s7 = 48;
  static const double s8 = 64;
  static const double s9 = 96;
}

/// Радиусы. Кнопки — всегда [pill], чтобы не плодить несколько визуальных языков.
class ClarifyRadius {
  ClarifyRadius._();
  static const double sm = 8;
  static const double md = 14;
  static const double lg = 20;
  static const double xl = 28;
  static const double pill = 999;

  /// Асимметричный силуэт диалогов/панелей v2 — крупный верх, острый низ
  /// (REDESIGN_V4_PLAN.md §6.1). Не замена [sm]/[md]/[lg]/[xl]/[pill] — те
  /// остаются для карточек/чипов, где уместно равномерное скругление.
  static const double dialogTop = 28;
  static const double dialogBottom = 8;

  /// Готовый силуэт для корневой оболочки модалок (§6.1/§6.3/§9.2) — крупный
  /// верх, острый низ, вместо равномерного [md]/[lg]/[xl] у всех диалогов.
  static const BorderRadius dialogShell = BorderRadius.only(
    topLeft: Radius.circular(dialogTop),
    topRight: Radius.circular(dialogTop),
    bottomLeft: Radius.circular(dialogBottom),
    bottomRight: Radius.circular(dialogBottom),
  );
}

/// Брейкпоинты — дискретные состояния раскладки, а не равномерный масштаб.
/// `_s` (scale-множитель в DesktopPlannerScreen) остаётся только для плавной
/// подгонки шрифта ВНУТРИ одного брейкпоинта, не через весь диапазон 800–3000px.
/// См. docs/REDESIGN_V2_PLAN.md §5.1.
enum ClarifyBreakpoint { mobile, compact, standard, wide }

class ClarifyBreakpoints {
  ClarifyBreakpoints._();
  static const double mobile = 700;
  static const double compact = 1100;
  static const double wide = 1600;

  static ClarifyBreakpoint of(double width) {
    if (width < mobile) return ClarifyBreakpoint.mobile;
    if (width < compact) return ClarifyBreakpoint.compact;
    if (width < wide) return ClarifyBreakpoint.standard;
    return ClarifyBreakpoint.wide;
  }
}

/// Длительности и кривые движения. [spring] — только для одного жеста
/// (отметка задачи выполненной), не для переходов по умолчанию.
class ClarifyMotion {
  ClarifyMotion._();
  static const Duration fast = Duration(milliseconds: 120);
  static const Duration base = Duration(milliseconds: 180);
  static const Duration slow = Duration(milliseconds: 280);
  static const Duration deliberate = Duration(milliseconds: 420);
  // Отметка задачи выполненной — единый темп для ВСЕХ фронтов этого одного
  // жеста разом (заливка чекбокса, зачёркивание, фон строки, полоса
  // приоритета): по прямому запросу пользователя это должно ощущаться как
  // одно связное движение, а не гонка нескольких анимаций на разной
  // скорости — раньше именно это и было (base=180мс на одних элементах,
  // ничего на других).
  static const Duration completion = Duration(milliseconds: 900);
  static const Curve standard = Cubic(0.2, 0.7, 0.3, 1.0);
  static const Curve spring = Cubic(0.34, 1.56, 0.64, 1.0);
}

/// Пресеты акцента в настройках — фиксированный набор, не произвольный
/// color-picker, чтобы каждый пресет был заведомо проверен на контраст
/// через [ClarifyTokens.withAccent]. Индекс 0 — индиго по умолчанию,
/// совпадает с [ClarifyTokens.light]/[ClarifyTokens.dark].accent.
class ClarifyAccentPresets {
  ClarifyAccentPresets._();

  static const List<Color> values = [
    Color(0xFF4F46E5), // индиго (дефолт)
    Color(0xFF9333EA), // фиолетовый
    Color(0xFFDB2777), // розовый
    Color(0xFF0891B2), // бирюзовый
    Color(0xFF059669), // изумрудный
    Color(0xFFEA580C), // терракотовый
  ];
}

extension ClarifyThemeX on BuildContext {
  /// Короткий доступ к токенам: `context.tokens.accent`.
  ClarifyTokens get tokens => Theme.of(this).extension<ClarifyTokens>()!;
}

/// Типографическая сигнатура v2 — новые пресеты поверх шкалы из
/// DESIGN_SYSTEM.md §3 (не замена Unbounded/Golos Text), см.
/// REDESIGN_V4_PLAN.md §6.1. На этом этапе никуда не подключены.
class ClarifyTypeSignature {
  ClarifyTypeSignature._();

  /// Табличные цифры — даты, счётчики, стрики не «прыгают» по ширине при
  /// обновлении значения. Накладывается поверх любого [base].
  static TextStyle tabular(TextStyle base) {
    return base.copyWith(
      fontFeatures: [
        ...?base.fontFeatures,
        const FontFeature.tabularFigures(),
      ],
    );
  }

  /// Крупный заголовок ритуальных экранов — резче трекинг, чем H1 из
  /// DESIGN_SYSTEM.md (-0.02em вместо -0.005em), для более выразительного
  /// скачка масштаба между «мелким» и «крупным» на ключевых экранах.
  static const TextStyle heroHeading = TextStyle(
    fontFamily: 'Unbounded',
    fontSize: 44,
    height: 1.05,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.02 * 44,
  );

  /// Лейбл метаданных (статус, категория, дата секции) — капс + разрядка,
  /// повторяющаяся деталь по интерфейсу. Текст переводится в верхний регистр
  /// в месте использования (регистр не задаётся стилем).
  static const TextStyle metaLabel = TextStyle(
    fontFamily: 'Golos Text',
    fontSize: 11,
    height: 1.3,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.08 * 11,
  );
}
