/// Заглушка для платформ без `dart:html` (десктоп) — там реальные попапы
/// идёт через `local_notifier`, см. desktop_planner_screen.dart.
class BrowserNotification {
  static bool show(String title, String body) => false;
}
