import 'dart:html' as html;

/// iOS даёт только 3 статичных варианта apple-mobile-web-app-status-bar-style
/// (default/black/black-translucent), без media-query — "black-translucent"
/// был выбран как компромисс на ОБЕ темы разом, но остаётся системное
/// затемнение iOS поверх этой зоны, которое не убрать (см.
/// docs/COMPETITOR_ANALYSIS_UPDATE_2026-07-31.md — не заводили отдельный
/// пункт, обсуждалось напрямую с пользователем 31.07). Вместо одного
/// компромисса на всё — переключаем сам тег в момент смены темы:
/// "black" (сплошной) на тёмной теме (почти совпадает с #0A0A10 — минимальный
/// шов), "default" (белый) на светлой (почти совпадает с #F6F6FB). Каждая
/// тема получает свой хорошо подходящий вариант вместо одного на все случаи.
class StatusBarStyle {
  static void apply(bool isDark) {
    final meta = html.document.querySelector(
      'meta[name="apple-mobile-web-app-status-bar-style"]',
    );
    meta?.setAttribute('content', isDark ? 'black' : 'default');
  }
}
