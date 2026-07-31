/// Заглушка для платформ без `dart:html` (десктоп) — там нет ни статус-бара,
/// ни самого понятия "apple-mobile-web-app-status-bar-style".
class StatusBarStyle {
  static void apply(bool isDark) {}
}
