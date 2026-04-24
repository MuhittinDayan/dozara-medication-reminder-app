import 'dart:ui';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../models/dose_log.dart';
import '../models/medicine.dart';
import 'hive_service.dart';
import 'voice_reminder_service.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) {
      return;
    }

    tz_data.initializeTimeZones();

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      settings,
      onDidReceiveNotificationResponse: _onNotificationResponse,
    );

    await _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    _initialized = true;
  }

  static int _notificationId(String doseLogId) =>
      doseLogId.hashCode.abs() % 1000000000;

  static int _missedNotificationId(String doseLogId) =>
      (_notificationId(doseLogId) + 1000000000) % 2147483647;

  static void _onNotificationResponse(NotificationResponse response) {
    _handleNotificationResponse(response);
  }

  static Future<void> _handleNotificationResponse(
    NotificationResponse response,
  ) async {
    final doseLogId = response.payload;
    if (doseLogId == null || doseLogId.isEmpty) {
      return;
    }

    switch (response.actionId) {
      case 'taken':
        await HiveService.markDoseAsTaken(doseLogId);
        break;
      case 'snooze':
        final snoozedLog = await HiveService.snoozeDose(doseLogId);
        if (snoozedLog != null) {
          await scheduleDoseLogNotifications(snoozedLog);
        }
        break;
      case 'skip':
        await HiveService.markDoseAsMissed(doseLogId);
        break;
      default:
        break;
    }
  }

  static Future<void> scheduleDoseLogNotifications(DoseLog doseLog) async {
    final medicine = HiveService.getMedicine(doseLog.medicineId);
    if (medicine == null || doseLog.status != DoseStatus.pending) {
      return;
    }

    if (!HiveService.isAlarmEnabled(
      medicine.id,
      _timeString(doseLog.scheduledTime),
    )) {
      return;
    }

    if (doseLog.scheduledTime.isBefore(DateTime.now())) {
      return;
    }

    final tzScheduled = tz.TZDateTime.from(doseLog.scheduledTime, tz.local);
    final baseId = _notificationId(doseLog.id);

    await _notifications.zonedSchedule(
      baseId,
      '${medicine.formEmoji} ${medicine.name}',
      _doseReminderBody(medicine),
      tzScheduled,
      _notificationDetails(),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: doseLog.id,
    );

    final missedId = _missedNotificationId(doseLog.id);
    await _notifications.zonedSchedule(
      missedId,
      '${medicine.name} dozu onay bekliyor',
      'Ilacinizi hala almadinizsa kontrol edin.',
      tzScheduled.add(const Duration(minutes: 30)),
      _notificationDetails(isWarning: true),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: doseLog.id,
    );
  }

  static String _doseReminderBody(Medicine medicine) {
    final parts = <String>['Ilac alma zamani geldi'];

    if (medicine.dosage != null && medicine.dosage!.trim().isNotEmpty) {
      parts.add('Doz: ${medicine.dosage!.trim()}');
    }

    if (medicine.withFood) {
      parts.add('Tok karnina');
    }

    return parts.join(' • ');
  }

  static Future<void> scheduleMedicineNotifications(
    Medicine medicine, {
    int daysAhead = 30,
  }) async {
    final now = DateTime.now();
    final horizon = now.add(Duration(days: daysAhead));
    final doseLogs = HiveService.getDoseLogsForMedicine(medicine.id).where(
      (log) =>
          log.status == DoseStatus.pending &&
          !log.scheduledTime.isBefore(now) &&
          log.scheduledTime.isBefore(horizon),
    );

    for (final doseLog in doseLogs) {
      await scheduleDoseLogNotifications(doseLog);
    }
  }

  static Future<void> rescheduleAllNotifications({int daysAhead = 30}) async {
    await cancelAllNotifications();

    final pendingLogs =
        HiveService.getPendingFutureDoseLogs(daysAhead: daysAhead);
    for (final log in pendingLogs) {
      await scheduleDoseLogNotifications(log);
    }

    await scheduleDailySummary();
  }

  static Future<void> cancelDoseNotifications(String doseLogId) async {
    await _notifications.cancel(_notificationId(doseLogId));
    await _notifications.cancel(_missedNotificationId(doseLogId));
  }

  static Future<void> showLowStockWarning(Medicine medicine) async {
    await _notifications.show(
      medicine.id.hashCode,
      'Stok Uyarisi: ${medicine.name}',
      'Sadece ${medicine.stockCount} adet ${medicine.formName} kaldi.',
      _notificationDetails(isWarning: true),
    );
  }

  static Future<void> showCaregiverReminder({
    required String profileName,
    required String message,
  }) async {
    await _notifications.show(
      profileName.hashCode.abs() % 1000000000,
      '$profileName icin ilac hatirlatmasi',
      message,
      _notificationDetails(isWarning: true),
    );
  }

  static Future<void> scheduleDailySummary() async {
    final now = DateTime.now();
    var scheduledDate = DateTime(now.year, now.month, now.day, 20, 0);

    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    final tzDate = tz.TZDateTime.from(scheduledDate, tz.local);

    await _notifications.zonedSchedule(
      999999,
      'Gunluk Ozet',
      'Bugunku ilac durumunuzu gormek icin dokunun.',
      tzDate,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'daily_summary',
          'Gunluk Ozetler',
          channelDescription: 'Her aksam gelen ilac ozeti',
          importance: Importance.low,
          priority: Priority.low,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  static Future<void> cancelMedicineNotifications(Medicine medicine) async {
    final logs = HiveService.getDoseLogsForMedicine(medicine.id);
    for (final log in logs) {
      await cancelDoseNotifications(log.id);
    }
  }

  static Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
  }

  static Future<List<PendingNotificationRequest>> getPendingNotifications() {
    return _notifications.pendingNotificationRequests();
  }

  static Future<void> speakReminderPreview(
    Medicine medicine, {
    String? doseLabel,
    bool force = false,
  }) {
    return VoiceReminderService.speakReminder(
      medicine.name,
      doseLabel: doseLabel,
      force: force,
    );
  }

  static Future<void> stopReminderPreview() {
    return VoiceReminderService.stop();
  }

  static NotificationDetails _notificationDetails({bool isWarning = false}) {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        isWarning ? 'warning_channel' : 'ilac_hatirlatici_channel',
        isWarning ? 'Uyarilar' : 'Ilac Hatirlatici',
        channelDescription: 'Ilac alma zamani ve stok bildirimleri',
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
        enableVibration: HiveService.getNotificationVibrationEnabled(),
        playSound: true,
        icon: '@mipmap/ic_launcher',
        largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
        styleInformation: const BigTextStyleInformation(''),
        color: isWarning ? const Color(0xFFD32F2F) : const Color(0xFF7C3AED),
        actions: isWarning
            ? null
            : const <AndroidNotificationAction>[
                AndroidNotificationAction(
                  'taken',
                  'Aldim',
                  showsUserInterface: true,
                ),
                AndroidNotificationAction(
                  'snooze',
                  '15 dk ertele',
                  showsUserInterface: true,
                ),
                AndroidNotificationAction(
                  'skip',
                  'Atla',
                  showsUserInterface: true,
                ),
              ],
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );
  }

  static Future<void> showTestNotification() async {
    await _notifications.show(
      0,
      'Test Bildirimi',
      'Ilac hatirlatici bildirimleri calisiyor.',
      _notificationDetails(),
    );
  }

  static String _timeString(DateTime value) {
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
