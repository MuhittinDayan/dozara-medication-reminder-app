import 'package:flutter/material.dart';
import '../models/dose_log.dart';
import '../models/medicine.dart';

enum DoseSlot { morning, noon, evening }

class DaySummary {
  final DateTime date;
  final int total;
  final int taken;
  final int missed;
  final int rate;

  const DaySummary({
    required this.date,
    required this.total,
    required this.taken,
    required this.missed,
    required this.rate,
  });
}

class MedicineStat {
  final Medicine medicine;
  final int rate;
  final int volume;
  final Color color;
  final List<DaySummary> last7Days;

  const MedicineStat({
    required this.medicine,
    required this.rate,
    required this.volume,
    required this.color,
    required this.last7Days,
  });
}

class HeatCell {
  final DateTime date;
  final int rate;

  const HeatCell({
    required this.date,
    required this.rate,
  });
}

class InsightSuggestion {
  final String title;
  final String body;
  final String actionLabel;
  final String? targetMedicineId;
  final TimeOfDay? recommendedTime;
  final DoseSlot slot;

  const InsightSuggestion({
    required this.title,
    required this.body,
    required this.actionLabel,
    this.targetMedicineId,
    this.recommendedTime,
    this.slot = DoseSlot.noon,
  });
}

class StatsCalculator {
  static const List<double> demoWeeklyData = [
    0.9,
    0.4,
    1.0,
    0.2,
    0.8,
    0.7,
    0.0,
  ];

  static const List<double> demoHeatmapPattern = [
    0.9, 0.0, 1.0, 0.8, 0.6, 1.0, 0.7,
    0.4, 1.0, 0.9, 0.0, 1.0, 0.8, 0.5,
    1.0, 0.7, 0.9, 0.4, 1.0, 0.0, 0.8,
    0.6, 1.0, 0.9, 0.7, 0.4, 1.0, 0.8,
    0.9, 0.7, 1.0, 0.0, 0.8, 0.6, 1.0,
  ];

  static List<DoseLog> logsForDays(List<DoseLog> logs, int days) {
    final start = DateTime.now().subtract(Duration(days: days - 1));
    final startDate = DateTime(start.year, start.month, start.day);
    return logs
        .where((log) => !log.scheduledTime.isBefore(startDate))
        .toList(growable: false);
  }

  static List<DoseLog> logsInPastWindow(
    List<DoseLog> logs, {
    required int days,
    required int offset,
  }) {
    final end = DateTime.now().subtract(Duration(days: offset));
    final start = end.subtract(Duration(days: days - 1));
    final startDate = DateTime(start.year, start.month, start.day);
    final endDate = DateTime(end.year, end.month, end.day, 23, 59, 59);
    return logs
        .where((log) => !log.scheduledTime.isBefore(startDate))
        .where((log) => !log.scheduledTime.isAfter(endDate))
        .toList(growable: false);
  }

  static int adherenceRate(List<DoseLog> logs) {
    if (logs.isEmpty) return 0;
    final taken = logs.where((log) => log.status == DoseStatus.taken).length;
    return ((taken / logs.length) * 100).round();
  }

  static int overallPercent(List<Medicine> medicines, List<DoseLog> logs90Days) {
    if (medicines.isEmpty) {
      final average = demoWeeklyData.reduce((a, b) => a + b) / demoWeeklyData.length;
      return (average * 100).round();
    }
    return adherenceRate(logsForDays(logs90Days, 7));
  }

  static List<double> calculateRealWeeklyData(List<DoseLog> logs) {
    return dailySummaries(logs, 7)
        .map((summary) => summary.rate / 100)
        .toList(growable: false);
  }

  static List<DaySummary> dailySummariesFromRates(List<double> rates) {
    final startDate = rates.length == 7
        ? startOfCurrentWeek()
        : DateTime.now().subtract(Duration(days: rates.length - 1));
    return List.generate(rates.length, (index) {
      final date = DateTime(
        startDate.year,
        startDate.month,
        startDate.day,
      ).add(Duration(days: index));
      final normalizedRate = rates[index].clamp(0.0, 1.0);
      const total = 10;
      final taken = (normalizedRate * total).round();

      return DaySummary(
        date: date,
        total: total,
        taken: taken,
        missed: total - taken,
        rate: (normalizedRate * 100).round(),
      );
    });
  }

  static List<DaySummary> dailySummaries(List<DoseLog> logs, int days) {
    final today = DateTime.now();
    final startDate = days == 7
        ? startOfCurrentWeek()
        : DateTime(today.year, today.month, today.day)
            .subtract(Duration(days: days - 1));
            
    return List.generate(days, (index) {
      final date = DateTime(
        startDate.year,
        startDate.month,
        startDate.day,
      ).add(Duration(days: index));
      final dayLogs = logs.where((log) => isSameDay(log.scheduledTime, date));
      final total = dayLogs.length;
      final taken = dayLogs.where((log) => log.status == DoseStatus.taken).length;
      final missed = dayLogs.where((log) => log.status == DoseStatus.missed).length;
      final rate = total == 0 ? 0 : ((taken / total) * 100).round();

      return DaySummary(
        date: date,
        total: total,
        taken: taken,
        missed: missed,
        rate: rate,
      );
    });
  }

  static DateTime startOfCurrentWeek() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return today.subtract(Duration(days: today.weekday - DateTime.monday));
  }

  static int fullCompletionStreak(List<DaySummary> summaries) {
    var streak = 0;
    for (final summary in summaries.reversed) {
      if (summary.total > 0 && summary.taken == summary.total) {
        streak++;
      } else {
        break;
      }
    }
    return streak;
  }

  static int calculateStreak(List<DoseLog> logs) {
    final today = DateTime.now();
    var streak = 0;

    for (var i = 0; i < 365; i++) {
      final day = today.subtract(Duration(days: i));
      final dayLogs = logs.where((log) =>
        log.scheduledTime.year == day.year &&
        log.scheduledTime.month == day.month &&
        log.scheduledTime.day == day.day
      ).toList();

      if (dayLogs.isEmpty) break;

      final allTaken = dayLogs.every((log) => log.status == DoseStatus.taken);
      if (!allTaken) break;

      streak++;
    }

    return streak;
  }

  static String trendLabel(int diff) {
    if (diff > 0) return '↑ $diff%';
    if (diff < 0) return '↓ ${diff.abs()}%';
    return '→ değişmedi';
  }

  static String missedTrendLabel(int current, int previous) {
    if (previous == 0 && current == 0) return 'hiç atlama yok';
    if (current < previous) return '↓ geçen hafta $previous';
    if (current > previous) return '↑ geçen hafta $previous';
    return '→ geçen hafta ile aynı';
  }

  static MedicineStat buildMedicineStat(Medicine medicine, List<DoseLog> logs) {
    final medicineLogs = logs
        .where((log) => log.medicineId == medicine.id)
        .toList(growable: false);
    final rate = adherenceRate(medicineLogs);
    final last7 = dailySummaries(medicineLogs, 7);

    return MedicineStat(
      medicine: medicine,
      rate: rate,
      volume: medicineLogs.length,
      color: Color(medicine.colorValue),
      last7Days: last7,
    );
  }

  static List<HeatCell> heatmapData(List<DoseLog> logs, int days) {
    final today = DateTime.now();
    return List.generate(days, (index) {
      final date = DateTime(today.year, today.month, today.day)
          .subtract(Duration(days: days - 1 - index));
      final dayLogs = logs.where((log) => isSameDay(log.scheduledTime, date));
      final total = dayLogs.length;
      final taken = dayLogs.where((log) => log.status == DoseStatus.taken).length;
      final rate = total == 0 ? 0 : ((taken / total) * 100).round();
      return HeatCell(date: date, rate: rate);
    });
  }

  static List<HeatCell> demoHeatmapData(int days) {
    final today = DateTime.now();
    return List.generate(days, (index) {
      final date = DateTime(today.year, today.month, today.day)
          .subtract(Duration(days: days - 1 - index));
      final value = demoHeatmapPattern[index % demoHeatmapPattern.length];
      return HeatCell(
        date: date,
        rate: (value.clamp(0.0, 1.0) * 100).round(),
      );
    });
  }

  static InsightSuggestion buildInsight({
    required List<Medicine> medicines,
    required List<DoseLog> logs,
    required String title,
    required String summaryPrefix,
    required String improvementPrefix,
  }) {
    final missedLogs = logs.where((log) => log.status == DoseStatus.missed).toList(growable: false);
    if (missedLogs.isEmpty || medicines.isEmpty) {
      return InsightSuggestion(
        title: title,
        body: '$improvementPrefix Bu dönemde kaçırılan belirgin bir desen yok.',
        actionLabel: 'Tamam',
      );
    }

    final weekdayCount = <int, int>{};
    final medicineCount = <String, int>{};
    final slotCount = <DoseSlot, int>{};

    for (final log in missedLogs) {
      weekdayCount.update(log.scheduledTime.weekday, (v) => v + 1, ifAbsent: () => 1);
      medicineCount.update(log.medicineId, (v) => v + 1, ifAbsent: () => 1);
      slotCount.update(doseSlot(timeFromDateTime(log.scheduledTime)), (v) => v + 1, ifAbsent: () => 1);
    }

    final weakWeekday = weekdayCount.entries.reduce((a, b) => a.value >= b.value ? a : b);
    final weakMedicineId = medicineCount.entries.reduce((a, b) => a.value >= b.value ? a : b);
    final weakSlot = slotCount.entries.reduce((a, b) => a.value >= b.value ? a : b).key;

    final medicine = medicines.firstWhere(
      (m) => m.id == weakMedicineId.key,
      orElse: () => medicines.first,
    );

    final currentTime = medicine.doseTimes.map(timeFromString).firstWhere(
          (t) => doseSlot(t) == weakSlot,
          orElse: () => medicine.doseTimes.isEmpty
              ? const TimeOfDay(hour: 13, minute: 30)
              : timeFromString(medicine.doseTimes.first),
        );
    final suggestedTime = shiftTime(currentTime, -30);

    return InsightSuggestion(
      title: title,
      body: '${weekdayLong(weakWeekday.key)} ${slotLabel(weakSlot)} dozlarında ${medicine.name} $summaryPrefix Alarmı ${timeToString(suggestedTime)} saatine çekebilirim.',
      actionLabel: 'Evet, ayarla',
      targetMedicineId: medicine.id,
      recommendedTime: suggestedTime,
      slot: weakSlot,
    );
  }

  static String weekdayShort(DateTime date) {
    switch (date.weekday) {
      case DateTime.monday: return 'Pt';
      case DateTime.tuesday: return 'Sa';
      case DateTime.wednesday: return 'Ça';
      case DateTime.thursday: return 'Pe';
      case DateTime.friday: return 'Cu';
      case DateTime.saturday: return 'Ct';
      case DateTime.sunday: return 'Pz';
      default: return '';
    }
  }

  static String weekdayLong(int weekday) {
    switch (weekday) {
      case DateTime.monday: return 'Pazartesi';
      case DateTime.tuesday: return 'Salı';
      case DateTime.wednesday: return 'Çarşamba';
      case DateTime.thursday: return 'Perşembe';
      case DateTime.friday: return 'Cuma';
      case DateTime.saturday: return 'Cumartesi';
      case DateTime.sunday: return 'Pazar';
      default: return 'Bu gün';
    }
  }

  static bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  static TimeOfDay timeFromString(String value) {
    final parts = value.split(':');
    return TimeOfDay(
      hour: int.tryParse(parts.first) ?? 8,
      minute: int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0,
    );
  }

  static TimeOfDay timeFromDateTime(DateTime value) {
    return TimeOfDay(hour: value.hour, minute: value.minute);
  }

  static TimeOfDay shiftTime(TimeOfDay time, int minutes) {
    final total = ((time.hour * 60) + time.minute + minutes).clamp(5 * 60, (23 * 60) + 59);
    return TimeOfDay(hour: total ~/ 60, minute: total % 60);
  }

  static String timeToString(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  static DoseSlot doseSlot(TimeOfDay time) {
    if (time.hour < 11) return DoseSlot.morning;
    if (time.hour < 17) return DoseSlot.noon;
    return DoseSlot.evening;
  }

  static String slotLabel(DoseSlot slot) {
    return switch (slot) {
      DoseSlot.morning => 'sabah',
      DoseSlot.noon => 'öğle',
      DoseSlot.evening => 'akşam',
    };
  }
}
