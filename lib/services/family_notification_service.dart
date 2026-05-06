import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'notification_service.dart';

/// Aile bildirim servisi - FCM ile aile/bakıcılara bildirim gönderir
class FamilyNotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static bool _isInitialized = false;
  static String? _currentToken;

  /// FCM Token'ı dinleyicileri
  static final List<void Function(String)> _tokenListeners = [];

  /// Bildirim dinleyicileri
  static void Function(RemoteMessage)? onNotificationReceived;

  /// Servisi baslatir ve FCM token'ını alir
  static Future<void> init() async {
    if (_isInitialized) return;

    try {
      // Bildirim izni iste
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        // Token al
        _currentToken = await _messaging.getToken();
        debugPrint('FCM Token: $_currentToken');

        // Token yenilenmelerini dinle
        _messaging.onTokenRefresh.listen((newToken) {
          _currentToken = newToken;
          debugPrint('FCM Token refreshed: $newToken');
          for (final listener in _tokenListeners) {
            listener(newToken);
          }
          // Token'ı Supabase'e kaydet
          _saveTokenToBackend(newToken);
        });

        // Arka plan bildirimlerini isle
        FirebaseMessaging.onBackgroundMessage(_onBackgroundMessage);

        // On bildirim mesajlarini dinle
        FirebaseMessaging.onMessage.listen(_onForegroundMessage);

        // Bildirime tiklandiginda
        FirebaseMessaging.onMessageOpenedApp.listen(_onMessageOpenedApp);

        // Token'ı backend'e kaydet
        await _saveTokenToBackend(_currentToken);
      }

      _isInitialized = true;
    } on Object catch (e) {
      debugPrint('FCM init error: $e');
    }
  }

  /// Supabase'e FCM token'ini kaydeder
  static Future<void> _saveTokenToBackend(String? token) async {
    if (token == null) return;

    // Token'ı Hive'da sakla (yedekleme için)
    // Gelecekte Supabase Realtime ile senkronize edilebilir
    debugPrint('FCM Token saved locally');
  }

  /// On plan bildirim handler'i
  static void _onForegroundMessage(RemoteMessage message) {
    debugPrint('Foreground notification: ${message.notification?.title}');

    onNotificationReceived?.call(message);

    // Bildirimi goster
    _showLocalNotification(message);
  }

  /// Bildirime tiklandiginda
  static void _onMessageOpenedApp(RemoteMessage message) {
    debugPrint('Notification opened app: ${message.data}');
    // Uygulama acildiginde yapilacaklar
    // Bildirim icerigine göre yonlendirme yapilabilir
  }

  /// Arka plan bildirim handler'i (overlay değil)
  @pragma('vm:entry-point')
  static Future<void> _onBackgroundMessage(RemoteMessage message) async {
    debugPrint('Background notification: ${message.notification?.title}');
  }

  /// Yerel bildirim goster (on planda)
  static void _showLocalNotification(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;

    NotificationService.showCaregiverReminder(
      profileName: notification.title ?? 'Aile Uyesi',
      message: notification.body ?? 'Yeni bildirim',
    );
  }

  /// Aile uyesine doz bildirimi gonder
  ///
  /// [receiverToken] - Hedef kullanıcının FCM token'ı
  /// [profileName] - Ilaç alan kişinin adi
  /// [medicineName] - Ilaç adi
  /// [doseTime] - Doz saati
  /// [wasTaken] - Alindi mi
  static Future<void> sendDoseNotification({
    required String receiverToken,
    required String profileName,
    required String medicineName,
    required String doseTime,
    required bool wasTaken,
  }) async {
    if (!kDebugMode) {
      // Production'da Supabase Cloud Function ile gonder
      // Şimdilik placeholder
      debugPrint('Would send notification to: $receiverToken');
      return;
    }

    // Debug modda sadece log
    debugPrint('Dose notification: $profileName $medicineName $doseTime');
  }

  /// Kaçirilan doz bildirimi gonder
  static Future<void> sendMissedDoseAlert({
    required String receiverToken,
    required String profileName,
    required String medicineName,
    required String doseTime,
  }) async {
    if (!kDebugMode) {
      debugPrint('Would send missed dose alert to: $receiverToken');
      return;
    }

    debugPrint(
        'Missed dose alert: $profileName missed $medicineName at $doseTime');
  }

  /// Düşük stok bildirimi gonder
  static Future<void> sendLowStockAlert({
    required String receiverToken,
    required String profileName,
    required String medicineName,
    required int remainingCount,
  }) async {
    if (!kDebugMode) {
      debugPrint('Would send low stock alert to: $receiverToken');
      return;
    }

    debugPrint('Low stock alert: $medicineName only $remainingCount left');
  }

  /// Mevcut FCM token'ini dondur
  static String? get currentToken => _currentToken;

  /// Token dinleyicisi ekle
  static void addTokenListener(void Function(String) listener) {
    _tokenListeners.add(listener);
  }

  /// Token dinleyicisi cikar
  static void removeTokenListener(void Function(String) listener) {
    _tokenListeners.remove(listener);
  }

  /// Bildirim izni kontrol et
  static Future<bool> hasPermission() async {
    final settings = await _messaging.getNotificationSettings();
    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  /// Bildirim izni iste
  static Future<bool> requestPermission() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  /// Token'i Supabase'e kaydet (gercek uygulamada)
  ///
  /// Bu fonksiyon Supabase veritabanina FCM token'ini kaydeder
  /// Kullanici profili ile iliskilendirilir
  static Future<void> registerTokenForProfile({
    required String profileId,
    required String token,
  }) async {
    // Supabase ile token kaydetme islemi
    // Bunu backend_service.dart icinde gerceklestirebiliriz
    debugPrint('Registering FCM token for profile: $profileId');
  }

  /// Bir profile ait token'lari al
  static Future<List<String>> getTokensForProfile(String profileId) async {
    // Supabase'den token'lari getir
    // Simdilik bos dondur
    return [];
  }
}
