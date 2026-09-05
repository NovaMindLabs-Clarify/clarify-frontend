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

  /// Сайт студии со страницей Clarify. Запасной адрес, если сервер не сказал,
  /// откуда качать обновление: отправить человека на страницу продукта лучше,
  /// чем не отправить никуда.
  static const String siteUrl = 'https://vantra-labs.github.io';

  static const Duration zenModeDuration = Duration(minutes: 45);

  static const int burnoutTaskThreshold = 10;

  /// Порог суммарной длительности задач на день (в минутах), после которого
  /// диалог создания/редактирования задачи показывает предупреждение о
  /// загрузке — считается по duration_minutes, до сохранения (в отличие от
  /// burnoutTaskThreshold — тот считает количество задач и всплывает уже
  /// после сохранения).
  static const int dailyLoadWarningMinutes = 6 * 60;

  /// Насколько давние ВЫПОЛНЕННЫЕ задачи ещё загружаются с сервера (B3).
  ///
  /// Раньше приложение тянуло вообще все задачи за всю историю при каждом
  /// запуске и при каждом realtime-событии. У активного пользователя за год
  /// накапливаются тысячи — приложение начинает «думать» на пустом месте.
  ///
  /// Год, а не 60 дней, как предлагал аудит: статистика считается на клиенте по
  /// этому же массиву, и у неё есть режим «Год» (выполнено за 12 месяцев) плюс
  /// счётчик серии дней подряд. С 60-дневным окном оба молча показывали бы
  /// неправду — а тихо неверная статистика хуже, чем медленная загрузка.
  /// Сузить окно можно будет тогда же, когда счётчики переедут в SQL — это
  /// вторая половина B3.
  ///
  /// Невыполненные задачи и подзадачи грузятся всегда, независимо от возраста.
  static const int completedTasksWindowDays = 365;

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
