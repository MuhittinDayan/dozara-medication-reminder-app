import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:ilac_hatirlatici/models/medicine.dart';
import 'package:ilac_hatirlatici/services/hive_service.dart';
import 'package:ilac_hatirlatici/services/security_service.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('ilac_hatirlatici_hive');
    Hive.init(tempDir.path);
    SecurityService.enableInMemoryFallbackForTests();
    await SecurityService.init();
    HiveService.registerAdapters();
    await HiveService.init(
      encryptionKey: await SecurityService.getOrCreateEncryptionKey(),
      migrateFromUnencrypted: false,
    );
  });

  tearDown(() async {
    await HiveService.close();
    await Hive.deleteFromDisk();
    SecurityService.resetTestState();
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

  test('removePin clears app lock settings', () async {
    await SecurityService.setPin('1234');
    await SecurityService.setBiometricsEnabled(true);
    await SecurityService.setLockOnResume(true);

    await SecurityService.removePin();

    final snapshot = await SecurityService.getSnapshot();
    expect(snapshot.hasPin, isFalse);
    expect(snapshot.biometricsEnabled, isFalse);
    expect(snapshot.lockOnResume, isFalse);
  });
}
