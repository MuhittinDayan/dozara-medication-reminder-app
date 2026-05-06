import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../cubit/profile_cubit.dart';
import '../data/backend/backend_service.dart';
import '../data/sync/sync_service.dart';
import '../main.dart';
import '../services/hive_service.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  StreamSubscription<dynamic>? _authSubscription;
  bool _isLoadingBackend = true;
  bool _isBusy = false;
  bool _isSyncing = false;
  String? _authEmail;

  @override
  void initState() {
    super.initState();
    _loadBackendState();
    _authSubscription = BackendService.authStateChanges?.listen((_) {
      _loadBackendState();
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  void _showSnackBar(String message, {Color? backgroundColor}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.nunito()),
        backgroundColor: backgroundColor ?? AppTheme.primaryColor,
      ),
    );
  }

  Future<void> _loadBackendState() async {
    if (!mounted) {
      return;
    }

    setState(() {
      _authEmail = BackendService.currentUser?.email;
      _isLoadingBackend = false;
    });
  }

  Future<void> _syncNow({bool showSuccess = true}) async {
    if (_isSyncing || !BackendService.isInitialized || _authEmail == null) {
      return;
    }

    setState(() {
      _isSyncing = true;
    });

    try {
      await SyncService.syncNow();
      await HiveService.syncDoseLogs();
      await NotificationService.rescheduleAllNotifications();
      if (mounted) {
        await context.read<ProfileCubit>().hydrate();
      }

      if (mounted && showSuccess) {
        _showSnackBar('Yedekleme tamamlandi.');
      }
    } on Object catch (error) {
      if (mounted) {
        _showSnackBar(
          'Yedekleme tamamlanamadi: $error',
          backgroundColor: AppTheme.errorColor,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSyncing = false;
        });
      }
    }
  }

  Future<void> _showAuthDialog({required bool isSignUp}) async {
    if (!BackendService.isInitialized) {
      _showSnackBar(
        'Hesap ve yedekleme servisi su an hazir degil.',
        backgroundColor: AppTheme.warningColor,
      );
      return;
    }

    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    var createAccount = isSignUp;
    var isSubmitting = false;
    String? errorText;

    final didAuthenticate = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> submit() async {
              final email = emailController.text.trim();
              final password = passwordController.text;

              final validationMessage = BackendService.validateEmailAndPassword(
                email: email,
                password: password,
              );
              if (validationMessage != null) {
                setDialogState(() {
                  errorText = validationMessage;
                });
                return;
              }

              setDialogState(() {
                isSubmitting = true;
                errorText = null;
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

                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop(true);
                }
              } on Object catch (error) {
                final friendlyMessage = BackendService.friendlyAuthError(error);
                setDialogState(() {
                  if (friendlyMessage.contains('Giris yap sekmesini') ||
                      friendlyMessage.contains('zaten hesap')) {
                    createAccount = false;
                  }
                  errorText = friendlyMessage;
                  isSubmitting = false;
                });
              }
            }

            return AlertDialog(
              title: Text(
                createAccount ? 'Hesap Olustur' : 'Giris Yap',
                style: GoogleFonts.nunito(fontWeight: FontWeight.w900),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'E-posta',
                      prefixIcon: Icon(Icons.mail_rounded),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: passwordController,
                    obscureText: true,
                    onSubmitted: (_) => submit(),
                    decoration: const InputDecoration(
                      labelText: 'Sifre',
                      prefixIcon: Icon(Icons.lock_rounded),
                    ),
                  ),
                  if (errorText != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      errorText!,
                      style: GoogleFonts.nunito(
                        color: AppTheme.errorColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: isSubmitting
                        ? null
                        : () {
                            setDialogState(() {
                              createAccount = !createAccount;
                              errorText = null;
                            });
                          },
                    child: Text(
                      createAccount
                          ? 'Zaten hesabim var'
                          : 'Yeni hesap olustur',
                      style: GoogleFonts.nunito(fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting
                      ? null
                      : () => Navigator.of(dialogContext).pop(false),
                  child: Text('Vazgec', style: GoogleFonts.nunito()),
                ),
                FilledButton(
                  onPressed: isSubmitting ? null : submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                  ),
                  child: isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          createAccount ? 'Olustur' : 'Giris Yap',
                          style: GoogleFonts.nunito(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                ),
              ],
            );
          },
        );
      },
    );

    emailController.dispose();
    passwordController.dispose();

    if (didAuthenticate == true && mounted) {
      await _loadBackendState();
      if (_authEmail == null) {
        _showSnackBar(
            'Hesap olusturuldu. E-posta onayi gerekiyorsa gelen kutunuzu kontrol edin.');
        return;
      }

      await _syncNow(showSuccess: false);
      _showSnackBar('Hesap baglandi ve yedekleme baslatildi.');
    }
  }

  Future<void> _signOut() async {
    if (_isBusy || !BackendService.isInitialized) {
      return;
    }

    setState(() {
      _isBusy = true;
    });

    await BackendService.signOut();
    await _loadBackendState();

    if (!mounted) {
      return;
    }

    setState(() {
      _isBusy = false;
    });

    _showSnackBar('Hesaptan cikis yapildi.');
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final appState = DozaraApp.of(context);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? AppTheme.darkBackground : AppTheme.backgroundColor,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 28),
          children: [
            _buildGradientHeader(isDarkMode),
            _buildSettingsSectionTitle('Hesap ve Yedekleme'),
            _buildContentPadding(
              child: _buildBackendSection(isDark),
            ),
            _buildSettingsSectionTitle('Görünüm'),
            _buildContentPadding(
              child: _buildSectionCard(
                isDark: isDark,
                children: [
                  _buildSwitchTile(
                    icon: Icons.dark_mode_rounded,
                    title: 'Karanlik Mod',
                    subtitle: isDarkMode ? 'Acik' : 'Kapali',
                    isDark: isDark,
                    value: isDarkMode,
                    enabled: true,
                    onChanged: (value) {
                      appState?.setThemeMode(
                        value ? ThemeMode.dark : ThemeMode.light,
                      );
                    },
                  ),
                ],
              ),
            ),
            _buildSettingsSectionTitle('Gelistirici Araclari'),
            _buildContentPadding(
              child: _buildSectionCard(
                isDark: isDark,
                children: [
                  _buildActionTile(
                    icon: Icons.notifications_active_rounded,
                    title: 'Test Bildirimi Gönder',
                    subtitle: 'Anlık bir test bildirimi oluşturur.',
                    isDark: isDark,
                    enabled: true,
                    onTap: _sendTestNotification,
                  ),
                ],
              ),
            ),
            _buildSettingsSectionTitle('Hakkinda'),
            _buildContentPadding(
              child: _buildSectionCard(
                isDark: isDark,
                children: [
                  _buildInfoTile(
                    icon: Icons.medication_rounded,
                    title: 'Dozara',
                    subtitle: 'Surum 1.0.0',
                    isDark: isDark,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendTestNotification() async {
    try {
      await NotificationService.showTestNotification();
      if (mounted) _showSnackBar('Test bildirimi gönderildi.');
    } on Object catch (e) {
      if (mounted) {
        _showSnackBar('Bildirim hatası: $e',
            backgroundColor: AppTheme.errorColor);
      }
    }
  }

  Widget _buildBackendSection(bool isDark) {
    if (_isLoadingBackend) {
      return _buildLoadingCard(isDark);
    }

    final configWarning = BackendService.configurationWarning;
    if (!BackendService.isConfigured) {
      return _buildSectionCard(
        isDark: isDark,
        children: [
          _buildInfoTile(
            icon: Icons.cloud_off_rounded,
            title: 'Yedekleme Kapali',
            subtitle: configWarning ??
                'Hesap ve yedekleme servisi su an hazir degil.',
            isDark: isDark,
          ),
        ],
      );
    }

    final email = _authEmail;
    if (email == null) {
      return _buildSectionCard(
        isDark: isDark,
        children: [
          _buildInfoTile(
            icon: Icons.cloud_queue_rounded,
            title: 'Hesap Bagli Degil',
            subtitle: 'Ilaclarinizi ve doz gecmisinizi hesabiniza yedekleyin.',
            isDark: isDark,
          ),
          _buildDivider(isDark),
          _buildActionTile(
            icon: Icons.login_rounded,
            title: 'Giris Yap',
            subtitle: 'Var olan hesabinizla yedeklemeyi acin.',
            isDark: isDark,
            enabled: !_isBusy && !_isSyncing,
            onTap: () => _showAuthDialog(isSignUp: false),
          ),
          _buildDivider(isDark),
          _buildActionTile(
            icon: Icons.person_add_alt_1_rounded,
            title: 'Hesap Olustur',
            subtitle: 'Yeni Dozara hesabi acin.',
            isDark: isDark,
            enabled: !_isBusy && !_isSyncing,
            onTap: () => _showAuthDialog(isSignUp: true),
          ),
        ],
      );
    }

    return _buildSectionCard(
      isDark: isDark,
      children: [
        _buildInfoTile(
          icon: Icons.cloud_done_rounded,
          title: 'Hesap Bagli',
          subtitle: email,
          isDark: isDark,
        ),
        _buildDivider(isDark),
        _buildActionTile(
          icon: Icons.sync_rounded,
          title: _isSyncing ? 'Yedekleniyor' : 'Simdi Yedekle',
          subtitle:
              'Hesaptaki verileri cihaza alir, yerel degisiklikleri hesaba kaydeder.',
          isDark: isDark,
          enabled: !_isBusy && !_isSyncing,
          onTap: _syncNow,
        ),
        _buildDivider(isDark),
        _buildActionTile(
          icon: Icons.logout_rounded,
          title: 'Cikis Yap',
          subtitle: 'Yerel veriler cihazda kalir, yedekleme durur.',
          isDark: isDark,
          enabled: !_isBusy && !_isSyncing,
          onTap: _signOut,
        ),
      ],
    );
  }

  Widget _buildGradientHeader(bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFF7C3AED),
            Color(0xFFA78BFA),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(28),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ayarlar',
            style: GoogleFonts.nunito(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          Text(
            'Tema ve uygulama tercihleri',
            style: GoogleFonts.nunito(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.75),
            ),
          ),
          const SizedBox(height: 14),
          _buildHeaderStatusCard(
            label: 'Tema',
            value: isDarkMode ? 'Karanlık' : 'Açık',
            icon:
                isDarkMode ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
            isActive: true,
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderStatusCard({
    required String label,
    required String value,
    required IconData icon,
    required bool isActive,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 16),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.nunito(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.7),
                ),
              ),
              Text(
                value,
                style: GoogleFonts.nunito(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsSectionTitle(String title) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 12),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 18,
            decoration: BoxDecoration(
              color: const Color(0xFF7C3AED),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            title,
            style: GoogleFonts.nunito(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContentPadding({required Widget child}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: child,
    );
  }

  Widget _buildLoadingCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppTheme.darkBorder : AppTheme.borderColor,
        ),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppTheme.primaryColor,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'Guvenlik bilgileri yukleniyor...',
            style: GoogleFonts.nunito(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white70 : AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required bool isDark,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppTheme.darkBorder : AppTheme.borderColor,
        ),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildDivider(bool isDark) {
    return Divider(
      height: 1,
      thickness: 1,
      color: isDark ? AppTheme.darkBorder : AppTheme.borderColor,
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isDark,
  }) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLeadingIcon(icon),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.nunito(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: GoogleFonts.nunito(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                    color: isDark
                        ? const Color(0xFFC4B7E9)
                        : AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isDark,
    required bool enabled,
    required Future<void> Function() onTap,
  }) {
    final foregroundColor = enabled
        ? (isDark ? Colors.white : AppTheme.textPrimary)
        : Colors.grey[500]!;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildLeadingIcon(icon, enabled: enabled),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.nunito(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: foregroundColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: GoogleFonts.nunito(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        height: 1.4,
                        color: enabled
                            ? (isDark
                                ? const Color(0xFFC4B7E9)
                                : AppTheme.textSecondary)
                            : Colors.grey[400],
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: enabled ? AppTheme.primaryColor : Colors.grey[400],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isDark,
    required bool value,
    required bool enabled,
    required ValueChanged<bool> onChanged,
  }) {
    final foregroundColor = enabled
        ? (isDark ? Colors.white : AppTheme.textPrimary)
        : Colors.grey[500]!;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLeadingIcon(icon, enabled: enabled),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.nunito(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: foregroundColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: GoogleFonts.nunito(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                    color: enabled
                        ? (isDark
                            ? const Color(0xFFC4B7E9)
                            : AppTheme.textSecondary)
                        : Colors.grey[400],
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            activeThumbColor: AppTheme.primaryColor,
            onChanged: enabled ? onChanged : null,
          ),
        ],
      ),
    );
  }

  Widget _buildLeadingIcon(IconData icon, {bool enabled = true}) {
    final color = enabled ? AppTheme.primaryColor : Colors.grey[400]!;

    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: color, size: 18),
    );
  }
}
