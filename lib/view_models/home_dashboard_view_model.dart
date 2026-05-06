import 'package:intl/intl.dart';

import '../models/dose_log.dart';
import '../models/medicine.dart';
import '../utils/stats_calculator.dart';
import '../widgets/home/home_day_summary.dart';

class DoseMedicinePair {
  const DoseMedicinePair({
    required this.dose,
    required this.medicine,
  });

  final DoseLog dose;
  final Medicine medicine;
}

class HomeDashboardViewModel {
  HomeDashboardViewModel({
    required this.selectedDay,
    required List<DoseLog> selectedDayDoses,
    required List<Medicine> activeMedicines,
    required List<Medicine> lowStockMedicines,
    required List<DoseLog> upcomingAgenda,
    required List<DoseLog> recentLogs,
  })  : selectedDayDoses = List<DoseLog>.unmodifiable(selectedDayDoses),
        activeMedicines = List<Medicine>.unmodifiable(activeMedicines),
        lowStockMedicines = List<Medicine>.unmodifiable(lowStockMedicines),
        upcomingAgenda = List<DoseLog>.unmodifiable(upcomingAgenda),
        _medicineById = {
          for (final medicine in activeMedicines) medicine.id: medicine,
        },
        currentStreak = StatsCalculator.calculateStreak(recentLogs) {
    final sortedDoses = [...selectedDayDoses]
      ..sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));

    _nextDose = _resolveNextDose(sortedDoses);
    _doseMedicinePairs = List<DoseMedicinePair>.unmodifiable(
      selectedDayDoses.map((dose) {
        final medicine = _medicineById[dose.medicineId];
        if (medicine == null) {
          return null;
        }
        return DoseMedicinePair(dose: dose, medicine: medicine);
      }).whereType<DoseMedicinePair>(),
    );
    _agendaGroups = _groupAgenda(upcomingAgenda);
  }

  HomeDashboardViewModel.empty(DateTime selectedDay)
      : this(
          selectedDay: selectedDay,
          selectedDayDoses: const [],
          activeMedicines: const [],
          lowStockMedicines: const [],
          upcomingAgenda: const [],
          recentLogs: const [],
        );

  final DateTime selectedDay;
  final List<DoseLog> selectedDayDoses;
  final List<Medicine> activeMedicines;
  final List<Medicine> lowStockMedicines;
  final List<DoseLog> upcomingAgenda;
  final int currentStreak;
  final Map<String, Medicine> _medicineById;

  late final DoseLog? _nextDose;
  late final List<DoseMedicinePair> _doseMedicinePairs;
  late final Map<String, List<DoseLog>> _agendaGroups;

  bool get isSelectedDayToday {
    final now = DateTime.now();
    return now.year == selectedDay.year &&
        now.month == selectedDay.month &&
        now.day == selectedDay.day;
  }

  int get takenCount =>
      selectedDayDoses.where((dose) => dose.status == DoseStatus.taken).length;

  int get pendingCount => selectedDayDoses
      .where(
        (dose) =>
            dose.status == DoseStatus.pending ||
            dose.status == DoseStatus.snoozed,
      )
      .length;

  int get missedCount =>
      selectedDayDoses.where((dose) => dose.status == DoseStatus.missed).length;

  double get completionRate =>
      selectedDayDoses.isEmpty ? 0 : takenCount / selectedDayDoses.length;

  DoseLog? get nextDose => _nextDose;

  Medicine? get nextMedicine {
    final dose = _nextDose;
    if (dose == null) {
      return null;
    }
    return _medicineById[dose.medicineId];
  }

  String get nextDoseLabel {
    final dose = _nextDose;
    if (dose == null) {
      return '--:--';
    }
    return DateFormat('HH:mm').format(dose.scheduledTime);
  }

  String get selectedDayTitle => isSelectedDayToday
      ? 'BugÃ¼nkÃ¼ Ä°laÃ§lar'
      : 'SeÃ§ili GÃ¼nÃ¼n Ä°laÃ§larÄ±';

  String get statusText {
    if (selectedDayDoses.isEmpty) {
      return 'Plan yok';
    }
    if (missedCount > 0) {
      return '$missedCount doz atlandÄ±';
    }

    final completionPercent = (completionRate * 100).round();
    return completionPercent >= 100
        ? 'TamamlandÄ±'
        : '$completionPercent% tamam';
  }

  HomeDaySummary get daySummary {
    return HomeDaySummary(
      takenCount: takenCount,
      pendingCount: pendingCount,
      missedCount: missedCount,
      completionRate: completionRate,
      nextDose: _nextDose,
      totalCount: selectedDayDoses.length,
    );
  }

  List<DoseMedicinePair> get doseMedicinePairs => _doseMedicinePairs;

  Map<String, List<DoseLog>> get agendaGroups => _agendaGroups;

  static DoseLog? _resolveNextDose(List<DoseLog> sortedDoses) {
    final now = DateTime.now();
    for (final dose in sortedDoses) {
      if (dose.scheduledTime.isAfter(now) &&
          dose.status != DoseStatus.taken &&
          dose.status != DoseStatus.missed) {
        return dose;
      }
    }

    for (final dose in sortedDoses) {
      if (dose.status != DoseStatus.taken && dose.status != DoseStatus.missed) {
        return dose;
      }
    }

    return sortedDoses.isEmpty ? null : sortedDoses.first;
  }

  static Map<String, List<DoseLog>> _groupAgenda(List<DoseLog> agenda) {
    final grouped = <String, List<DoseLog>>{};
    for (final dose in agenda) {
      final key = DateFormat('yyyy-MM-dd').format(dose.scheduledTime);
      grouped.putIfAbsent(key, () => <DoseLog>[]).add(dose);
    }
    return Map<String, List<DoseLog>>.unmodifiable(grouped);
  }
}
