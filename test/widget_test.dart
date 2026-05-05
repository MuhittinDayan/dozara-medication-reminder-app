import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:dozara/main.dart';
import 'package:dozara/models/profile.dart';
import 'package:dozara/screens/main_screen.dart';
import 'package:dozara/screens/onboarding_screen.dart';
import 'package:dozara/services/hive_service.dart';
import 'package:dozara/widgets/home/home_day_summary.dart';
import 'package:dozara/widgets/home/home_header.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUpAll(() async {
    FlutterSecureStorage.setMockInitialValues({});
    await initializeDateFormatting('tr_TR', null);
    tempDir = await Directory.systemTemp.createTemp('ilac_hatirlatici_widget');
    Hive.init(tempDir.path);
    HiveService.registerAdapters();
    await HiveService.init();
  });

  tearDownAll(() async {
    await HiveService.close();
    await Hive.deleteFromDisk();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  testWidgets('App loads smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const DozaraApp(
        showOnboarding: false,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.byType(MainScreen), findsOneWidget);
    expect(find.text('Ekle'), findsOneWidget);
    expect(find.byIcon(Icons.add_rounded), findsWidgets);
  });

  testWidgets('Onboarding appears when it is not completed',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const DozaraApp(),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(OnboardingScreen), findsOneWidget);
    expect(find.text('Dozara'), findsOneWidget);
  });

  testWidgets('Home screen still renders when active profile name is empty',
      (WidgetTester tester) async {
    final emptyNameProfile = Profile(
      id: 'empty-name-profile',
      name: '',
      colorValue: const Color(0xFF7C3AED).toARGB32(),
      avatarUrl: '',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HomeHeader(
            activeProfile: emptyNameProfile,
            summary: const HomeDaySummary(
              takenCount: 0,
              pendingCount: 0,
              missedCount: 0,
              completionRate: 0,
              totalCount: 0,
            ),
            currentStreak: 0,
            isDark: false,
            isSelectedDayToday: true,
            onNotificationsTap: () {},
            onProfileTap: (_) {},
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(tester.takeException(), isNull);
    expect(find.textContaining('Merhaba,'), findsOneWidget);
    expect(find.text('Merhaba, Ben'), findsOneWidget);
  });
}
