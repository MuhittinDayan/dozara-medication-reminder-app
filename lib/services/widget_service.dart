import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';

import '../models/dose_log.dart';
import 'hive_service.dart';

/// Ana ekran widget servisi
/// Uygulama verilerini Android/iOS widget'larına aktarır
class WidgetService {
  static const String _appGroupId = 'group.com.dozara.app';
  static const String _androidWidgetName = 'DozaraWidgetReceiver';

  /// Widget'ı başlatır ve günceller
  static Future<void> init() async {
    // iOS için app group
    await HomeWidget.setAppGroupId(_appGroupId);
  }

  /// Widget verilerini günceller
  static Future<void> updateWidget() async {
    try {
      final todayDoses = HiveService.getTodayDoseLogs();

      // Bugünkü bekleyen dozlar
      final pendingDoses = todayDoses
          .where((log) =>
              log.status == DoseStatus.pending ||
              log.status == DoseStatus.snoozed)
          .toList();

      // Sonraki doz
      DoseLog? nextDose;
      if (pendingDoses.isNotEmpty) {
        pendingDoses.sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));
        nextDose = pendingDoses.first;
      }

      // Widget verilerini kaydet
      await HomeWidget.saveWidgetData<String>(
          'next_dose',
          nextDose != null
              ? DateFormat('HH:mm').format(nextDose.scheduledTime)
              : '--:--');

      await HomeWidget.saveWidgetData<String>(
          'medicine_name',
          nextDose != null
              ? HiveService.getMedicine(nextDose.medicineId)?.name ?? 'İlaç'
              : 'Bugün plan yok');

      await HomeWidget.saveWidgetData<String>(
          'pending_count', pendingDoses.length.toString());

      // Widget'ı güncelle
      await HomeWidget.updateWidget(
        name: _androidWidgetName,
        androidName: _androidWidgetName,
        iOSName: 'DozaraWidget',
        qualifiedAndroidName: 'com.dozara.app.$_androidWidgetName',
      );
    } on Object catch (e) {
      debugPrint('Widget update error: $e');
    }
  }

  /// Doz alındığında widget'ı günceller
  static Future<void> onDoseTaken() async {
    await updateWidget();
  }

  /// Belirli aralıklarla widget'ı güncellemek için
  static Future<void> scheduleUpdates() async {
    // Her 15 dakikada bir güncelleme planla
    // Bu genellikle sistem tarafından yönetilir
    await updateWidget();
  }

  /// Uygulama açıldığında veya veri değiştiğinde çağır
  static Future<void> refresh() async {
    await updateWidget();
  }
}
