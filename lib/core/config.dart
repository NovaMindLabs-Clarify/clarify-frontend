/// Единая точка конфигурации для значений, которые раньше были россыпью
/// захардкожены по всему коду (см. docs/IMPROVEMENT_PLAN.md, пункт P3.4).
class AppConfig {
  AppConfig._();

  static const String backendBaseUrl =
      'https://clarify-backend-g6np.onrender.com';

  /// Локальный порт, на котором main.dart поднимает временный HttpServer
  /// для перехвата Яндекс OAuth-редиректа.
  static const int yandexOAuthCallbackPort = 8765;
  static const String yandexClientId = '8a185fbf29224afa926cdfc55e78c7ad';

  static const int dailyTaskLimit = 100;

  static const String telegramSupportUrl = 'https://t.me/ClarifyHelp_bot';

  static const Duration zenModeDuration = Duration(minutes: 45);

  static const int burnoutTaskThreshold = 10;

  /// Порог суммарной длительности задач на день (в минутах), после которого
  /// диалог создания/редактирования задачи показывает предупреждение о
  /// загрузке — считается по duration_minutes, до сохранения (в отличие от
  /// burnoutTaskThreshold — тот считает количество задач и всплывает уже
  /// после сохранения).
  static const int dailyLoadWarningMinutes = 6 * 60;

  /// Порог "гниения" задачи (в днях) — невыполненная задача без даты или
  /// просроченная, которую создали дольше этого срока назад, помечается
  /// значком на карточке (список/доска). См. task_rot_tracking.sql —
  /// для задач, созданных до применения той миграции, отсчёт возраста
  /// идёт от момента миграции, а не от настоящей даты создания.
  static const int taskRotDays = 5;

  /// Порог количества переносов даты вперёд, после которого на карточке
  /// показывается значок "перенесено N раз" — см. reschedule_count.
  static const int rescheduleWarningCount = 3;

  /// Публичный ключ VAPID для Web Push (SOCIAL_PLAN.md §4.5) — не секрет (в
  /// отличие от приватного, который живёт только в переменных окружения
  /// backend на Render, см. backend/clarify-backend/PUSH_SETUP.md).
  static const String vapidPublicKey =
      'BE4cKKSz5qpsnfM-3IxlH7n7UFyZSfslZyFnBtxSHux0Rfhbsi5wUb4KoR4yR5HwYW7Y3z9sHjUwPC_R9OcHjdQ';
}
