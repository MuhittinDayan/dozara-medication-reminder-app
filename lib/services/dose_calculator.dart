import '../models/medicine.dart';

class DoseCalculator {
  /// İlk doz saatinden diğer doz saatlerini hesaplar.
  /// Örnek: firstDoseTime = "08:00", frequency = 3
  /// Sonuç: ["08:00", "16:00", "00:00"] (8 saatte bir)
  static List<String> calculateDoseTimes(String firstDoseTime, int frequency) {
    if (frequency <= 0) return [];
    if (frequency == 1) return [firstDoseTime];

    final times = <String>[];
    final parts = firstDoseTime.split(':');
    final firstHour = int.parse(parts[0]);
    final firstMinute = int.parse(parts[1]);

    final intervalHours = 24 ~/ frequency;

    for (var index = 0; index < frequency; index++) {
      final hour = (firstHour + (intervalHours * index)) % 24;
      final minute = firstMinute;
      times.add(
        '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}',
      );
    }

    times.sort();
    return times;
  }

  /// Bir doz saatinin geçip geçmediğini kontrol eder.
  static bool isDosePast(String doseTime) {
    final now = DateTime.now();
    final parts = doseTime.split(':');
    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);

    final doseDateTime = DateTime(
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    return now.isAfter(doseDateTime);
  }

  /// Sonraki doz saatini bulur.
  static String? getNextDoseTime(List<String> doseTimes) {
    for (final time in doseTimes) {
      if (!isDosePast(time)) {
        return time;
      }
    }
    return null; // Tüm dozlar geçmiş.
  }

  /// İlaç için kalan toplam doz sayısını hesaplar.
  static int getRemainingDoses(Medicine medicine) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final endDate = medicine.endDate;

    if (today.isAfter(endDate)) return 0;

    final remainingDays = endDate.difference(today).inDays + 1;
    return remainingDays * medicine.remindersPerDay;
  }

  /// Saat aralığını okunabilir formatta döndürür.
  static String getIntervalDescription(int frequency) {
    if (frequency <= 0) return '';
    if (frequency == 1) return 'Günde 1 kez';

    final intervalHours = 24 ~/ frequency;
    return 'Günde $frequency kez ($intervalHours saatte bir)';
  }
}
