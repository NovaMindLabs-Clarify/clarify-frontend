import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Плоский доступ к пользовательским настройкам (Hive-бокс `settings`,
/// открыт в main.dart до runApp). [accentPresetIndex]/[reducedMotionOverride]
/// — ValueNotifier, а не просто значения в боксе: диалог настроек аккаунта
/// не имеет доступа к состоянию _SmartPlannerAppState и не может вызвать его
/// setState напрямую, поэтому MaterialApp в main.dart сам подписывается на
/// эти нотифаеры через ValueListenableBuilder.
class AppSettings {
  AppSettings._();

  static Box get _box => Hive.box('settings');

  static bool get notificationsEnabled => _box.get('notifications_enabled', defaultValue: true) as bool;
  static set notificationsEnabled(bool value) => _box.put('notifications_enabled', value);

  /// Реальная push-подписка (web Notification/PushManager) — отдельно от
  /// [notificationsEnabled] (общий гейт локальных алармов, default true).
  /// Default false: подписки не существует, пока пользователь явно не
  /// включит её (PushRegistrationWeb.register) и браузер не выдаст
  /// разрешение — в отличие от notificationsEnabled, тут "включено по
  /// умолчанию" было бы неверно и приводило к тому, что первый тап по
  /// объединённому переключателю в настройках выключал его вместо запроса
  /// разрешения (см. mobile_settings_screen.dart).
  static bool get pushSubscribed => _box.get('push_subscribed', defaultValue: false) as bool;
  static set pushSubscribed(bool value) => _box.put('push_subscribed', value);

  static int get zenDurationMinutes => _box.get('zen_duration_minutes', defaultValue: 45) as int;
  static set zenDurationMinutes(int value) => _box.put('zen_duration_minutes', value);

  static bool get dailyReviewEnabled => _box.get('daily_review_enabled', defaultValue: true) as bool;
  static set dailyReviewEnabled(bool value) => _box.put('daily_review_enabled', value);

  /// Дата (YYYY-MM-DD), для которой уже показывался "ежедневный обзор" —
  /// раньше хранилась только в памяти (поле State), поэтому на мобильном
  /// PWA, где браузер/ОС часто убивает вкладку в фоне и пересоздаёт State
  /// заново, обзор фактически показывался при КАЖДОМ заходе в приложение
  /// вместо одного раза в день. Персист в Hive переживает пересоздание
  /// процесса.
  static String? get lastDailyReviewDate => _box.get('last_daily_review_date') as String?;
  static set lastDailyReviewDate(String? value) => _box.put('last_daily_review_date', value);

  static String get quickAddDefaultPriority => _box.get('quick_add_default_priority', defaultValue: 'none') as String;
  static set quickAddDefaultPriority(String value) => _box.put('quick_add_default_priority', value);

  static String get quickAddDefaultRecurrence => _box.get('quick_add_default_recurrence', defaultValue: 'none') as String;
  static set quickAddDefaultRecurrence(String value) => _box.put('quick_add_default_recurrence', value);

  static bool get closeToTray => _box.get('close_to_tray', defaultValue: true) as bool;
  static set closeToTray(bool value) => _box.put('close_to_tray', value);

  static bool get aiOnboardingSeen => _box.get('ai_onboarding_seen', defaultValue: false) as bool;
  static set aiOnboardingSeen(bool value) => _box.put('ai_onboarding_seen', value);

  static final ValueNotifier<int> accentPresetIndex = ValueNotifier<int>(
    Hive.box('settings').get('accent_preset', defaultValue: 0) as int,
  );
  static void setAccentPresetIndex(int value) {
    accentPresetIndex.value = value;
    _box.put('accent_preset', value);
  }

  static final ValueNotifier<bool> reducedMotionOverride = ValueNotifier<bool>(
    Hive.box('settings').get('reduced_motion_override', defaultValue: false) as bool,
  );
  static void setReducedMotionOverride(bool value) {
    reducedMotionOverride.value = value;
    _box.put('reduced_motion_override', value);
  }
}
