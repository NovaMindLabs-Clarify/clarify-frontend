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

  // Метки команд и проектов — приглушены под тёплую базу (2026-09-04): прежние
  // чистые индиго/фуксия/бирюза светились на бумажном и графитовом фоне как
  // из другого приложения. Это НЕ акцент интерфейса, а именно назначаемые
  // пользователем метки — цвет здесь уместен.
  static const List<Color> _tagPalette = [
    Color(0xFF7A6A52), // табак
    Color(0xFF8A6B7B), // пыльная слива
    Color(0xFFB5654A), // терракота
    Color(0xFF4F6F6B), // полынь
    Color(0xFF6B7F55), // олива
    Color(0xFFB08A3E), // охра
    Color(0xFF6E6A80), // сланец
    Color(0xFF8C5B52), // кирпич
  ];

  // === ПАЛИТРА (переработана 2026-09-04) ===
  //
  // Была: сине-чёрная база плюс акцент #4F46E5. Это дефолтный индиго Tailwind,
  // и связка «тёмно-синий фон + этот индиго + скруглённые блоки» опознаётся как
  // «собрано нейросетью» раньше, чем человек успевает прочитать содержимое.
  // Продукт из-за одной только палитры попадал в общую кучу — живой фидбек:
  // «видел уже два проекта с абсолютно идентичными блочками».
  //
  // Стало: тёплая графитовая база в тёмной теме, тёплая бумага в светлой, и
  // главное — **акцент больше не цвет бренда, а контраст**. accent в тёмной
  // теме это тёплый почти-белый, в светлой — чернильный: заливка кнопки
  // становится инверсией фона, а не пятном фиолетового. Цвет в интерфейсе
  // остаётся только там, где он что-то ЗНАЧИТ: просрочка, перенос, успех.
  //
  // Практическая выгода такого решения: ни один виджет не пришлось трогать —
  // всё, что уже красится через t.accent/t.onAccent, автоматически перешло на
  // контрастную схему.
  static const light = ClarifyTokens(
    bg: Color(0xFFF7F4ED),
    surface: Color(0xFFFFFDF8),
    surface2: Color(0xFFFBF8F1),
    surfaceSunken: Color(0xFFEFEAE0),
    border: Color(0x1A2B2620),
    borderStrong: Color(0x2E2B2620),
    text: Color(0xFF1E1B16),
    text2: Color(0xFF575048),
    text3: Color(0xFF8B8378),
    // Чернила по бумаге вместо цветного акцента.
    accent: Color(0xFF1E1B16),
    accentHover: Color(0xFF322D25),
    accentSoft: Color(0x141E1B16),
    onAccent: Color(0xFFFBF8F1),
    // Смысловые цвета приглушены под тёплую базу: прежние чистые red/amber/green
    // на бумажном фоне выглядели инородно, как из другого набора.
    danger: Color(0xFFB33A2B),
    dangerSoft: Color(0x1AB33A2B),
    warning: Color(0xFF9A6B18),
    warningSoft: Color(0x1F9A6B18),
    success: Color(0xFF4E6B3C),
    successSoft: Color(0x1A4E6B3C),
    tagPalette: _tagPalette,
  );

  static const dark = ClarifyTokens(
    bg: Color(0xFF15130F),
    surface: Color(0xFF1D1A15),
    surface2: Color(0xFF241F19),
    surfaceSunken: Color(0xFF100E0B),
    border: Color(0x1AF2EDE3),
    borderStrong: Color(0x33F2EDE3),
    text: Color(0xFFF2EDE3),
    text2: Color(0xFFA9A093),
    text3: Color(0xFF736B60),
    // Тёплый почти-белый как «акцент»: заливка кнопки — инверсия фона.
    accent: Color(0xFFF2EDE3),
    accentHover: Color(0xFFFFFBF3),
    accentSoft: Color(0x1AF2EDE3),
    onAccent: Color(0xFF15130F),
    danger: Color(0xFFE0614C),
    dangerSoft: Color(0x24E0614C),
    warning: Color(0xFFD9A441),
    warningSoft: Color(0x24D9A441),
    success: Color(0xFF8A9A6B),
    successSoft: Color(0x248A9A6B),
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
      accentSoft: accent.withValues(alpha: 0.12),
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

/// Подсказка при наведении в языке приложения (фидбек 2026-09-03): дефолтный
/// флаттеровский Tooltip — тёмный прямоугольник с системным шрифтом, он
/// читался как «вынужденная мера», а не часть интерфейса. Задаётся темой, а не
/// обёрткой-виджетом: так стилизуются РАЗОМ и наши `Tooltip(...)`, и те, что
/// Flutter рисует сам внутри `IconButton`/`PopupMenuButton` и прочих виджетов,
/// куда мы не дотянулись бы обёрткой.
///
/// Блюра здесь нет намеренно: `TooltipThemeData.decoration` — это обычный
/// `BoxDecoration`, `BackdropFilter` в него не положить, а ради стекла
/// пришлось бы отказаться от темы и вернуться к ручной обёртке в каждом месте.
TooltipThemeData clarifyTooltipTheme(ClarifyTokens t) {
  return TooltipThemeData(
    waitDuration: const Duration(milliseconds: 400),
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    margin: const EdgeInsets.all(4),
    textStyle: TextStyle(
      fontFamily: 'Golos Text',
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: t.text,
      decoration: TextDecoration.none,
    ),
    decoration: BoxDecoration(
      color: t.surface2,
      borderRadius: BorderRadius.circular(ClarifyRadius.md),
      border: Border.all(color: t.border),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.18),
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
      ],
    ),
  );
}

/// Пресеты акцента в настройках — фиксированный набор, не произвольный
/// color-picker, чтобы каждый пресет был заведомо проверен на контраст
/// через [ClarifyTokens.withAccent].
///
/// Индекс 0 — «по умолчанию»: он НЕ применяется через withAccent, а означает
/// штатную контрастную схему из [ClarifyTokens.light]/[dark], где акцент это
/// чернила по бумаге (светлая тема) или тёплый почти-белый (тёмная). Значение
/// в списке нужно только для образца цвета в настройках.
///
/// Остальные пресеты (2026-09-04) приглушены под тёплую базу: прежние чистые
/// индиго/фуксия/бирюза на графитовом и бумажном фоне выглядели как из другого
/// приложения. Возможность выбрать цвет сохранена — убран только крикливый
/// набор.
class ClarifyAccentPresets {
  ClarifyAccentPresets._();

  static const List<Color> values = [
    Color(0xFF2B2620), // по умолчанию — контраст, а не цвет
    Color(0xFF8C5B52), // кирпич
    Color(0xFF7A6A52), // табак
    Color(0xFF4F6F6B), // полынь
    Color(0xFF6B7F55), // олива
    Color(0xFF8A6B7B), // пыльная слива
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
