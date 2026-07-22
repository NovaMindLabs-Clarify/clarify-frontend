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
}
