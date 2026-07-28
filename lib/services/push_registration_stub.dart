/// Заглушка для платформ без `dart:html` (десктоп) — там push-уведомления
/// не нужны, у Windows-версии свой контур (Timer-будильники, см.
/// desktop_planner_screen.dart:_scheduleTaskAlarms). См. push_registration.dart
/// за условным экспортом.
class PushRegistrationWeb {
  static Future<String?> register(String vapidPublicKeyBase64Url) async {
    return 'Push-уведомления доступны только в браузерной версии (PWA)';
  }

  static Future<String?> unregister() async => null;
}
