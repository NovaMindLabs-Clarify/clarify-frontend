import 'dart:html' as html;

/// Настоящий OS-уровневый попап через браузерный Notification API — вместо
/// `local_notifier` (десктоп-only, на web падает MissingPluginException, см.
/// push_registration.dart:14 в desktop_planner_screen.dart, где раньше это
/// молча уходило в in-app ClarifyToast). Требует разрешения, выданного через
/// PushRegistrationWeb.register (см. mobile_settings_screen.dart).
class BrowserNotification {
  static bool show(String title, String body) {
    if (!html.Notification.supported) return false;
    if (html.Notification.permission != 'granted') return false;
    html.Notification(title, body: body);
    return true;
  }
}
