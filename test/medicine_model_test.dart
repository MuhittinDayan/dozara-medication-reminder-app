import 'package:flutter_test/flutter_test.dart';

import 'package:dozara/models/medicine.dart';

void main() {
  group('Medicine scheduling', () {
    test('daily schedule applies to each day in the treatment window', () {
      final medicine = Medicine(
        id: 'med-1',
        name: 'Parol',
        dailyFrequency: 2,
        totalDays: 3,
        firstDoseTime: '08:00',
        startDate: DateTime(2026, 4, 20),
      );

      expect(medicine.isScheduledForDate(DateTime(2026, 4, 20)), isTrue);
      expect(medicine.isScheduledForDate(DateTime(2026, 4, 21)), isTrue);
      expect(medicine.isScheduledForDate(DateTime(2026, 4, 22)), isTrue);
      expect(medicine.isScheduledForDate(DateTime(2026, 4, 23)), isFalse);
    });

    test('specific day schedule only matches the chosen weekdays', () {
      final medicine = Medicine(
        id: 'med-2',
        name: 'Vitamin D',
        dailyFrequency: 1,
        totalDays: 7,
        firstDoseTime: '09:00',
        startDate: DateTime(2026, 4, 20),
        scheduleType: MedicineScheduleType.specificDays,
        selectedWeekdays: const [DateTime.monday, DateTime.wednesday],
      );

      expect(medicine.isScheduledForDate(DateTime(2026, 4, 20)), isTrue);
      expect(medicine.isScheduledForDate(DateTime(2026, 4, 21)), isFalse);
      expect(medicine.isScheduledForDate(DateTime(2026, 4, 22)), isTrue);
    });

    test('interval schedule repeats every N days', () {
      final medicine = Medicine(
        id: 'med-3',
        name: 'Antibiyotik',
        dailyFrequency: 1,
        totalDays: 7,
        firstDoseTime: '10:00',
        startDate: DateTime(2026, 4, 20),
        scheduleType: MedicineScheduleType.interval,
        intervalDays: 2,
      );

      expect(medicine.isScheduledForDate(DateTime(2026, 4, 20)), isTrue);
      expect(medicine.isScheduledForDate(DateTime(2026, 4, 21)), isFalse);
      expect(medicine.isScheduledForDate(DateTime(2026, 4, 22)), isTrue);
      expect(medicine.isScheduledForDate(DateTime(2026, 4, 26)), isTrue);
    });

    test('explicit reminder times override generated frequency times', () {
      final medicine = Medicine(
        id: 'med-4',
        name: 'Şurup',
        dailyFrequency: 3,
        totalDays: 5,
        firstDoseTime: '08:00',
        startDate: DateTime(2026, 4, 20),
        reminderTimes: const ['21:00', '09:30'],
      );

      expect(medicine.doseTimes, ['09:30', '21:00']);
      expect(medicine.remindersPerDay, 2);
    });
  });
}
