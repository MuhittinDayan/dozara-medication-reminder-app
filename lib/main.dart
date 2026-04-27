import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'cubit/profile_cubit.dart';
import 'data/backend/backend_service.dart';
import 'data/sync/sync_service.dart';
import 'screens/add_medicine_screen.dart';
import 'screens/main_screen.dart';
import 'screens/onboarding_screen.dart';
import 'services/ai_service.dart';
import 'services/hive_service.dart';
import 'services/notification_service.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env', isOptional: true);
  await BackendService.init();
  await initializeDateFormatting('tr_TR', null);

  await Hive.initFlutter();
  HiveService.registerAdapters();

  await HiveService.init();

  await NotificationService.init();
  AIService.init();
  await HiveService.syncDoseLogs();
  await SyncService.syncNow();
  HiveService.onLocalDataChanged = SyncService.pushLocalSnapshot;
  await NotificationService.rescheduleAllNotifications();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  runApp(const IlacHatirlaticiApp());
}

class IlacHatirlaticiApp extends StatefulWidget {
  const IlacHatirlaticiApp({
    super.key,
    this.showOnboarding = true,
  });

  final bool showOnboarding;

  static IlacHatirlaticiAppState? of(BuildContext context) =>
      context.findAncestorStateOfType<IlacHatirlaticiAppState>();

  @override
  State<IlacHatirlaticiApp> createState() => IlacHatirlaticiAppState();
}

class IlacHatirlaticiAppState extends State<IlacHatirlaticiApp> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  ThemeMode _themeMode = ThemeMode.system;
  bool _onboardingCompleted = true;

  BuildContext? get modalContext => _navigatorKey.currentContext;

  @override
  void initState() {
    super.initState();
    _themeMode = _loadSavedThemeMode();
    _onboardingCompleted =
        !widget.showOnboarding || HiveService.isOnboardingCompleted();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) {
      return;
    }

    setState(() {
      _themeMode = mode;
    });

    await HiveService.setThemeModePreference(_themeModeToPreference(mode));
  }

  Future<void> completeOnboarding({
    required bool openAddMedicine,
  }) async {
    if (!mounted) {
      return;
    }

    setState(() {
      _onboardingCompleted = true;
    });

    if (!openAddMedicine) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      _navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (_) => const AddMedicineScreen(),
        ),
      );
    });
  }

  ThemeMode _loadSavedThemeMode() {
    try {
      return _themeModeFromPreference(HiveService.getThemeModePreference());
    } on StateError {
      return ThemeMode.system;
    }
  }

  ThemeMode _themeModeFromPreference(String value) {
    switch (value) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  String _themeModeToPreference(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'system';
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ProfileCubit()..hydrate(),
      child: MaterialApp(
        navigatorKey: _navigatorKey,
        title: 'İlaç Hatırlatıcı',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: _themeMode,
        locale: const Locale('tr', 'TR'),
        home: _onboardingCompleted
            ? const MainScreen()
            : OnboardingScreen(onComplete: completeOnboarding),
      ),
    );
  }
}
