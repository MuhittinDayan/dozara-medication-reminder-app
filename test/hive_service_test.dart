import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:ilac_hatirlatici/models/medicine.dart';
import 'package:ilac_hatirlatici/services/hive_service.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('ilac_hatirlatici_hive');
    Hive.init(tempDir.path);
    HiveService.registerAdapters();
    await HiveService.init();
  });

  tearDown(() async {
    await HiveService.close();
    await Hive.deleteFromDisk();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('syncMedicineDoseLogs creates logs for interval schedules', () async {
    final now = DateTime.now();
    final startDate = DateTime(now.year, now.month, now.day);

    final medicine = Medicine(
      id: 'interval-med',
      name: 'Antibiyotik',
      dailyFrequency: 1,
      totalDays: 7,
      firstDoseTime: '08:00',
      startDate: startDate,
      scheduleType: MedicineScheduleType.interval,
      intervalDays: 2,
      reminderTimes: const ['08:00'],
    );

    await HiveService.addMedicine(medicine);

    final logs = HiveService.getDoseLogsForMedicine(medicine.id);
    final dayOffsets = logs
        .map((log) => log.scheduledTime.difference(startDate).inDays)
        .toList()
      ..sort();

    expect(logs.length, 4);
    expect(dayOffsets, [0, 2, 4, 6]);
  });

  test('theme mode preference is persisted in the settings box', () async {
    expect(HiveService.getThemeModePreference(), 'system');

    await HiveService.setThemeModePreference('dark');

    expect(HiveService.getThemeModePreference(), 'dark');
  });

  test('onboarding completion preference is persisted in the settings box',
      () async {
    expect(HiveService.isOnboardingCompleted(), isFalse);

    await HiveService.setOnboardingCompleted(true);

    expect(HiveService.isOnboardingCompleted(), isTrue);

    await HiveService.setOnboardingCompleted(false);

    expect(HiveService.isOnboardingCompleted(), isFalse);
  });

}
