import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../cubit/profile_cubit.dart';
import '../models/dose_log.dart';
import '../models/profile.dart';
import '../services/hive_service.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';

class FamilyProfilesScreen extends StatelessWidget {
  const FamilyProfilesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ProfileCubit, ProfileState>(
      builder: (context, state) {
        final overviews = state.profiles
            .map(_ProfileOverview.fromProfile)
            .toList(growable: false);
        final canAddMore = state.profiles.length < 5;

        return Scaffold(
          backgroundColor: AppTheme.darkBackground,
          body: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppTheme.darkBackground, AppTheme.darkCard],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          icon: const Icon(
                            Icons.arrow_back_ios_new_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () => _openCareSummary(context),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white,
                            backgroundColor:
                                Colors.white.withValues(alpha: 0.12),
                          ),
                          child: Text(
                            'Profilleri Yonet',
                            style:
                                GoogleFonts.nunito(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Kim kullaniyor?',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.nunito(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Profil secmeden once kimin ne durumda oldugu gorunsun.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.nunito(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.white.withValues(alpha: 0.55),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Expanded(
                      child: GridView.builder(
                        itemCount: overviews.length + 1,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 14,
                          crossAxisSpacing: 14,
                          childAspectRatio: 0.92,
                        ),
                        itemBuilder: (context, index) {
                          if (index == overviews.length) {
                            return _AddProfileCard(
                              enabled: canAddMore,
                              onTap: canAddMore
                                  ? () => _openProfileEditor(context)
                                  : null,
                            );
                          }

                          final overview = overviews[index];
                          final isActive =
                              overview.profile.id == state.activeProfileId;
                          return _ProfileSelectionCard(
                            overview: overview,
                            isActive: isActive,
                            onTap: () =>
                                _selectProfile(context, overview.profile),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _selectProfile(BuildContext context, Profile profile) async {
    await context.read<ProfileCubit>().switchTo(profile.id);
    if (context.mounted) {
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _openCareSummary(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const FamilyCareSummaryScreen()),
    );
  }

  Future<void> _openProfileEditor(
    BuildContext context, {
    Profile? profile,
  }) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => FamilyProfileEditorScreen(initialProfile: profile),
      ),
    );
  }
}

class FamilyCareSummaryScreen extends StatelessWidget {
  const FamilyCareSummaryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return BlocBuilder<ProfileCubit, ProfileState>(
      builder: (context, state) {
        final overviews = state.profiles
            .map(_ProfileOverview.fromProfile)
            .toList(growable: false);

        return Scaffold(
          backgroundColor:
              isDark ? AppTheme.darkBackground : AppTheme.backgroundColor,
          appBar: AppBar(
            titleSpacing: 0,
            flexibleSpace: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppTheme.primaryColor, AppTheme.primaryLight],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Aile Ozeti',
                  style: GoogleFonts.nunito(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                Text(
                  '${state.profiles.length} profil takip ediliyor',
                  style: GoogleFonts.nunito(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.white.withValues(alpha: 0.76),
                  ),
                ),
              ],
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: TextButton.icon(
                  onPressed: () => _openProfileEditor(context),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: Colors.white.withValues(alpha: 0.14),
                  ),
                  icon: const Icon(Icons.add_rounded),
                  label: Text(
                    'Ekle',
                    style: GoogleFonts.nunito(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              for (final overview in overviews)
                _CareSummaryCard(
                  overview: overview,
                  isActive: overview.profile.id == state.activeProfileId,
                  onTap: () => _openProfileEditor(
                    context,
                    profile: overview.profile,
                  ),
                  onSendReminder: overview.requiresReminder &&
                          overview.profile.receivesDoseNotifications
                      ? () => _sendReminder(context, overview)
                      : null,
                  onSwitchProfile: () =>
                      _switchTo(context, overview.profile.id),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openProfileEditor(
    BuildContext context, {
    Profile? profile,
  }) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => FamilyProfileEditorScreen(initialProfile: profile),
      ),
    );
  }

  Future<void> _switchTo(BuildContext context, String profileId) async {
    await context.read<ProfileCubit>().switchTo(profileId);
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Aktif profil degistirildi.',
          style: GoogleFonts.nunito(),
        ),
        backgroundColor: AppTheme.primaryColor,
      ),
    );
  }

  Future<void> _sendReminder(
    BuildContext context,
    _ProfileOverview overview,
  ) async {
    await NotificationService.showCaregiverReminder(
      profileName: overview.profile.name,
      message: overview.reminderMessage,
    );

    if (!context.mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${overview.profile.name} icin hatirlatma gonderildi.',
          style: GoogleFonts.nunito(),
        ),
        backgroundColor: AppTheme.warningColor,
      ),
    );
  }
}

class FamilyProfileEditorScreen extends StatefulWidget {
  const FamilyProfileEditorScreen({
    super.key,
    this.initialProfile,
  });

  final Profile? initialProfile;

  @override
  State<FamilyProfileEditorScreen> createState() =>
      _FamilyProfileEditorScreenState();
}

class _FamilyProfileEditorScreenState extends State<FamilyProfileEditorScreen> {
  static const _relations = ['Anne', 'Baba', 'Cocuk', 'Es', 'Diger', 'Ben'];
  static const _palette = [
    Color(0xFF7C3AED),
    Color(0xFFEC4899),
    Color(0xFF0891B2),
    Color(0xFF059669),
    Color(0xFFD97706),
  ];

  late final TextEditingController _nameController;
  late String _selectedRelation;
  late Color _selectedColor;
  late bool _receivesDoseNotifications;
  late bool _canManageMedicines;
  late bool _isEmergencyContact;
  bool _isSaving = false;

  bool get _isEditing => widget.initialProfile != null;

  @override
  void initState() {
    super.initState();
    final profile = widget.initialProfile;
    _nameController = TextEditingController(text: profile?.name ?? '');
    _selectedRelation = profile?.relation ?? 'Anne';
    _selectedColor = Color(profile?.colorValue ?? _palette[1].toARGB32());
    _receivesDoseNotifications = profile?.receivesDoseNotifications ?? true;
    _canManageMedicines = profile?.canManageMedicines ?? true;
    _isEmergencyContact = profile?.isEmergencyContact ?? false;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final title = _isEditing ? 'Profili Duzenle' : 'Yeni Profil';
    final previewName = _nameController.text.trim().isEmpty
        ? _selectedRelation
        : _nameController.text.trim();

    return Scaffold(
      backgroundColor:
          isDark ? AppTheme.darkBackground : AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(title),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TextButton(
              onPressed: _isSaving ? null : _saveProfile,
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Colors.white.withValues(alpha: 0.14),
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      'Kaydet',
                      style: GoogleFonts.nunito(fontWeight: FontWeight.w800),
                    ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkCard : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark ? AppTheme.darkBorder : AppTheme.borderColor,
              ),
            ),
            child: Column(
              children: [
                _ProfileAvatar(
                  profile: Profile(
                    id: widget.initialProfile?.id ?? 'preview',
                    name: previewName,
                    colorValue: _selectedColor.toARGB32(),
                    avatarUrl: '',
                    relation: _selectedRelation,
                    receivesDoseNotifications: _receivesDoseNotifications,
                    canManageMedicines: _canManageMedicines,
                    isEmergencyContact: _isEmergencyContact,
                    isCaregiverMode: _selectedRelation != 'Ben',
                  ),
                  size: 72,
                ),
                const SizedBox(height: 8),
                Text(
                  'Renk Sec',
                  style: GoogleFonts.nunito(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: isDark
                        ? const Color(0xFFD6D0E8)
                        : AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: _palette.map((color) {
                    final isSelected =
                        color.toARGB32() == _selectedColor.toARGB32();
                    return GestureDetector(
                      onTap: () => setState(() => _selectedColor = color),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: color,
                          border: Border.all(
                            color:
                                isSelected ? Colors.white : Colors.transparent,
                            width: 2,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: color.withValues(alpha: 0.38),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ]
                              : null,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _nameController,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Ad Soyad',
              hintText: 'Orn: Fatma Hanim',
              prefixIcon: Icon(Icons.person_rounded),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 14),
          Text(
            'Yakinlik',
            style: GoogleFonts.nunito(
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _relations.map((relation) {
              final isSelected = relation == _selectedRelation;
              return ChoiceChip(
                label: Text(relation),
                selected: isSelected,
                onSelected: (_) => setState(() => _selectedRelation = relation),
              );
            }).toList(),
          ),
          const SizedBox(height: 18),
          Container(
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkCard : Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isDark ? AppTheme.darkBorder : AppTheme.borderColor,
              ),
            ),
            child: Column(
              children: [
                _PermissionTile(
                  title: 'Doz alindi bildirimi',
                  subtitle: 'Bana push gonder',
                  value: _receivesDoseNotifications,
                  onChanged: (value) {
                    setState(() => _receivesDoseNotifications = value);
                  },
                  showDivider: true,
                ),
                _PermissionTile(
                  title: 'Ilac ekleme yetkisi',
                  subtitle: 'Bu profili duzenleyebilir',
                  value: _canManageMedicines,
                  onChanged: (value) {
                    setState(() => _canManageMedicines = value);
                  },
                  showDivider: true,
                ),
                _PermissionTile(
                  title: 'Acil durum kisisi',
                  subtitle: 'Kritik uyarilarda bana ulas',
                  value: _isEmergencyContact,
                  onChanged: (value) {
                    setState(() => _isEmergencyContact = value);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _isSaving ? null : _saveProfile,
            child: Text(
              _isEditing ? 'Degisiklikleri Kaydet' : 'Profili Olustur',
            ),
          ),
          if (_isEditing &&
              widget.initialProfile?.id != HiveService.defaultProfileId)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: TextButton.icon(
                onPressed: _isSaving ? null : _deleteProfile,
                icon: const Icon(Icons.delete_outline_rounded),
                label: const Text('Profili Sil'),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _saveProfile() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _showMessage('Profil adi bos birakilamaz.', AppTheme.errorColor);
      return;
    }

    if (!_isEditing &&
        context.read<ProfileCubit>().state.profiles.length >= 5) {
      _showMessage('En fazla 5 profil eklenebilir.', AppTheme.errorColor);
      return;
    }

    setState(() => _isSaving = true);

    final existing = widget.initialProfile;
    final profile = (existing ??
            Profile(
              id: DateTime.now().microsecondsSinceEpoch.toString(),
              name: name,
              colorValue: _selectedColor.toARGB32(),
              avatarUrl: '',
            ))
        .copyWith(
      name: name,
      colorValue: _selectedColor.toARGB32(),
      relation: _selectedRelation,
      receivesDoseNotifications: _receivesDoseNotifications,
      canManageMedicines: _canManageMedicines,
      isEmergencyContact: _isEmergencyContact,
      isCaregiverMode: _selectedRelation != 'Ben',
    );

    if (_isEditing) {
      await context.read<ProfileCubit>().updateProfile(profile);
    } else {
      await context
          .read<ProfileCubit>()
          .createProfile(profile, makeActive: true);
    }

    if (!mounted) {
      return;
    }

    setState(() => _isSaving = false);
    Navigator.of(context).pop(true);
  }

  Future<void> _deleteProfile() async {
    final profile = widget.initialProfile;
    if (profile == null) {
      return;
    }

    await context.read<ProfileCubit>().deleteProfile(profile.id);
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop(true);
  }

  void _showMessage(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.nunito()),
        backgroundColor: color,
      ),
    );
  }
}

class _ProfileSelectionCard extends StatelessWidget {
  const _ProfileSelectionCard({
    required this.overview,
    required this.isActive,
    required this.onTap,
  });

  final _ProfileOverview overview;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: isActive
                ? Colors.white.withValues(alpha: 0.12)
                : Colors.white.withValues(alpha: 0.06),
            border: Border.all(
              color: isActive ? AppTheme.primaryLight : Colors.transparent,
              width: 2,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    _ProfileAvatar(profile: overview.profile, size: 62),
                    if (overview.urgentCount > 0)
                      Positioned(
                        right: -2,
                        bottom: -2,
                        child: Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: AppTheme.errorColor,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppTheme.darkCard,
                              width: 2,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '${overview.urgentCount}',
                            style: GoogleFonts.nunito(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  overview.profile.name,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.nunito(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  overview.subtitle,
                  style: GoogleFonts.nunito(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.white.withValues(alpha: 0.58),
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: overview.chipBackground,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    overview.chipLabel,
                    style: GoogleFonts.nunito(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: overview.chipColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AddProfileCard extends StatelessWidget {
  const _AddProfileCard({
    required this.enabled,
    required this.onTap,
  });

  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: Colors.white.withValues(alpha: 0.04),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.18),
              style: BorderStyle.solid,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.08),
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.add_rounded,
                  size: 28,
                  color: enabled
                      ? Colors.white.withValues(alpha: 0.72)
                      : Colors.white.withValues(alpha: 0.28),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Profil Ekle',
                style: GoogleFonts.nunito(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: enabled
                      ? Colors.white.withValues(alpha: 0.74)
                      : Colors.white.withValues(alpha: 0.34),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                enabled ? 'Maks. 5 profil' : 'Limit doldu',
                style: GoogleFonts.nunito(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: Colors.white.withValues(alpha: 0.32),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CareSummaryCard extends StatelessWidget {
  const _CareSummaryCard({
    required this.overview,
    required this.isActive,
    required this.onTap,
    required this.onSwitchProfile,
    this.onSendReminder,
  });

  final _ProfileOverview overview;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback onSwitchProfile;
  final VoidCallback? onSendReminder;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: overview.requiresReminder
              ? const Color(0xFFFEE2E2)
              : (isDark ? AppTheme.darkBorder : AppTheme.borderColor),
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              Row(
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      _ProfileAvatar(profile: overview.profile, size: 42),
                      if (overview.urgentCount > 0)
                        Positioned(
                          top: -2,
                          right: -2,
                          child: Container(
                            width: 18,
                            height: 18,
                            decoration: BoxDecoration(
                              color: AppTheme.errorColor,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '${overview.urgentCount}',
                              style: GoogleFonts.nunito(
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          overview.profile.name,
                          style: GoogleFonts.nunito(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          '${overview.activeMedicineCount} ilac · Bugun ${overview.todayTaken}/${overview.todayTotal}',
                          style: GoogleFonts.nunito(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: isDark
                                ? const Color(0xFFD6D0E8)
                                : AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: overview.chipBackground,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${overview.percentLabel}${overview.isPerfectWeek ? ' 🔥' : ''}',
                      style: GoogleFonts.nunito(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: overview.chipColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: overview.weekRate,
                  minHeight: 5,
                  backgroundColor: AppTheme.accentColor,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    overview.progressColor,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              if (overview.medicineRows.isNotEmpty)
                Row(
                  children: overview.medicineRows.take(2).map((row) {
                    return Expanded(
                      child: Container(
                        margin: const EdgeInsets.only(right: 6),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: isDark ? AppTheme.darkSurface : Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isDark
                                ? AppTheme.darkBorder
                                : AppTheme.borderColor,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: row.statusColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                row.name,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.nunito(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            Text(
                              row.statusSymbol,
                              style: GoogleFonts.nunito(
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                color: row.statusColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              if (overview.requiresReminder && onSendReminder != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        color: Color(0xFF92400E),
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          overview.reminderMessage,
                          style: GoogleFonts.nunito(
                            fontSize: 11,
                            height: 1.35,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF92400E),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: onSendReminder,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.warningColor,
                          minimumSize: const Size(0, 36),
                        ),
                        child: Text(
                          'Gonder',
                          style:
                              GoogleFonts.nunito(fontWeight: FontWeight.w900),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onTap,
                      child: Text(
                        'Profili Duzenle',
                        style: GoogleFonts.nunito(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: isActive ? null : onSwitchProfile,
                      child: Text(
                        isActive ? 'Aktif Profil' : 'Bu Profili Ac',
                        style: GoogleFonts.nunito(fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PermissionTile extends StatelessWidget {
  const _PermissionTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.showDivider = false,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: showDivider
            ? Border(
                bottom: BorderSide(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? AppTheme.darkBorder
                      : AppTheme.borderColor,
                ),
              )
            : null,
      ),
      child: ListTile(
        title: Text(
          title,
          style: GoogleFonts.nunito(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(
          subtitle,
          style: GoogleFonts.nunito(fontSize: 11, fontWeight: FontWeight.w700),
        ),
        trailing: Switch.adaptive(
          value: value,
          activeTrackColor: AppTheme.primaryColor,
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({
    required this.profile,
    required this.size,
  });

  final Profile profile;
  final double size;

  @override
  Widget build(BuildContext context) {
    final base = Color(profile.colorValue);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [
            base,
            Color.lerp(base, Colors.white, 0.35) ?? base,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: base.withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        profile.initials.substring(0, profile.initials.length.clamp(1, 2)),
        style: GoogleFonts.nunito(
          fontSize: size * 0.34,
          fontWeight: FontWeight.w900,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _ProfileOverview {
  const _ProfileOverview({
    required this.profile,
    required this.activeMedicineCount,
    required this.todayTaken,
    required this.todayTotal,
    required this.urgentCount,
    required this.weekRate,
    required this.percentLabel,
    required this.chipLabel,
    required this.chipColor,
    required this.chipBackground,
    required this.progressColor,
    required this.subtitle,
    required this.medicineRows,
    required this.requiresReminder,
    required this.reminderMessage,
    required this.isPerfectWeek,
  });

  final Profile profile;
  final int activeMedicineCount;
  final int todayTaken;
  final int todayTotal;
  final int urgentCount;
  final double weekRate;
  final String percentLabel;
  final String chipLabel;
  final Color chipColor;
  final Color chipBackground;
  final Color progressColor;
  final String subtitle;
  final List<_MedicineRowStatus> medicineRows;
  final bool requiresReminder;
  final String reminderMessage;
  final bool isPerfectWeek;

  static _ProfileOverview fromProfile(Profile profile) {
    final now = DateTime.now();
    final startOfWeek = DateTime(now.year, now.month, now.day)
        .subtract(const Duration(days: 6));
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    final medicines = HiveService.getMedicinesForProfile(
      profile.id,
      activeOnly: true,
    );
    final todayLogs = HiveService.getDoseLogsForProfileDate(profile.id, now);
    final weekLogs = HiveService.getDoseLogsForProfileInRange(
      profile.id,
      startOfWeek,
      tomorrow,
    );

    final todayTaken =
        todayLogs.where((log) => log.status == DoseStatus.taken).length;
    final urgentCount = todayLogs.where((log) {
      if (log.status == DoseStatus.missed) {
        return true;
      }
      if (log.status == DoseStatus.pending ||
          log.status == DoseStatus.snoozed) {
        return log.scheduledTime.isBefore(now);
      }
      return false;
    }).length;

    final weekRate = weekLogs.isEmpty
        ? 0
        : weekLogs.where((log) => log.status == DoseStatus.taken).length /
            weekLogs.length;
    final percent = (weekRate * 100).round();

    final medicineRows = medicines.map((medicine) {
      final medicineLogs = todayLogs
          .where((log) => log.medicineId == medicine.id)
          .toList(growable: false);
      final hasMissed = medicineLogs.any((log) {
        if (log.status == DoseStatus.missed) {
          return true;
        }
        return (log.status == DoseStatus.pending ||
                log.status == DoseStatus.snoozed) &&
            log.scheduledTime.isBefore(now);
      });
      final hasPending = medicineLogs.any(
        (log) =>
            log.status == DoseStatus.pending ||
            log.status == DoseStatus.snoozed,
      );
      final allTaken = medicineLogs.isNotEmpty &&
          medicineLogs.every((log) => log.status == DoseStatus.taken);

      if (hasMissed) {
        return _MedicineRowStatus(
          name: medicine.name,
          statusColor: AppTheme.errorColor,
          statusSymbol: '!',
        );
      }
      if (hasPending) {
        return _MedicineRowStatus(
          name: medicine.name,
          statusColor: AppTheme.warningColor,
          statusSymbol: '•',
        );
      }
      if (allTaken) {
        return _MedicineRowStatus(
          name: medicine.name,
          statusColor: AppTheme.successColor,
          statusSymbol: '✓',
        );
      }
      return _MedicineRowStatus(
        name: medicine.name,
        statusColor: AppTheme.primaryColor,
        statusSymbol: '·',
      );
    }).toList()
      ..sort((a, b) => a.priority.compareTo(b.priority));

    final chipLabel = todayLogs.isEmpty
        ? 'Plan yok'
        : urgentCount > 0
            ? '$urgentCount atlandi'
            : todayTaken == todayLogs.length
                ? 'Tam uyum'
                : '$todayTaken/${todayLogs.length} ✓';

    final chipColor = urgentCount > 0
        ? const Color(0xFFFCA5A5)
        : todayLogs.isEmpty
            ? const Color(0xFFD6D0E8)
            : const Color(0xFF6EE7B7);
    final chipBackground = urgentCount > 0
        ? const Color(0x33EF4444)
        : todayLogs.isEmpty
            ? const Color(0x22FFFFFF)
            : const Color(0x3310B981);
    final progressColor = percent >= 85
        ? AppTheme.successColor
        : percent >= 70
            ? AppTheme.primaryColor
            : percent >= 50
                ? AppTheme.warningColor
                : AppTheme.errorColor;
    final subtitle = profile.isPrimarySelf
        ? 'Sen'
        : (profile.isCaregiverMode ? 'Bakici' : profile.relation);

    final reminderMessage = urgentCount > 0
        ? 'Bugun $urgentCount doz bekliyor. Hatirlatma gonder?'
        : 'Uyum dusuyor. Nazik bir hatirlatma gonder?';

    return _ProfileOverview(
      profile: profile,
      activeMedicineCount: medicines.length,
      todayTaken: todayTaken,
      todayTotal: todayLogs.length,
      urgentCount: urgentCount,
      weekRate: weekRate.clamp(0, 1).toDouble(),
      percentLabel: '%$percent',
      chipLabel: chipLabel,
      chipColor: chipColor,
      chipBackground: chipBackground,
      progressColor: progressColor,
      subtitle: subtitle,
      medicineRows: medicineRows,
      requiresReminder: urgentCount > 0 || weekRate < 0.65,
      reminderMessage: reminderMessage,
      isPerfectWeek: weekLogs.isNotEmpty &&
          weekLogs.every((log) => log.status == DoseStatus.taken),
    );
  }
}

class _MedicineRowStatus {
  const _MedicineRowStatus({
    required this.name,
    required this.statusColor,
    required this.statusSymbol,
  });

  final String name;
  final Color statusColor;
  final String statusSymbol;

  int get priority {
    if (statusColor == AppTheme.errorColor) {
      return 0;
    }
    if (statusColor == AppTheme.warningColor) {
      return 1;
    }
    if (statusColor == AppTheme.successColor) {
      return 2;
    }
    return 3;
  }
}
