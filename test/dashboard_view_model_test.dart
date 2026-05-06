import 'package:flutter_test/flutter_test.dart';

import 'package:dozara/models/dose_log.dart';
import 'package:dozara/models/medicine.dart';
import 'package:dozara/view_models/home_dashboard_view_model.dart';
import 'package:dozara/view_models/stats_dashboard_view_model.dart';

void main() {
  group('HomeDashboardViewModel', () {
    test('precomputes summary, next dose and dose medicine pairs', () {
      final selectedDay = DateTime.now().add(const Duration(days: 1));
      final medicine = _medicine('med-1', 'Parol');
      final orphanDose = DoseLog(
        id: 'dose-orphan',
        medicineId: 'missing',
        scheduledTime: selectedDay,
      );
      final takenDose = DoseLog(
        id: 'dose-taken',
        medicineId: medicine.id,
        scheduledTime: selectedDay.add(const Duration(hours: 1)),
        status: DoseStatus.taken,
      );
      final pendingDose = DoseLog(
        id: 'dose-pending',
        medicineId: medicine.id,
        scheduledTime: selectedDay.add(const Duration(hours: 2)),
      );

      final viewModel = HomeDashboardViewModel(
        selectedDay: selectedDay,
        selectedDayDoses: [orphanDose, takenDose, pendingDose],
        activeMedicines: [medicine],
        lowStockMedicines: [medicine],
        upcomingAgenda: [pendingDose],
        recentLogs: [takenDose],
      );

      expect(viewModel.takenCount, 1);
      expect(viewModel.pendingCount, 2);
      expect(viewModel.missedCount, 0);
      expect(viewModel.daySummary.totalCount, 3);
      expect(viewModel.nextDose, orphanDose);
      expect(viewModel.nextMedicine, isNull);
      expect(viewModel.doseMedicinePairs, hasLength(2));
      expect(viewModel.agendaGroups, hasLength(1));
    });
  });

  group('StatsDashboardViewModel', () {
    test('precomputes weekly, monthly and quarter stats', () {
      final now = DateTime.now();
      final medicine = _medicine('med-1', 'Vitamin');
      final logs = [
        DoseLog(
          id: 'taken-1',
          medicineId: medicine.id,
          scheduledTime: now.subtract(const Duration(days: 1)),
          status: DoseStatus.taken,
        ),
        DoseLog(
          id: 'missed-1',
          medicineId: medicine.id,
          scheduledTime: now.subtract(const Duration(days: 2)),
          status: DoseStatus.missed,
        ),
        DoseLog(
          id: 'old-taken',
          medicineId: medicine.id,
          scheduledTime: now.subtract(const Duration(days: 40)),
          status: DoseStatus.taken,
        ),
      ];

      final viewModel = StatsDashboardViewModel(
        medicines: [medicine],
        logs90Days: logs,
      );

      expect(viewModel.overallPercent, greaterThanOrEqualTo(0));
      expect(viewModel.weekly.logs, hasLength(2));
      expect(viewModel.weekly.totalCount, 2);
      expect(viewModel.weekly.takenCount, 1);
      expect(viewModel.weekly.missedCount, 1);
      expect(viewModel.monthly.logs, hasLength(2));
      expect(viewModel.monthly.heatmapData, hasLength(35));
      expect(viewModel.quarter.heatmapData, hasLength(90));
      expect(viewModel.quarter.lastSeven, hasLength(7));
    });
  });
}

Medicine _medicine(String id, String name) {
  return Medicine(
    id: id,
    name: name,
    dailyFrequency: 1,
    totalDays: 30,
    firstDoseTime: '09:00',
    startDate: DateTime.now().subtract(const Duration(days: 10)),
  );
}
