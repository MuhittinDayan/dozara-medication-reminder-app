import 'package:hive/hive.dart';

part 'medicine.g.dart';

@HiveType(typeId: 5)
enum MedicineScheduleType {
  @HiveField(0)
  daily,

  @HiveField(1)
  specificDays,

  @HiveField(2)
  interval,
}

@HiveType(typeId: 3)
enum MedicineForm {
  @HiveField(0)
  pill, // 💊 Hap

  @HiveField(1)
  syrup, // 🥤 Şurup

  @HiveField(2)
  injection, // 💉 İğne

  @HiveField(3)
  drop, // 💧 Damla

  @HiveField(4)
  cream, // 🧴 Krem

  @HiveField(5)
  inhaler, // 💨 İnhaler
}

@HiveType(typeId: 0)
class Medicine extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final int dailyFrequency;

  @HiveField(3)
  final int totalDays;

  @HiveField(4)
  final String firstDoseTime; // HH:mm formatı

  @HiveField(5)
  final DateTime startDate;

  @HiveField(6)
  int? stockCount;

  @HiveField(7)
  @Deprecated('lowStockThreshold kullan')
  final int stockWarningThreshold;

  @HiveField(8)
  bool isActive;

  @HiveField(9)
  final int colorValue; // Renk (int olarak saklanır)

  @HiveField(10)
  final MedicineForm form; // İlaç formu

  @HiveField(11)
  final String? note; // Opsiyonel not

  @HiveField(12)
  final bool withFood; // Tok karnına mı?

  @HiveField(13)
  final String? profileId; // Profil ID (Faz 3 için)

  @HiveField(14)
  final String? dosage; // Örn: 500 mg / 10 ml

  @HiveField(15)
  final MedicineScheduleType? scheduleType;

  @HiveField(16)
  final List<int>? selectedWeekdays;

  @HiveField(17)
  final int? intervalDays;

  @HiveField(18)
  final List<String>? reminderTimes;

  @HiveField(19)
  final int? lowStockThreshold;

  Medicine({
    required this.id,
    required this.name,
    required this.dailyFrequency,
    required this.totalDays,
    required this.firstDoseTime,
    required this.startDate,
    this.stockCount,
    @Deprecated('lowStockThreshold kullan') this.stockWarningThreshold = 5,
    this.isActive = true,
    this.colorValue = 0xFF2E7D32,
    this.form = MedicineForm.pill,
    this.note,
    this.withFood = false,
    this.profileId,
    this.dosage,
    this.scheduleType,
    this.selectedWeekdays,
    this.intervalDays,
    this.reminderTimes,
    this.lowStockThreshold = 7,
  });

  /// Günlük doz saatlerini hesaplar.
  List<String> get doseTimes {
    final customTimes = _normalizeTimes(reminderTimes ?? const []);
    if (customTimes.isNotEmpty) {
      return customTimes;
    }

    final times = <String>[];
    final parts = firstDoseTime.split(':');
    final firstHour = int.parse(parts[0]);
    final firstMinute = int.parse(parts[1]);

    final safeFrequency = dailyFrequency <= 0 ? 1 : dailyFrequency;
    final intervalHours = 24 ~/ safeFrequency;

    for (var index = 0; index < safeFrequency; index++) {
      final hour = (firstHour + (intervalHours * index)) % 24;
      final minute = firstMinute;
      times.add(
        '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}',
      );
    }

    times.sort();
    return times;
  }

  int get remindersPerDay => doseTimes.length;

  MedicineScheduleType get scheduleTypeValue =>
      scheduleType ?? MedicineScheduleType.daily;

  List<int> get selectedWeekdaysValue {
    final days = (selectedWeekdays ?? const <int>[])
        .where((day) => day >= DateTime.monday && day <= DateTime.sunday)
        .toSet()
        .toList()
      ..sort();
    return days;
  }

  int get intervalDaysValue =>
      intervalDays == null || intervalDays! <= 0 ? 1 : intervalDays!;

  DateTime get startDateOnly =>
      DateTime(startDate.year, startDate.month, startDate.day);

  /// Bitiş tarihini hesaplar.
  DateTime get endDate =>
      startDateOnly.add(Duration(days: totalDays <= 0 ? 0 : totalDays - 1));

  /// İlaç süresinin dolup dolmadığını kontrol eder.
  bool get isExpired =>
      DateTime.now().isAfter(endDate.add(const Duration(days: 1)));

  /// Stok azaldı mı?
  bool get isStockLow =>
      lowStockThreshold != null &&
      stockCount != null &&
      stockCount! <= lowStockThreshold!;

  /// Stok bitti mi?
  bool get isStockEmpty =>
      lowStockThreshold != null && stockCount != null && stockCount! <= 0;

  String get formEmoji {
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

  String get formName {
    switch (form) {
      case MedicineForm.pill:
        return 'Hap / Tablet';
      case MedicineForm.syrup:
        return 'Şurup';
      case MedicineForm.injection:
        return 'İğne';
      case MedicineForm.drop:
        return 'Damla';
      case MedicineForm.cream:
        return 'Krem / Merhem';
      case MedicineForm.inhaler:
        return 'İnhaler';
    }
  }

  String get scheduleDescription {
    switch (scheduleTypeValue) {
      case MedicineScheduleType.daily:
        return 'Her gün';
      case MedicineScheduleType.specificDays:
        final labels = selectedWeekdaysValue.map(_weekdayLabel).join(', ');
        return labels.isEmpty ? 'Belirli günler' : labels;
      case MedicineScheduleType.interval:
        switch (intervalDaysValue) {
          case 1:
            return 'Her gün';
          case 7:
            return 'Haftada bir';
          case 14:
            return '2 haftada bir';
          case 30:
            return 'Ayda bir';
          default:
            return '$intervalDaysValue günde bir';
        }
    }
  }

  bool isScheduledForDate(DateTime date) {
    final targetDate = DateTime(date.year, date.month, date.day);
    if (targetDate.isBefore(startDateOnly) || targetDate.isAfter(endDate)) {
      return false;
    }

    switch (scheduleTypeValue) {
      case MedicineScheduleType.daily:
        return true;
      case MedicineScheduleType.specificDays:
        final days = selectedWeekdaysValue;
        if (days.isEmpty) {
          return targetDate.weekday == startDateOnly.weekday;
        }
        return days.contains(targetDate.weekday);
      case MedicineScheduleType.interval:
        final diff = targetDate.difference(startDateOnly).inDays;
        return diff % intervalDaysValue == 0;
    }
  }

  Medicine copyWith({
    String? id,
    String? name,
    int? dailyFrequency,
    int? totalDays,
    String? firstDoseTime,
    DateTime? startDate,
    int? stockCount,
    int? stockWarningThreshold,
    bool? isActive,
    int? colorValue,
    MedicineForm? form,
    String? note,
    bool? withFood,
    String? profileId,
    String? dosage,
    MedicineScheduleType? scheduleType,
    List<int>? selectedWeekdays,
    int? intervalDays,
    List<String>? reminderTimes,
    int? lowStockThreshold,
  }) {
    return Medicine(
      id: id ?? this.id,
      name: name ?? this.name,
      dailyFrequency: dailyFrequency ?? this.dailyFrequency,
      totalDays: totalDays ?? this.totalDays,
      firstDoseTime: firstDoseTime ?? this.firstDoseTime,
      startDate: startDate ?? this.startDate,
      stockCount: stockCount ?? this.stockCount,
      stockWarningThreshold:
          stockWarningThreshold ?? this.stockWarningThreshold,
      isActive: isActive ?? this.isActive,
      colorValue: colorValue ?? this.colorValue,
      form: form ?? this.form,
      note: note ?? this.note,
      withFood: withFood ?? this.withFood,
      profileId: profileId ?? this.profileId,
      dosage: dosage ?? this.dosage,
      scheduleType: scheduleType ?? this.scheduleType,
      selectedWeekdays: selectedWeekdays ?? this.selectedWeekdays,
      intervalDays: intervalDays ?? this.intervalDays,
      reminderTimes: reminderTimes ?? this.reminderTimes,
      lowStockThreshold: lowStockThreshold ?? this.lowStockThreshold,
    );
  }

  static List<String> _normalizeTimes(List<String> times) {
    final normalized = <String>{};

    for (final time in times) {
      final parts = time.split(':');
      if (parts.length != 2) {
        continue;
      }

      final hour = int.tryParse(parts[0]);
      final minute = int.tryParse(parts[1]);
      if (hour == null || minute == null) {
        continue;
      }
      if (hour < 0 || hour > 23 || minute < 0 || minute > 59) {
        continue;
      }

      normalized.add(
        '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}',
      );
    }

    final result = normalized.toList()..sort();
    return result;
  }

  static String _weekdayLabel(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return 'Pzt';
      case DateTime.tuesday:
        return 'Sal';
      case DateTime.wednesday:
        return 'Çar';
      case DateTime.thursday:
        return 'Per';
      case DateTime.friday:
        return 'Cum';
      case DateTime.saturday:
        return 'Cmt';
      case DateTime.sunday:
        return 'Paz';
      default:
        return 'Gün';
    }
  }
}
