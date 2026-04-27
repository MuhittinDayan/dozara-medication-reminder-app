import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_fonts/google_fonts.dart';
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
import 'services/security_service.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env', isOptional: true);
  await BackendService.init();
  await initializeDateFormatting('tr_TR', null);

  await SecurityService.init();

  await Hive.initFlutter();
  HiveService.registerAdapters();

  final encryptionKey = await SecurityService.getOrCreateEncryptionKey();
  final needsMigration = await SecurityService.needsStorageMigration();
  await HiveService.init(
    encryptionKey: encryptionKey,
    migrateFromUnencrypted: needsMigration,
  );
  if (needsMigration) {
    await SecurityService.markStorageMigrationComplete();
  }

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
    this.requireAuthentication = true,
    this.showOnboarding = true,
  });

  final bool requireAuthentication;
  final bool showOnboarding;

  static IlacHatirlaticiAppState? of(BuildContext context) =>
      context.findAncestorStateOfType<IlacHatirlaticiAppState>();

  @override
  State<IlacHatirlaticiApp> createState() => IlacHatirlaticiAppState();
}

class IlacHatirlaticiAppState extends State<IlacHatirlaticiApp>
    with WidgetsBindingObserver {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  final TextEditingController _pinController = TextEditingController();

  ThemeMode _themeMode = ThemeMode.system;
  bool _isBackground = false;
  bool _isLocked = false;
  bool _isInitializingSecurity = true;
  bool _isUnlocking = false;
  bool _onboardingCompleted = true;
  String? _unlockError;
  SecuritySnapshot? _securitySnapshot;

  BuildContext? get modalContext => _navigatorKey.currentContext;

  @override
  void initState() {
    super.initState();
    _themeMode = _loadSavedThemeMode();
    _onboardingCompleted =
        !widget.showOnboarding || HiveService.isOnboardingCompleted();
    WidgetsBinding.instance.addObserver(this);
    _bootstrapSecurity();
  }

  @override
  void dispose() {
    _pinController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> refreshSecurityState() async {
    await _loadSecurityState(keepLocked: _isLocked);
  }

  Future<void> lockNow() async {
    final snapshot = await SecurityService.getSnapshot();
    if (!mounted || !snapshot.hasPin) {
      return;
    }

    setState(() {
      _securitySnapshot = snapshot;
      _isBackground = false;
      _isLocked = true;
      _unlockError = null;
      _pinController.clear();
    });
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

  Future<void> _bootstrapSecurity() async {
    if (!widget.requireAuthentication) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLocked = false;
        _isInitializingSecurity = false;
      });
      return;
    }

    await _loadSecurityState(keepLocked: true);

    final snapshot = _securitySnapshot;
    if (snapshot == null || !snapshot.hasPin) {
      return;
    }

    if (snapshot.biometricsEnabled) {
      await _tryBiometricUnlock();
    }
  }

  Future<void> _loadSecurityState({required bool keepLocked}) async {
    final snapshot = await SecurityService.getSnapshot();
    if (!mounted) {
      return;
    }

    setState(() {
      _securitySnapshot = snapshot;
      _unlockError = null;
      _isLocked = snapshot.hasPin && keepLocked;
      if (!snapshot.hasPin) {
        _pinController.clear();
      }
      _isInitializingSecurity = false;
    });
  }

  Future<void> _tryBiometricUnlock() async {
    final snapshot = _securitySnapshot;
    if (_isUnlocking ||
        snapshot == null ||
        !snapshot.hasPin ||
        !snapshot.biometricsEnabled ||
        !snapshot.biometricsAvailable) {
      return;
    }

    setState(() {
      _isUnlocking = true;
      _unlockError = null;
    });

    final authenticated = await SecurityService.authenticateWithBiometrics(
      reason: 'İlaç takibinize erişmek için biyometrik doğrulama yapın',
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _isUnlocking = false;
      if (authenticated) {
        _isLocked = false;
        _unlockError = null;
        _pinController.clear();
      } else {
        _unlockError =
            'Biyometrik doğrulama tamamlanamadı. PIN ile devam edin.';
      }
    });
  }

  Future<void> _unlockWithPin() async {
    final pin = _pinController.text.trim();
    if (pin.length < 4 || pin.length > 6) {
      setState(() {
        _unlockError = 'PIN 4-6 hane olmalı.';
      });
      return;
    }

    setState(() {
      _isUnlocking = true;
      _unlockError = null;
    });

    final isValid = await SecurityService.verifyPin(pin);
    if (!mounted) {
      return;
    }

    setState(() {
      _isUnlocking = false;
      if (isValid) {
        _isLocked = false;
        _unlockError = null;
        _pinController.clear();
      } else {
        _unlockError = 'Girdiğiniz PIN doğru değil.';
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final snapshot = _securitySnapshot;

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      if (widget.requireAuthentication && snapshot != null) {
        setState(() {
          _isBackground = true;
          if (snapshot.hasPin && snapshot.lockOnResume) {
            _isLocked = true;
            _unlockError = null;
            _pinController.clear();
          }
        });
      }
      return;
    }

    if (state == AppLifecycleState.resumed) {
      setState(() {
        _isBackground = false;
      });

      if (!widget.requireAuthentication || snapshot == null) {
        return;
      }

      if (!snapshot.hasPin) {
        setState(() {
          _isLocked = false;
          _unlockError = null;
          _pinController.clear();
        });
        return;
      }

      if (snapshot.lockOnResume) {
        setState(() {
          _isLocked = true;
          _unlockError = null;
          _pinController.clear();
        });

        if (snapshot.biometricsEnabled) {
          _tryBiometricUnlock();
        }
      }
    }
  }

  Widget _buildSecurityOverlay() {
    final snapshot = _securitySnapshot;

    return Positioned.fill(
      child: Material(
        color: Colors.transparent,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: ColoredBox(
            color: Colors.black.withValues(alpha: 0.55),
            child: SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final bottomInset = MediaQuery.of(context).viewInsets.bottom;

                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
                    child: SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(
                        24,
                        24,
                        24,
                        bottomInset + 24,
                      ),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight - bottomInset - 48,
                        ),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 360),
                            child: Material(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(28),
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: _isInitializingSecurity || snapshot == null
                                    ? _buildLoadingState()
                                    : (_isLocked
                                        ? _buildUnlockState(snapshot)
                                        : const SizedBox.shrink()),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const CircularProgressIndicator(color: AppTheme.primaryColor),
        const SizedBox(height: 18),
        Text(
          'Güvenlik hazırlanıyor...',
          style: GoogleFonts.nunito(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppTheme.primaryDark,
          ),
        ),
      ],
    );
  }

  Widget _buildUnlockState(SecuritySnapshot snapshot) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(
          Icons.lock_rounded,
          size: 72,
          color: AppTheme.primaryColor,
        ),
        const SizedBox(height: 16),
        Text(
          'Uygulama Kilitli',
          style: GoogleFonts.nunito(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            color: AppTheme.primaryDark,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'İlaç geçmişinizi açmak için PIN’inizi girin.'
          '${snapshot.biometricsEnabled && snapshot.biometricsAvailable ? ' İsterseniz biyometrik doğrulama da kullanabilirsiniz.' : ''}',
          style: GoogleFonts.nunito(
            fontSize: 15,
            height: 1.5,
            color: Colors.grey[700],
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _pinController,
          keyboardType: TextInputType.number,
          obscureText: true,
          maxLength: 6,
          autofocus: true,
          onSubmitted: (_) => _unlockWithPin(),
          decoration: const InputDecoration(
            labelText: 'Uygulama PIN’i',
            prefixIcon: Icon(Icons.pin_rounded),
            counterText: '',
          ),
        ),
        if (_unlockError != null) ...[
          const SizedBox(height: 10),
          Text(
            _unlockError!,
            style: GoogleFonts.nunito(
              color: AppTheme.errorColor,
              fontWeight: FontWeight.w800,
            ),
            textAlign: TextAlign.center,
          ),
        ],
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isUnlocking ? null : _unlockWithPin,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: _isUnlocking
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : Text(
                    'Kilidi Aç',
                    style: GoogleFonts.nunito(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
          ),
        ),
        if (snapshot.biometricsEnabled && snapshot.biometricsAvailable) ...[
          const SizedBox(height: 10),
          TextButton.icon(
            onPressed: _isUnlocking ? null : _tryBiometricUnlock,
            icon: const Icon(Icons.fingerprint_rounded),
            label: Text(
              'Biyometri ile Aç',
              style: GoogleFonts.nunito(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasPin = _securitySnapshot?.hasPin ?? false;
    final shouldShowLockScreen = widget.requireAuthentication &&
        !_isInitializingSecurity &&
        _isLocked &&
        hasPin;
    
    final obscureBackground = _isBackground && hasPin;
    
    final shouldShowSecurityOverlay =
        obscureBackground || _isInitializingSecurity || shouldShowLockScreen;

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
        builder: (context, child) {
          return Stack(
            children: [
              if (child != null) child,
              if (shouldShowSecurityOverlay) _buildSecurityOverlay(),
            ],
          );
        },
        home: _onboardingCompleted
            ? const MainScreen()
            : OnboardingScreen(onComplete: completeOnboarding),
      ),
    );
  }
}
