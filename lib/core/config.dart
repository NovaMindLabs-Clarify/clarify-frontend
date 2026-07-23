/// Единая точка конфигурации для значений, которые раньше были россыпью
/// захардкожены по всему коду (см. docs/IMPROVEMENT_PLAN.md, пункт P3.4).
class AppConfig {
  AppConfig._();

  static const String backendBaseUrl = 'https://clarify-backend-g6np.onrender.com';

  /// Локальный порт, на котором main.dart поднимает временный HttpServer
  /// для перехвата Яндекс OAuth-редиректа.
  static const int yandexOAuthCallbackPort = 8765;
  static const String yandexClientId = '8a185fbf29224afa926cdfc55e78c7ad';

  static const int dailyTaskLimit = 100;

  static const String telegramSupportUrl = 'https://t.me/ClarifyPlan';

  static const Duration zenModeDuration = Duration(minutes: 45);

  static const int burnoutTaskThreshold = 10;

  /// Публичный ключ VAPID для Web Push (SOCIAL_PLAN.md §4.5) — не секрет (в
  /// отличие от приватного, который живёт только в переменных окружения
  /// backend на Render, см. backend/clarify-backend/PUSH_SETUP.md).
  static const String vapidPublicKey =
      'BE4cKKSz5qpsnfM-3IxlH7n7UFyZSfslZyFnBtxSHux0Rfhbsi5wUb4KoR4yR5HwYW7Y3z9sHjUwPC_R9OcHjdQ';
}
