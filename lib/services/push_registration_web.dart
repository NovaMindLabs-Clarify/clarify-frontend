import 'dart:convert';
import 'dart:html' as html;
import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Регистрация Web Push-подписки (SOCIAL_PLAN.md §4.5) — Service Worker
/// (web/push_sw.js) + PushManager + сохранение подписки в Supabase
/// `push_subscriptions` (сама таблица применяется вручную,
/// backend/clarify-backend/sql/push_subscriptions.sql).
///
/// НЕПРОВЕРЕННОЕ: API dart:html (ServiceWorkerContainer.register,
/// PushManager.subscribe, PushSubscription.getKey) сверены с официальной
/// документацией api.dart.dev, но сам код не запускался в браузере — нет
/// инструмента для этого в среде выполнения, где написан.
class PushRegistrationWeb {
  static Future<String?> register(String vapidPublicKeyBase64Url) async {
    try {
      final serviceWorkerContainer = html.window.navigator.serviceWorker;
      if (serviceWorkerContainer == null) {
        return 'Service Worker не поддерживается браузером';
      }

      final registration = await serviceWorkerContainer.register('/push_sw.js');

      final permission = await html.Notification.requestPermission();
      if (permission != 'granted') {
        return 'Разрешение на уведомления не выдано';
      }

      final pushManager = registration.pushManager;
      if (pushManager == null) {
        return 'Push API не поддерживается этим браузером';
      }

      final applicationServerKey = _urlBase64ToUint8List(vapidPublicKeyBase64Url);
      final subscription = await pushManager.subscribe({
        'userVisibleOnly': true,
        'applicationServerKey': applicationServerKey,
      });

      final endpoint = subscription.endpoint;
      final p256dhBuffer = subscription.getKey('p256dh');
      final authBuffer = subscription.getKey('auth');
      if (endpoint == null || p256dhBuffer == null || authBuffer == null) {
        return 'Не удалось получить ключи подписки';
      }

      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return 'Не авторизован';

      await Supabase.instance.client.from('push_subscriptions').upsert({
        'user_id': user.id,
        'endpoint': endpoint,
        'p256dh': _base64UrlEncode(p256dhBuffer.asUint8List()),
        'auth_key': _base64UrlEncode(authBuffer.asUint8List()),
      }, onConflict: 'endpoint');

      return null; // успех
    } catch (e) {
      return 'Ошибка: $e';
    }
  }

  static Uint8List _urlBase64ToUint8List(String base64String) {
    final padding = '=' * ((4 - base64String.length % 4) % 4);
    final normalized = (base64String + padding).replaceAll('-', '+').replaceAll('_', '/');
    return base64Decode(normalized);
  }

  static String _base64UrlEncode(Uint8List bytes) {
    return base64Url.encode(bytes).replaceAll('=', '');
  }
}
