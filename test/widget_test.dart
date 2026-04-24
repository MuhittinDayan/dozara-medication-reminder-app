import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:ilac_hatirlatici/main.dart';
import 'package:ilac_hatirlatici/models/profile.dart';
import 'package:ilac_hatirlatici/screens/main_screen.dart';
import 'package:ilac_hatirlatici/screens/onboarding_screen.dart';
import 'package:ilac_hatirlatici/services/hive_service.dart';
import 'package:ilac_hatirlatici/services/security_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUpAll(() async {
    await initializeDateFormatting('tr_TR', null);
    tempDir = await Directory.systemTemp.createTemp('ilac_hatirlatici_widget');
    Hive.init(tempDir.path);
    SecurityService.enableInMemoryFallbackForTests();
    await SecurityService.init();
    HiveService.registerAdapters();
    await HiveService.init(
      encryptionKey: await SecurityService.getOrCreateEncryptionKey(),
      migrateFromUnencrypted: false,
    );
  });

  tearDownAll(() async {
    await HiveService.close();
    await Hive.deleteFromDisk();
    SecurityService.resetTestState();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  testWidgets('App loads smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const IlacHatirlaticiApp(
        requireAuthentication: false,
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

  testWidgets('App opens without lock when no PIN is configured',
      (WidgetTester tester) async {
    await SecurityService.removePin();

    await tester.pumpWidget(
      const IlacHatirlaticiApp(showOnboarding: false),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(MainScreen), findsOneWidget);
    expect(find.text('Uygulama Kilitli'), findsNothing);
  });

  testWidgets('Onboarding appears when it is not completed',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const IlacHatirlaticiApp(requireAuthentication: false),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(OnboardingScreen), findsOneWidget);
    expect(find.text('MediTrack'), findsOneWidget);
  });

  testWidgets('Home screen still renders when active profile name is empty',
      (WidgetTester tester) async {
    await Hive.box<Profile>('profiles').clear();
    await Hive.box('settings').clear();
    await Hive.box('medicines').clear();
    await Hive.box('dose_logs').clear();

    final emptyNameProfile = Profile(
      id: 'empty-name-profile',
      name: '',
      colorValue: const Color(0xFF7C3AED).toARGB32(),
      avatarUrl: '',
    );

    await HiveService.addProfile(emptyNameProfile);
    await HiveService.setActiveProfile(emptyNameProfile.id);

    await tester.pumpWidget(
      const IlacHatirlaticiApp(
        requireAuthentication: false,
        showOnboarding: false,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(tester.takeException(), isNull);
    expect(find.textContaining('Merhaba,'), findsOneWidget);
    expect(find.textContaining('İlaç'), findsWidgets);
  });
}
