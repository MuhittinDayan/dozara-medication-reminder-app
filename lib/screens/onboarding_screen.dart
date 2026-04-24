import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../cubit/profile_cubit.dart';
import '../data/backend/backend_service.dart';
import '../data/sync/sync_service.dart';
import '../services/hive_service.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({
    super.key,
    required this.onComplete,
  });

  final Future<void> Function({required bool openAddMedicine}) onComplete;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static const _conditions = [
    'Diyabet',
    'Tansiyon',
    'Kalp',
    'Astim',
    'Alerji',
    'Diger',
  ];

  static const _palette = [
    AppTheme.primaryColor,
    Color(0xFFEC4899),
    Color(0xFF0891B2),
    Color(0xFF059669),
    Color(0xFFD97706),
  ];

  final PageController _pageController = PageController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _birthDateController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final Set<String> _selectedConditions = {'Diyabet'};

  int _page = 0;
  bool _isSaving = false;
  bool _isAuthenticating = false;
  bool _isSignInMode = false;
  bool _authMessageIsInfo = false;
  String? _authError;
  Color _selectedColor = _palette.first;

  @override
  void initState() {
    super.initState();
    final activeProfile = HiveService.getActiveProfile();
    if (activeProfile.name != 'Ben') {
      _nameController.text = activeProfile.name;
    }
    final activeColor = Color(activeProfile.colorValue);
    _selectedColor = _palette.any(
      (color) => color.toARGB32() == activeColor.toARGB32(),
    )
        ? activeColor
        : _palette.first;
    _birthDateController.text = HiveService.getOnboardingBirthDate();
    final savedConditions = HiveService.getOnboardingConditions();
    if (savedConditions.isNotEmpty) {
      _selectedConditions
        ..clear()
        ..addAll(savedConditions);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _birthDateController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  bool get _isLightPage => _page == 2 || _page == 3 || _page == 4;

  Future<void> _goNext() async {
    if (_page >= 5) {
      return;
    }

    await _pageController.nextPage(
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _goToCloudPage({bool signInMode = false}) async {
    setState(() {
      _isSignInMode = signInMode;
      _authError = null;
      _authMessageIsInfo = false;
    });

    await _pageController.animateToPage(
      4,
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _saveProfileStep() async {
    if (_isSaving) {
      return;
    }

    setState(() => _isSaving = true);

    try {
      final name = _nameController.text.trim().isEmpty
          ? 'Ben'
          : _nameController.text.trim();
      final birthDate = _birthDateController.text.trim();
      final conditions = _selectedConditions.toList()..sort();

      final cubit = context.read<ProfileCubit>();
      final currentProfile = cubit.state.activeProfile;

      await HiveService.saveOnboardingProfileContext(
        conditions: conditions,
        birthDate: birthDate,
      );

      final noteParts = <String>[
        if (birthDate.isNotEmpty) 'Dogum tarihi: $birthDate',
        if (conditions.isNotEmpty) 'Kronik durumlar: ${conditions.join(', ')}',
      ];

      await cubit.updateProfile(
        currentProfile.copyWith(
          name: name,
          colorValue: _selectedColor.toARGB32(),
          relation: 'Ben',
          note: noteParts.isEmpty ? currentProfile.note : noteParts.join(' | '),
        ),
      );

      if (!mounted) {
        return;
      }

      await _goNext();
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _authenticateWithSupabase({required bool createAccount}) async {
    if (_isAuthenticating) {
      return;
    }

    final configWarning = BackendService.configurationWarning;
    if (!BackendService.isInitialized || configWarning != null) {
      setState(() {
        _authError = configWarning ??
            'Supabase hazir degil. Uygulamayi .env dosyasindan sonra yeniden baslatin.';
        _authMessageIsInfo = false;
      });
      return;
    }

    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.length < 6) {
      setState(() {
        _authError = 'E-posta ve en az 6 karakterli sifre girin.';
        _authMessageIsInfo = false;
      });
      return;
    }

    setState(() {
      _isAuthenticating = true;
      _authError = null;
      _authMessageIsInfo = false;
    });

    try {
      if (createAccount) {
        await BackendService.signUpWithPassword(
          email: email,
          password: password,
        );
      } else {
        await BackendService.signInWithPassword(
          email: email,
          password: password,
        );
      }

      if (createAccount && BackendService.currentUser == null) {
        if (!mounted) {
          return;
        }

        setState(() {
          _isSignInMode = true;
          _authMessageIsInfo = true;
          _authError =
              'Hesap olusturuldu. E-posta onayi aciksa gelen kutunuzu kontrol edin, sonra giris yapin.';
        });
        return;
      }

      if (BackendService.currentUser != null) {
        await SyncService.syncNow();
        await HiveService.syncDoseLogs();
        await NotificationService.rescheduleAllNotifications();
        if (mounted) {
          await context.read<ProfileCubit>().hydrate();
        }
      }

      if (!mounted) {
        return;
      }

      await _goNext();
    } catch (error) {
      if (mounted) {
        final friendlyMessage = BackendService.friendlyAuthError(error);
        setState(() {
          if (friendlyMessage.contains('Giris yap sekmesini') ||
              friendlyMessage.contains('zaten hesap')) {
            _isSignInMode = true;
          }
          _authMessageIsInfo = false;
          _authError = friendlyMessage;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isAuthenticating = false;
        });
      }
    }
  }

  Future<void> _finish({required bool openAddMedicine}) async {
    if (_isSaving) {
      return;
    }

    setState(() => _isSaving = true);

    try {
      await HiveService.setOnboardingCompleted(true);
      if (mounted) {
        await widget.onComplete(openAddMedicine: openAddMedicine);
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness:
            _isLightPage ? Brightness.dark : Brightness.light,
        statusBarBrightness: _isLightPage ? Brightness.light : Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor:
            _isLightPage ? AppTheme.backgroundColor : AppTheme.primaryDark,
        body: PageView(
          controller: _pageController,
          onPageChanged: (value) => setState(() => _page = value),
          children: [
            _buildSplashPage(),
            _buildFeaturesPage(),
            _buildPermissionsPage(),
            _buildProfilePage(),
            _buildCloudAccountPage(),
            _buildReadyPage(),
          ],
        ),
      ),
    );
  }

  Widget _buildSplashPage() {
    return _GradientPageFrame(
      gradient: const LinearGradient(
        colors: [
          Color(0xFF4C1D95),
          AppTheme.primaryColor,
          AppTheme.primaryLight
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      children: [
        const Spacer(),
        Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white.withValues(alpha: 0.24)),
          ),
          child: const Icon(
            Icons.medication_rounded,
            color: Colors.white,
            size: 48,
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'MediTrack',
          style: GoogleFonts.nunito(
            fontSize: 34,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.4,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Ailenizin sagligi, her zaman\nelinizin altinda',
          textAlign: TextAlign.center,
          style: GoogleFonts.nunito(
            fontSize: 15,
            height: 1.5,
            fontWeight: FontWeight.w700,
            color: Colors.white.withValues(alpha: 0.72),
          ),
        ),
        const SizedBox(height: 34),
        const _HeroLineArt(),
        const Spacer(),
        _PrimaryOnboardingButton(
          label: 'Baslayalim',
          icon: Icons.arrow_forward_rounded,
          inverted: true,
          onPressed: _goNext,
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => _goToCloudPage(signInMode: true),
          child: Text(
            'Zaten hesabin var mi? Giris yap',
            style: GoogleFonts.nunito(
              color: Colors.white.withValues(alpha: 0.7),
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFeaturesPage() {
    return _GradientPageFrame(
      gradient: const LinearGradient(
        colors: [Color(0xFF3B0764), AppTheme.primaryDark],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      children: [
        Row(
          children: [
            const Spacer(),
            TextButton(
              onPressed: () => _finish(openAddMedicine: false),
              child: Text(
                'Gec',
                style: GoogleFonts.nunito(
                  color: Colors.white.withValues(alpha: 0.56),
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'Neden MediTrack?',
          style: GoogleFonts.nunito(
            fontSize: 28,
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Akilli hatirlatici, AI asistan ve aile takibi tek uygulamada.',
          style: GoogleFonts.nunito(
            fontSize: 14,
            height: 1.5,
            fontWeight: FontWeight.w700,
            color: Colors.white.withValues(alpha: 0.66),
          ),
        ),
        const SizedBox(height: 24),
        const _FeaturePill(
          icon: Icons.auto_awesome_rounded,
          title: 'Gemini AI Asistan',
          subtitle: 'Recete tara, ilac bilgisi al',
        ),
        const _FeaturePill(
          icon: Icons.groups_rounded,
          title: 'Aile Profilleri',
          subtitle: '5 profile kadar Netflix tarzi takip',
        ),
        const _FeaturePill(
          icon: Icons.fingerprint_rounded,
          title: 'Biyometrik Guvenlik',
          subtitle: 'PIN, Face ID ve parmak izi kilidi',
        ),
        const _FeaturePill(
          icon: Icons.analytics_rounded,
          title: 'Uyum Analizi',
          subtitle: 'Haftalik rapor ve PDF export',
        ),
        const Spacer(),
        _DotsIndicator(currentIndex: _page, darkBackground: true),
        const SizedBox(height: 18),
        _PrimaryOnboardingButton(
          label: 'Devam Et',
          icon: Icons.arrow_forward_rounded,
          inverted: true,
          onPressed: _goNext,
        ),
      ],
    );
  }

  Widget _buildPermissionsPage() {
    return _LightPageFrame(
      children: [
        const Spacer(),
        Center(
          child: Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              color: AppTheme.accentColor,
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(
              Icons.notifications_active_rounded,
              color: AppTheme.primaryColor,
              size: 38,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Izinleri birlikte ayarlayalim',
          textAlign: TextAlign.center,
          style: GoogleFonts.nunito(
            fontSize: 25,
            fontWeight: FontWeight.w900,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Ilac hatirlatmalari ve tarama ozellikleri icin neyin neden istendigini net gorebilirsin.',
          textAlign: TextAlign.center,
          style: GoogleFonts.nunito(
            fontSize: 14,
            height: 1.45,
            fontWeight: FontWeight.w700,
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 22),
        const _PermissionRow(
          icon: Icons.notifications_rounded,
          iconBackground: AppTheme.accentColor,
          title: 'Bildirimler',
          subtitle: 'Ilac ve stok uyarilari',
          badge: 'Gerekli',
          badgeColor: Color(0xFF065F46),
          badgeBackground: Color(0xFFD1FAE5),
        ),
        const _PermissionRow(
          icon: Icons.photo_camera_rounded,
          iconBackground: Color(0xFFFEF3C7),
          title: 'Kamera',
          subtitle: 'Recete ve ilac tarama',
          badge: 'Gerekli',
          badgeColor: Color(0xFF065F46),
          badgeBackground: Color(0xFFD1FAE5),
        ),
        const _PermissionRow(
          icon: Icons.health_and_safety_rounded,
          iconBackground: Color(0xFFEFF6FF),
          title: 'Saglik Verisi',
          subtitle: 'Opsiyonel entegrasyonlar',
          badge: 'Opsiyonel',
          badgeColor: AppTheme.primaryDark,
          badgeBackground: AppTheme.accentColor,
        ),
        const _PermissionRow(
          icon: Icons.location_on_rounded,
          iconBackground: Color(0xFFF0FDF4),
          title: 'Konum',
          subtitle: 'Yakindaki eczaneleri bul',
          badge: 'Opsiyonel',
          badgeColor: AppTheme.primaryDark,
          badgeBackground: AppTheme.accentColor,
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.backgroundSecondary,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.borderColor),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.lock_rounded,
                color: AppTheme.primaryColor,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Verileriniz cihazinizda sifreli saklanir. Ucuncu taraflarla paylasilmaz.',
                  style: GoogleFonts.nunito(
                    fontSize: 12,
                    height: 1.45,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.primaryDark,
                  ),
                ),
              ),
            ],
          ),
        ),
        const Spacer(),
        _DotsIndicator(currentIndex: _page),
        const SizedBox(height: 18),
        _PrimaryOnboardingButton(
          label: 'Izin Ver',
          icon: Icons.arrow_forward_rounded,
          onPressed: _goNext,
        ),
        const SizedBox(height: 4),
        TextButton(
          onPressed: _goNext,
          child: Text(
            'Simdi degil',
            style: GoogleFonts.nunito(
              color: AppTheme.textTertiary,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProfilePage() {
    final previewName =
        _nameController.text.trim().isEmpty ? 'B' : _nameController.text.trim();
    final initial = previewName.substring(0, 1).toUpperCase();

    return _LightPageFrame(
      children: [
        Text(
          'Seni taniyalim',
          textAlign: TextAlign.center,
          style: GoogleFonts.nunito(
            fontSize: 26,
            fontWeight: FontWeight.w900,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Ilk profilini olustur, hatirlatmalar sana gore calissin.',
          textAlign: TextAlign.center,
          style: GoogleFonts.nunito(
            fontSize: 14,
            height: 1.4,
            fontWeight: FontWeight.w700,
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 20),
        Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            width: 86,
            height: 86,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  _selectedColor,
                  Color.lerp(_selectedColor, Colors.white, 0.42) ??
                      _selectedColor,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: _selectedColor.withValues(alpha: 0.32),
                  blurRadius: 22,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Text(
              initial,
              style: GoogleFonts.nunito(
                fontSize: 34,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 10,
          runSpacing: 10,
          children: _palette.map((color) {
            final isSelected = color.toARGB32() == _selectedColor.toARGB32();
            return GestureDetector(
              onTap: () => setState(() => _selectedColor = color),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? AppTheme.primaryDark : Colors.white,
                    width: isSelected ? 3 : 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: isSelected ? 0.42 : 0.18),
                      blurRadius: isSelected ? 12 : 6,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 22),
        TextField(
          controller: _nameController,
          textCapitalization: TextCapitalization.words,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            labelText: 'Adin ne?',
            hintText: 'Orn: Ayse',
            prefixIcon: Icon(Icons.person_rounded),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _birthDateController,
          keyboardType: TextInputType.datetime,
          decoration: const InputDecoration(
            labelText: 'Dogum tarihi',
            hintText: 'GG / AA / YYYY',
            prefixIcon: Icon(Icons.cake_rounded),
          ),
        ),
        const SizedBox(height: 18),
        _SectionLabel(label: 'Kronik hastalik var mi?'),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _conditions.map((condition) {
            final isSelected = _selectedConditions.contains(condition);
            return FilterChip(
              label: Text(condition),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    _selectedConditions.add(condition);
                  } else {
                    _selectedConditions.remove(condition);
                  }
                });
              },
            );
          }).toList(),
        ),
        const Spacer(),
        _DotsIndicator(currentIndex: _page),
        const SizedBox(height: 18),
        _PrimaryOnboardingButton(
          label: _isSaving ? 'Kaydediliyor...' : 'Profili Olustur',
          icon: Icons.arrow_forward_rounded,
          onPressed: _isSaving ? null : _saveProfileStep,
        ),
      ],
    );
  }

  Widget _buildReadyPage() {
    final name = _nameController.text.trim().isEmpty
        ? HiveService.getActiveProfile().name
        : _nameController.text.trim();

    return _GradientPageFrame(
      gradient: const LinearGradient(
        colors: [
          Color(0xFF4C1D95),
          AppTheme.primaryColor,
          AppTheme.primaryLight
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      children: [
        const Spacer(),
        const _ConfettiStrip(),
        const SizedBox(height: 8),
        Container(
          width: 104,
          height: 104,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.16),
            border: Border.all(
                color: Colors.white.withValues(alpha: 0.3), width: 2),
          ),
          child: Center(
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.2),
              ),
              child: const Icon(
                Icons.check_rounded,
                color: Colors.white,
                size: 42,
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'Harika, $name!',
          textAlign: TextAlign.center,
          style: GoogleFonts.nunito(
            fontSize: 28,
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'MediTrack hazir. Simdi ilk ilacini ekleyebilir veya receteni tarayabilirsin.',
          textAlign: TextAlign.center,
          style: GoogleFonts.nunito(
            fontSize: 14,
            height: 1.55,
            fontWeight: FontWeight.w700,
            color: Colors.white.withValues(alpha: 0.76),
          ),
        ),
        const SizedBox(height: 24),
        const _ReadySummaryRow(
          icon: Icons.auto_awesome_rounded,
          label: 'Gemini AI Asistan aktif',
        ),
        const _ReadySummaryRow(
          icon: Icons.notifications_rounded,
          label: 'Hatirlaticilar hazir',
        ),
        const _ReadySummaryRow(
          icon: Icons.lock_rounded,
          label: 'Veriler sifreli',
        ),
        const Spacer(),
        _PrimaryOnboardingButton(
          label: _isSaving ? 'Acilıyor...' : 'Ilk Ilaci Ekle',
          icon: Icons.medication_rounded,
          inverted: true,
          onPressed: _isSaving ? null : () => _finish(openAddMedicine: true),
        ),
        const SizedBox(height: 6),
        TextButton(
          onPressed: _isSaving ? null : () => _finish(openAddMedicine: false),
          child: Text(
            'veya ana sayfaya gec',
            style: GoogleFonts.nunito(
              color: Colors.white.withValues(alpha: 0.58),
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCloudAccountPage() {
    final configWarning = BackendService.configurationWarning;
    final hasAccount = BackendService.currentUser?.email != null;

    return _LightPageFrame(
      children: [
        const Spacer(),
        Center(
          child: Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              color: AppTheme.accentColor,
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(
              Icons.cloud_done_rounded,
              color: AppTheme.primaryColor,
              size: 38,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Bulut hesabini baglayalim',
          textAlign: TextAlign.center,
          style: GoogleFonts.nunito(
            fontSize: 25,
            fontWeight: FontWeight.w900,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Hesap, ilaclarini yeni telefonda geri getirmek ve aile profillerini cihazlar arasinda esitlemek icin kullanilir.',
          textAlign: TextAlign.center,
          style: GoogleFonts.nunito(
            fontSize: 14,
            height: 1.45,
            fontWeight: FontWeight.w700,
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 22),
        if (hasAccount)
          _CloudStatusCard(email: BackendService.currentUser!.email!)
        else if (configWarning != null)
          _CloudWarningCard(message: configWarning)
        else ...[
          _AuthModeSwitch(
            isSignInMode: _isSignInMode,
            onChanged: (value) {
              setState(() {
                _isSignInMode = value;
                _authError = null;
                _authMessageIsInfo = false;
              });
            },
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'E-posta',
              prefixIcon: Icon(Icons.mail_rounded),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _passwordController,
            obscureText: true,
            onSubmitted: (_) => _authenticateWithSupabase(createAccount: false),
            decoration: const InputDecoration(
              labelText: 'Sifre',
              prefixIcon: Icon(Icons.lock_rounded),
            ),
          ),
          if (_authError != null) ...[
            const SizedBox(height: 12),
            Text(
              _authError!,
              style: GoogleFonts.nunito(
                fontSize: 12,
                height: 1.35,
                color: _authMessageIsInfo
                    ? const Color(0xFF047857)
                    : AppTheme.errorColor,
                fontWeight: FontWeight.w800,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
        const Spacer(),
        _DotsIndicator(currentIndex: _page, itemCount: 6),
        const SizedBox(height: 18),
        if (hasAccount)
          _PrimaryOnboardingButton(
            label: 'Devam Et',
            icon: Icons.arrow_forward_rounded,
            onPressed: _goNext,
          )
        else ...[
          _PrimaryOnboardingButton(
            label: _isAuthenticating
                ? 'Baglaniyor...'
                : (_isSignInMode ? 'Giris Yap' : 'Hesap Olustur'),
            icon: _isSignInMode
                ? Icons.login_rounded
                : Icons.person_add_alt_1_rounded,
            onPressed: _isAuthenticating || configWarning != null
                ? null
                : () => _authenticateWithSupabase(
                      createAccount: !_isSignInMode,
                    ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _isAuthenticating || configWarning != null
                ? null
                : () {
                    setState(() {
                      _isSignInMode = !_isSignInMode;
                      _authError = null;
                      _authMessageIsInfo = false;
                    });
                  },
            icon: Icon(
              _isSignInMode
                  ? Icons.person_add_alt_1_rounded
                  : Icons.login_rounded,
            ),
            label: Text(
              _isSignInMode ? 'Yeni hesap olustur' : 'Hesabim var, giris yap',
              style: GoogleFonts.nunito(fontWeight: FontWeight.w900),
            ),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              foregroundColor: AppTheme.primaryColor,
              side: const BorderSide(color: AppTheme.primaryColor),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
          ),
          const SizedBox(height: 4),
          TextButton(
            onPressed: _isAuthenticating ? null : _goNext,
            child: Text(
              'Simdilik atla',
              style: GoogleFonts.nunito(
                color: AppTheme.textTertiary,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _GradientPageFrame extends StatelessWidget {
  const _GradientPageFrame({
    required this.gradient,
    required this.children,
  });

  final Gradient gradient;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(gradient: gradient),
      child: _ResponsivePagePadding(children: children),
    );
  }
}

class _LightPageFrame extends StatelessWidget {
  const _LightPageFrame({
    required this.children,
  });

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppTheme.backgroundColor,
        gradient: LinearGradient(
          colors: [Colors.white, AppTheme.backgroundColor],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: _ResponsivePagePadding(children: children),
    );
  }
}

class _ResponsivePagePadding extends StatelessWidget {
  const _ResponsivePagePadding({
    required this.children,
  });

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 18, 22, 22),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ),
      ),
    );
  }
}

class _PrimaryOnboardingButton extends StatelessWidget {
  const _PrimaryOnboardingButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.inverted = false,
  });

  final String label;
  final IconData? icon;
  final bool inverted;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final foreground = inverted ? AppTheme.primaryColor : Colors.white;
    final background = inverted ? Colors.white : AppTheme.primaryColor;

    return SizedBox(
      width: double.infinity,
      height: 56,
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: icon == null ? const SizedBox.shrink() : Icon(icon, size: 20),
        label: Text(label),
        style: FilledButton.styleFrom(
          backgroundColor: background,
          disabledBackgroundColor: background.withValues(alpha: 0.72),
          foregroundColor: foreground,
          disabledForegroundColor: foreground.withValues(alpha: 0.72),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          textStyle: GoogleFonts.nunito(
            fontSize: 16,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _DotsIndicator extends StatelessWidget {
  const _DotsIndicator({
    required this.currentIndex,
    this.darkBackground = false,
    this.itemCount = 6,
  });

  final int currentIndex;
  final bool darkBackground;
  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(itemCount, (index) {
        final isActive = currentIndex == index;
        final color = darkBackground
            ? Colors.white.withValues(alpha: isActive ? 1 : 0.28)
            : (isActive ? AppTheme.primaryColor : AppTheme.accentColor);

        return AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: isActive ? 24 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(999),
          ),
        );
      }),
    );
  }
}

class _FeaturePill extends StatelessWidget {
  const _FeaturePill({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.nunito(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.nunito(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.white.withValues(alpha: 0.62),
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.2),
            ),
            child:
                const Icon(Icons.check_rounded, color: Colors.white, size: 16),
          ),
        ],
      ),
    );
  }
}

class _PermissionRow extends StatelessWidget {
  const _PermissionRow({
    required this.icon,
    required this.iconBackground,
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.badgeColor,
    required this.badgeBackground,
  });

  final IconData icon;
  final Color iconBackground;
  final String title;
  final String subtitle;
  final String badge;
  final Color badgeColor;
  final Color badgeBackground;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColor),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: iconBackground,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: AppTheme.primaryColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.nunito(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.textPrimary,
                  ),
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.nunito(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: badgeBackground,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              badge,
              style: GoogleFonts.nunito(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                color: badgeColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReadySummaryRow extends StatelessWidget {
  const _ReadySummaryRow({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.nunito(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                color: Colors.white.withValues(alpha: 0.9),
              ),
            ),
          ),
          Container(
            width: 10,
            height: 10,
            decoration: const BoxDecoration(
              color: Color(0xFF4ADE80),
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }
}

class _CloudStatusCard extends StatelessWidget {
  const _CloudStatusCard({required this.email});

  final String email;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFD1FAE5),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF86EFAC)),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_rounded, color: Color(0xFF047857)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '$email ile bagli',
              style: GoogleFonts.nunito(
                fontSize: 13,
                height: 1.35,
                fontWeight: FontWeight.w900,
                color: const Color(0xFF065F46),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AuthModeSwitch extends StatelessWidget {
  const _AuthModeSwitch({
    required this.isSignInMode,
    required this.onChanged,
  });

  final bool isSignInMode;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 46,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppTheme.backgroundSecondary,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Row(
        children: [
          Expanded(
            child: _AuthModeSegment(
              label: 'Giris yap',
              selected: isSignInMode,
              onTap: () => onChanged(true),
            ),
          ),
          Expanded(
            child: _AuthModeSegment(
              label: 'Hesap olustur',
              selected: !isSignInMode,
              onTap: () => onChanged(false),
            ),
          ),
        ],
      ),
    );
  }
}

class _AuthModeSegment extends StatelessWidget {
  const _AuthModeSegment({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppTheme.primaryColor : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Center(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.nunito(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: selected ? Colors.white : AppTheme.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _CloudWarningCard extends StatelessWidget {
  const _CloudWarningCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFCD34D)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_rounded, color: Color(0xFFD97706)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.nunito(
                fontSize: 13,
                height: 1.35,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF92400E),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: GoogleFonts.nunito(
        fontSize: 11,
        fontWeight: FontWeight.w900,
        letterSpacing: 0.8,
        color: AppTheme.primaryColor,
      ),
    );
  }
}

class _HeroLineArt extends StatelessWidget {
  const _HeroLineArt();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 96,
      child: CustomPaint(
        painter: _HeroLineArtPainter(),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _HeroLineArtPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final pillPaint = Paint()..color = Colors.white.withValues(alpha: 0.26);
    final pillAccent = Paint()..color = Colors.white.withValues(alpha: 0.48);
    final stroke = Paint()
      ..color = Colors.white.withValues(alpha: 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final centerY = size.height * 0.5;
    final pill = RRect.fromRectAndRadius(
      Rect.fromLTWH(size.width * 0.12, centerY - 12, 78, 24),
      const Radius.circular(16),
    );
    canvas.drawRRect(pill, pillPaint);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.12, centerY - 12, 39, 24),
        const Radius.circular(16),
      ),
      pillAccent,
    );

    final path = Path()
      ..moveTo(size.width * 0.45, centerY + 2)
      ..lineTo(size.width * 0.51, centerY + 2)
      ..lineTo(size.width * 0.55, centerY - 18)
      ..lineTo(size.width * 0.59, centerY + 24)
      ..lineTo(size.width * 0.63, centerY - 7)
      ..lineTo(size.width * 0.68, centerY + 8)
      ..lineTo(size.width * 0.73, centerY + 8);
    canvas.drawPath(path, stroke);

    final familyPaint = Paint()..color = Colors.white.withValues(alpha: 0.34);
    canvas.drawCircle(Offset(size.width * 0.82, centerY - 9), 10, familyPaint);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(size.width * 0.82, centerY + 16),
          width: 16,
          height: 22,
        ),
        const Radius.circular(8),
      ),
      familyPaint,
    );
    canvas.drawCircle(
      Offset(size.width * 0.91, centerY - 4),
      7,
      Paint()..color = Colors.white.withValues(alpha: 0.24),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ConfettiStrip extends StatelessWidget {
  const _ConfettiStrip();

  @override
  Widget build(BuildContext context) {
    const pieces = [
      (0.08, 8.0, Color(0xFFFDE68A), true, 0.35),
      (0.22, 22.0, Color(0xFFFCA5A5), false, -0.18),
      (0.38, 4.0, Color(0xFF6EE7B7), true, -0.28),
      (0.55, 18.0, Color(0xFF93C5FD), false, 0.12),
      (0.72, 8.0, Color(0xFFF9A8D4), true, 0.42),
      (0.88, 24.0, Color(0xFFC4B5FD), false, -0.34),
    ];

    return SizedBox(
      height: 54,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            children: [
              for (final piece in pieces)
                Positioned(
                  left: constraints.maxWidth * piece.$1,
                  top: piece.$2,
                  child: Transform.rotate(
                    angle: piece.$5,
                    child: Container(
                      width: piece.$4 ? 11 : 8,
                      height: piece.$4 ? 11 : 8,
                      decoration: BoxDecoration(
                        color: piece.$3,
                        borderRadius: BorderRadius.circular(piece.$4 ? 3 : 999),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
