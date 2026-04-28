import 'package:flutter/material.dart';
import '../models/medicine.dart';
import '../services/ai_service.dart';

class MedicineFormHelper {
  static String localizedFormEmoji(MedicineForm form) {
    switch (form) {
      case MedicineForm.pill:
        return '💊';
      case MedicineForm.syrup:
        return '🥤';
      case MedicineForm.injection:
        return '💉';
      case MedicineForm.drop:
        return '💧';
      case MedicineForm.cream:
        return '🧴';
      case MedicineForm.inhaler:
        return '💨';
    }
  }

  static String localizedFormName(MedicineForm form) {
    switch (form) {
      case MedicineForm.pill:
        return 'Tablet';
      case MedicineForm.syrup:
        return 'Şurup';
      case MedicineForm.injection:
        return 'İğne';
      case MedicineForm.drop:
        return 'Damla';
      case MedicineForm.cream:
        return 'Krem';
      case MedicineForm.inhaler:
        return 'İnhaler';
    }
  }

  static MedicineForm formFromScanValue(String value) {
    final lower = value.toLowerCase();
    if (lower.contains('hap') || lower.contains('tablet')) {
      return MedicineForm.pill;
    }
    if (lower.contains('surup') || lower.contains('şurup')) {
      return MedicineForm.syrup;
    }
    if (lower.contains('igne') || lower.contains('iğne')) {
      return MedicineForm.injection;
    }
    if (lower.contains('damla')) {
      return MedicineForm.drop;
    }
    if (lower.contains('krem') || lower.contains('merhem')) {
      return MedicineForm.cream;
    }
    if (lower.contains('sprey') || lower.contains('inhaler')) {
      return MedicineForm.inhaler;
    }
    return MedicineForm.pill;
  }

  static Set<int> extractWeekdaysFromUsage(String usage) {
    final lower = usage.toLowerCase();
    final weekdays = <int>{};

    if (lower.contains('pazartesi') || lower.contains('pzt')) {
      weekdays.add(DateTime.monday);
    }
    if (lower.contains('sali') || lower.contains('sal')) {
      weekdays.add(DateTime.tuesday);
    }
    if (lower.contains('carsamba') || lower.contains('car')) {
      weekdays.add(DateTime.wednesday);
    }
    if (lower.contains('persembe') || lower.contains('per')) {
      weekdays.add(DateTime.thursday);
    }
    if (lower.contains('cuma') || lower.contains('cum')) {
      weekdays.add(DateTime.friday);
    }
    if (lower.contains('cumartesi') || lower.contains('cmt')) {
      weekdays.add(DateTime.saturday);
    }
    if (lower.contains('pazar') || lower.contains('paz')) {
      weekdays.add(DateTime.sunday);
    }

    return weekdays;
  }

  static String formatScanFieldValue(String key, String value) {
    switch (key) {
      case 'form':
        return localizedFormName(formFromScanValue(value));
      case 'frequency':
        final frequency = int.tryParse(value.trim());
        return frequency == null ? value : '$frequency kez / gün';
      case 'meal':
        if (value.toLowerCase().contains('tok')) {
          return 'Tok karnına';
        }
        if (value.toLowerCase().contains('ac')) {
          return 'Aç karnına';
        }
        return value;
      default:
        return value;
    }
  }

  static (String, Color, Color) scanConfidenceMeta(ScanFieldConfidence confidence) {
    switch (confidence) {
      case ScanFieldConfidence.high:
        return (
          'Yüksek güven',
          const Color(0xFF065F46),
          const Color(0xFFD1FAE5),
        );
      case ScanFieldConfidence.medium:
        return (
          'Orta güven',
          const Color(0xFF1D4ED8),
          const Color(0xFFDBEAFE),
        );
      case ScanFieldConfidence.low:
        return (
          'Kontrol et',
          const Color(0xFF92400E),
          const Color(0xFFFEF3C7),
        );
    }
  }
}
