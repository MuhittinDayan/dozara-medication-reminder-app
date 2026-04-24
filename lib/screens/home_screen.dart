import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../models/dose_log.dart';
import '../models/medicine.dart';
import '../models/profile.dart';
import '../services/hive_service.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';
import 'add_medicine_screen.dart';
import 'family_profiles_screen.dart';
import 'medicine_detail_screen.dart';
import 'notification_center_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  List<DoseLog> _selectedDayDoses = [];
  List<Medicine> _activeMedicines = [];
  List<Medicine> _lowStockMedicines = [];
  List<DoseLog> _upcomingAgenda = [];
  DateTime _selectedDay = DateTime.now();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadData();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadData();
    }
  }

  Future<void> _loadData() async {
    await HiveService.syncDoseLogs();
    if (!mounted) {
      return;
    }

    setState(() {
      _selectedDayDoses = HiveService.getDoseLogsForDate(_selectedDay);
      _activeMedicines = HiveService.getActiveMedicines();
      _lowStockMedicines = HiveService.getLowStockMedicines();
      _upcomingAgenda =
          HiveService.getPendingFutureDoseLogs(daysAhead: 60).take(18).toList();
    });
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Günaydın';
    if (hour < 17) return 'İyi günler';
    if (hour < 21) return 'İyi akşamlar';
    return 'İyi geceler';
  }

  bool get _isSelectedDayToday {
    final now = DateTime.now();
    return now.year == _selectedDay.year &&
        now.month == _selectedDay.month &&
        now.day == _selectedDay.day;
  }

  int get _takenCount =>
      _selectedDayDoses.where((dose) => dose.status == DoseStatus.taken).length;

  int get _pendingCount => _selectedDayDoses
      .where(
        (dose) =>
            dose.status == DoseStatus.pending ||
            dose.status == DoseStatus.snoozed,
      )
      .length;

  int get _missedCount => _selectedDayDoses
      .where((dose) => dose.status == DoseStatus.missed)
      .length;

  double get _completionRate =>
      _selectedDayDoses.isEmpty ? 0 : _takenCount / _selectedDayDoses.length;

  bool get _showLegacyHeaderSummary => false;

  DoseLog? get _nextDose {
    final doses = [..._selectedDayDoses]
      ..sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));

    if (_isSelectedDayToday) {
      final now = DateTime.now();
      for (final dose in doses) {
        if (dose.scheduledTime.isAfter(now) &&
            dose.status != DoseStatus.taken &&
            dose.status != DoseStatus.missed) {
          return dose;
        }
      }
    }

    for (final dose in doses) {
      if (dose.status != DoseStatus.taken && dose.status != DoseStatus.missed) {
        return dose;
      }
    }

    return doses.isEmpty ? null : doses.first;
  }

  String get _nextDoseLabel {
    final dose = _nextDose;
    if (dose == null) {
      return '--:--';
    }
    return DateFormat('HH:mm').format(dose.scheduledTime);
  }

  String _profileDisplayName(Profile profile) {
    final name = profile.name.trim();
    return name.isEmpty ? 'Ben' : name;
  }

  String _profileAvatarLabel(Profile profile) {
    final initials = profile.initials.trim();
    return initials.isEmpty
        ? 'B'
        : initials.substring(0, initials.length.clamp(1, 2));
  }

  String get _selectedDayTitle =>
      _isSelectedDayToday ? 'Bugünkü İlaçlar' : 'Seçili Günün İlaçları';

  (String, Color, Color, double, IconData) _statusMeta(DoseStatus status) {
    return switch (status) {
      DoseStatus.taken => (
          'Alındı',
          AppTheme.takenColor,
          const Color(0xFFD1FAE5),
          1.0,
          Icons.check_rounded,
        ),
      DoseStatus.missed => (
          'Atlandı',
          AppTheme.missedColor,
          const Color(0xFFFEE2E2),
          0.15,
          Icons.close_rounded,
        ),
      DoseStatus.snoozed => (
          'Ertelendi',
          AppTheme.snoozedColor,
          const Color(0xFFDBEAFE),
          0.48,
          Icons.schedule_rounded,
        ),
      DoseStatus.pending => (
          'Bekliyor',
          AppTheme.pendingColor,
          const Color(0xFFFEF3C7),
          0.6,
          Icons.priority_high_rounded,
        ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkBackground : AppTheme.backgroundColor,
      ),
      child: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _loadData,
          color: AppTheme.primaryColor,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            children: [
              _buildHeader(isDark),
              _buildCalendarStrip(),
              _buildOverviewMetrics(isDark),
              if (_lowStockMedicines.isNotEmpty) _buildStockWarning(),
              _buildSectionTitle(
                _selectedDayTitle,
                icon: Icons.calendar_today_rounded,
                isDark: isDark,
              ),
              if (_selectedDayDoses.isEmpty)
                _buildNoDosesMessage(isDark)
              else
                for (final dose in _selectedDayDoses)
                  _buildDoseCard(dose, isDark),
              _buildSectionDivider(isDark),
              _buildSectionTitle(
                'Tüm İlaçlarım',
                icon: Icons.medication_rounded,
                isDark: isDark,
              ),
              if (_activeMedicines.isEmpty)
                _buildEmptyState(isDark)
              else
                for (final medicine in _activeMedicines)
                  _buildMedicineCard(medicine, isDark),
              if (_upcomingAgenda.isNotEmpty) _buildAgendaSection(isDark),
              const SizedBox(height: 112),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    final activeProfile = HiveService.getActiveProfile();
    final activeProfileName = _profileDisplayName(activeProfile);
    final nextDose = _nextDose;
    final nextMedicine =
        nextDose == null ? null : HiveService.getMedicine(nextDose.medicineId);
    final completionPercent = (_completionRate * 100).round();

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.primaryColor, AppTheme.primaryLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Merhaba, $activeProfileName',
                      style: GoogleFonts.nunito(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _isSelectedDayToday ? 'Bugünkü İlaçlar' : 'Seçili Gün',
                      style: GoogleFonts.nunito(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _selectedDayDoses.isEmpty
                          ? '${_greeting()} Bugün planlı ilaç görünmüyor.'
                          : 'Bugün $_takenCount/${_selectedDayDoses.length} doz tamamlandı.',
                      style: GoogleFonts.nunito(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.88),
                      ),
                    ),
                  ],
                ),
              ),
              _buildHeaderProfiles(activeProfile),
            ],
          ),
          const SizedBox(height: 16),
          _buildHeaderDoseHero(nextMedicine, completionPercent),
          if (_showLegacyHeaderSummary) const SizedBox(height: 10),
          if (_showLegacyHeaderSummary)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Günlük Uyum',
                          style: GoogleFonts.nunito(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Colors.white.withValues(alpha: 0.76),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$_takenCount/${_selectedDayDoses.length}',
                          style: GoogleFonts.nunito(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 34,
                    color: Colors.white.withValues(alpha: 0.16),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Sıradaki',
                        style: GoogleFonts.nunito(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Colors.white.withValues(alpha: 0.76),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _nextDoseLabel,
                        style: GoogleFonts.nunito(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeaderDoseHero(Medicine? nextMedicine, int completionPercent) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.17),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Text(
                nextMedicine?.formEmoji ?? '-',
                style: const TextStyle(fontSize: 24, color: Colors.white),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sıradaki doz',
                  style: GoogleFonts.nunito(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Colors.white.withValues(alpha: 0.74),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  nextMedicine?.name ?? 'Bugün doz yok',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.nunito(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: _completionRate.clamp(0, 1).toDouble(),
                    minHeight: 5,
                    backgroundColor: Colors.white.withValues(alpha: 0.18),
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _nextDoseLabel,
                style: GoogleFonts.nunito(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
              Text(
                '$completionPercent%',
                style: GoogleFonts.nunito(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: Colors.white.withValues(alpha: 0.78),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ignore: unused_element
  Widget _buildProfileSelector(Profile activeProfile) {
    final activeProfileName = _profileDisplayName(activeProfile);

    return Row(
      children: [
        Expanded(
          child: InkWell(
            onTap: () => _showProfileSwitcherSheet(activeProfile),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: Colors.white.withValues(alpha: 0.24),
                    child: Text(
                      _profileAvatarLabel(activeProfile),
                      style: GoogleFonts.nunito(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          activeProfileName,
                          style: GoogleFonts.nunito(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'Profil seçimi',
                          style: GoogleFonts.nunito(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.expand_more_rounded, color: Colors.white),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        InkWell(
          onTap: _showAddProfileDialog,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
            ),
            child: const Icon(Icons.add_rounded, color: Colors.white, size: 20),
          ),
        ),
      ],
    );
  }

  Widget _buildHeaderProfiles(Profile activeProfile) {
    final profiles = HiveService.getAllProfiles();
    final visibleProfiles = profiles.take(3).toList(growable: false);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: () => _showProfileSwitcherSheet(activeProfile),
          child: SizedBox(
            width: 34.0 + (visibleProfiles.length - 1).clamp(0, 3) * 22,
            height: 38,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                for (var index = 0; index < visibleProfiles.length; index++)
                  Positioned(
                    left: index * 22,
                    child: _buildHeaderAvatar(
                      visibleProfiles[index],
                      isActive: visibleProfiles[index].id == activeProfile.id,
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        _buildHeaderIconButton(
          icon: Icons.notifications_active_rounded,
          onTap: () async {
            await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const NotificationCenterScreen(),
              ),
            );
            if (mounted) {
              await _loadData();
            }
          },
        ),
      ],
    );
  }

  Widget _buildHeaderAvatar(Profile profile, {required bool isActive}) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Color(profile.colorValue),
        border: Border.all(
          color: isActive ? Colors.white : Colors.white.withValues(alpha: 0.42),
          width: isActive ? 2.2 : 1.4,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        _profileAvatarLabel(profile),
        style: GoogleFonts.nunito(
          fontSize: 11,
          fontWeight: FontWeight.w900,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildHeaderIconButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.18),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: Icon(icon, color: Colors.white, size: 18),
      ),
    );
  }

  Widget _buildCalendarStrip() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final today = DateTime.now();
    final centerDay =
        DateTime(_selectedDay.year, _selectedDay.month, _selectedDay.day);
    final days =
        List.generate(7, (index) => centerDay.add(Duration(days: index - 3)));

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
            color: isDark ? AppTheme.darkBorder : AppTheme.borderColor),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withValues(alpha: 0.08),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          for (var index = 0; index < days.length; index++) ...[
            Expanded(
              child: _buildCalendarDayCard(
                day: days[index],
                today: today,
                isDark: isDark,
              ),
            ),
            if (index < days.length - 1) const SizedBox(width: 6),
          ],
        ],
      ),
    );
  }

  Widget _buildCalendarDayCard({
    required DateTime day,
    required DateTime today,
    required bool isDark,
  }) {
    final isToday = day.day == today.day &&
        day.month == today.month &&
        day.year == today.year;
    final isSelected = day.year == _selectedDay.year &&
        day.month == _selectedDay.month &&
        day.day == _selectedDay.day;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedDay = day;
        });
        _loadData();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 66,
        decoration: BoxDecoration(
          gradient: isSelected
              ? const LinearGradient(
                  colors: [AppTheme.primaryColor, AppTheme.primaryLight],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: isSelected
              ? null
              : (isDark ? AppTheme.darkSurface : AppTheme.backgroundSecondary),
          borderRadius: BorderRadius.circular(14),
          border: isToday && !isSelected
              ? Border.all(color: AppTheme.primaryLight, width: 1.2)
              : null,
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppTheme.primaryColor.withValues(alpha: 0.24),
                    blurRadius: 16,
                    offset: const Offset(0, 7),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _calendarWeekdayLabel(day.weekday),
              style: GoogleFonts.nunito(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: isSelected
                    ? Colors.white.withValues(alpha: 0.86)
                    : (isDark
                        ? const Color(0xFFC4B7E9)
                        : AppTheme.textSecondary),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '${day.day}',
              style: GoogleFonts.nunito(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: isSelected
                    ? Colors.white
                    : (isDark ? Colors.white : AppTheme.textPrimary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _calendarWeekdayLabel(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return 'PZT';
      case DateTime.tuesday:
        return 'SAL';
      case DateTime.wednesday:
        return 'ÇAR';
      case DateTime.thursday:
        return 'PER';
      case DateTime.friday:
        return 'CUM';
      case DateTime.saturday:
        return 'CMT';
      case DateTime.sunday:
        return 'PAZ';
      default:
        return '';
    }
  }

  Widget _buildOverviewMetrics(bool isDark) {
    final completionPercent = (_completionRate * 100).round();
    final statusText = _selectedDayDoses.isEmpty
        ? 'Plan yok'
        : _missedCount > 0
            ? '$_missedCount doz atlandı'
            : completionPercent >= 100
                ? 'Tamamlandı'
                : '$completionPercent% tamam';

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? AppTheme.darkBorder : AppTheme.borderColor,
        ),
        boxShadow: [
          BoxShadow(
            color:
                AppTheme.primaryColor.withValues(alpha: isDark ? 0.12 : 0.08),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppTheme.primaryColor, AppTheme.primaryLight],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.insights_rounded,
                  color: Colors.white,
                  size: 19,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DateFormat('d MMMM yyyy', 'tr_TR').format(_selectedDay),
                      style: GoogleFonts.nunito(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : AppTheme.textPrimary,
                      ),
                    ),
                    Text(
                      statusText,
                      style: GoogleFonts.nunito(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: isDark
                            ? const Color(0xFFC4B7E9)
                            : AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.accentColor,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'Sıradaki $_nextDoseLabel',
                  style: GoogleFonts.nunito(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.primaryDark,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: _completionRate.clamp(0, 1).toDouble(),
              minHeight: 7,
              backgroundColor:
                  isDark ? AppTheme.darkSurface : AppTheme.backgroundSecondary,
              color: AppTheme.primaryColor,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _buildOverviewStat(
                  icon: Icons.medication_rounded,
                  label: 'Doz',
                  value: '${_selectedDayDoses.length}',
                  isDark: isDark,
                ),
              ),
              _buildMetricDivider(isDark),
              Expanded(
                child: _buildOverviewStat(
                  icon: Icons.check_circle_rounded,
                  label: 'Alındı',
                  value: '$_takenCount',
                  color: AppTheme.takenColor,
                  isDark: isDark,
                ),
              ),
              _buildMetricDivider(isDark),
              Expanded(
                child: _buildOverviewStat(
                  icon: Icons.schedule_rounded,
                  label: 'Bekleyen',
                  value: '$_pendingCount',
                  color: AppTheme.pendingColor,
                  isDark: isDark,
                ),
              ),
              _buildMetricDivider(isDark),
              Expanded(
                child: _buildOverviewStat(
                  icon: Icons.inventory_2_rounded,
                  label: 'Stok',
                  value: '${_lowStockMedicines.length}',
                  color: _lowStockMedicines.isEmpty
                      ? AppTheme.takenColor
                      : AppTheme.warningColor,
                  isDark: isDark,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewStat({
    required IconData icon,
    required String label,
    required String value,
    required bool isDark,
    Color color = AppTheme.primaryColor,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.nunito(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: isDark ? Colors.white : AppTheme.textPrimary,
          ),
        ),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.nunito(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: isDark ? const Color(0xFFC4B7E9) : AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildMetricDivider(bool isDark) {
    return Container(
      width: 1,
      height: 44,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      color: isDark ? AppTheme.darkBorder : AppTheme.borderColor,
    );
  }

  // ignore: unused_element
  Widget _buildSummaryCard(bool isDark) {
    final pending = _selectedDayDoses
        .where(
          (dose) =>
              dose.status == DoseStatus.pending ||
              dose.status == DoseStatus.snoozed,
        )
        .length;
    final missed = _selectedDayDoses
        .where((dose) => dose.status == DoseStatus.missed)
        .length;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppTheme.darkBorder : AppTheme.borderColor,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppTheme.accentColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.today_rounded,
                  color: AppTheme.primaryColor,
                  size: 18,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                DateFormat('d MMMM yyyy', 'tr_TR').format(_selectedDay),
                style: GoogleFonts.nunito(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _buildSummaryMetric(
                    'Toplam', '${_selectedDayDoses.length}'),
              ),
              const SizedBox(width: 8),
              Expanded(child: _buildSummaryMetric('Alındı', '$_takenCount')),
              const SizedBox(width: 8),
              Expanded(child: _buildSummaryMetric('Bekliyor', '$pending')),
              const SizedBox(width: 8),
              Expanded(child: _buildSummaryMetric('Atlandı', '$missed')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryMetric(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.backgroundSecondary.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: GoogleFonts.nunito(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppTheme.primaryColor,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.nunito(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAgendaSection(bool isDark) {
    final grouped = <String, List<DoseLog>>{};
    for (final dose in _upcomingAgenda) {
      final key = DateFormat('yyyy-MM-dd').format(dose.scheduledTime);
      grouped.putIfAbsent(key, () => []).add(dose);
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppTheme.darkBorder : AppTheme.borderColor,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.upcoming_rounded, color: AppTheme.primaryColor),
              const SizedBox(width: 8),
              Text(
                'Yaklasan Ajanda',
                style: GoogleFonts.nunito(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Haftalik ve aralikli tedavileri burada tarih bazli gorebilirsiniz.',
            style: GoogleFonts.nunito(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? const Color(0xFFC4B7E9) : AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          ...grouped.entries.take(5).map((entry) {
            final doses = entry.value;
            final day = doses.first.scheduledTime;
            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    DateFormat('d MMMM yyyy, EEEE', 'tr_TR').format(day),
                    style: GoogleFonts.nunito(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...doses.take(4).map((dose) {
                    final medicine = HiveService.getMedicine(dose.medicineId);
                    if (medicine == null) {
                      return const SizedBox.shrink();
                    }

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppTheme.darkSurface
                            : AppTheme.backgroundSecondary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: Color(medicine.colorValue)
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Center(
                              child: Text(
                                medicine.formEmoji,
                                style: const TextStyle(fontSize: 18),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  medicine.name,
                                  style: GoogleFonts.nunito(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                Text(
                                  '${DateFormat('HH:mm').format(dose.scheduledTime)} · ${medicine.scheduleDescription}',
                                  style: GoogleFonts.nunito(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
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
                  }),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildStockWarning() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFCD34D)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded, color: AppTheme.warningColor),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _lowStockMedicines
                  .map((medicine) =>
                      '${medicine.name} (${medicine.stockCount} adet)')
                  .join(', '),
              style: GoogleFonts.nunito(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF92400E),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(
    String title, {
    IconData? icon,
    required bool isDark,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 20,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          if (icon != null) ...[
            Icon(icon, size: 18, color: AppTheme.primaryColor),
            const SizedBox(width: 6),
          ],
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

  Widget _buildSectionDivider(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Divider(
        color: isDark ? AppTheme.darkBorder : AppTheme.borderColor,
        thickness: 0.5,
        height: 1,
      ),
    );
  }

  Widget _buildNoDosesMessage(bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? AppTheme.darkBorder
              : AppTheme.primaryColor.withValues(alpha: 0.12),
        ),
        boxShadow: [
          BoxShadow(
            color:
                AppTheme.primaryColor.withValues(alpha: isDark ? 0.12 : 0.08),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.primaryColor.withValues(alpha: 0.95),
                      AppTheme.primaryLight,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.event_available_rounded,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bugün sakin görünüyor',
                      style: GoogleFonts.nunito(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      DateFormat('d MMMM', 'tr_TR').format(_selectedDay),
                      style: GoogleFonts.nunito(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Bu gün için planlanmış doz yok. Takvimi gezebilir ya da yeni bir hatırlatıcı ekleyebilirsin.',
            style: GoogleFonts.nunito(
              fontSize: 12,
              height: 1.45,
              fontWeight: FontWeight.w700,
              color: isDark ? const Color(0xFFC4B7E9) : AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isDark
                  ? AppTheme.darkSurface
                  : AppTheme.accentColor.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              'İlaç planı oluştuğunda dozlar burada akışa düşer.',
              style: GoogleFonts.nunito(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: isDark ? const Color(0xFFD6D0E8) : AppTheme.primaryColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDoseCard(DoseLog dose, bool isDark) {
    final medicine = HiveService.getMedicine(dose.medicineId);
    if (medicine == null) {
      return const SizedBox.shrink();
    }

    final status = _statusMeta(dose.status);
    final medColor = Color(medicine.colorValue);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: status.$2.withValues(alpha: 0.45),
        ),
        boxShadow: [
          BoxShadow(
            color: status.$2.withValues(alpha: isDark ? 0.12 : 0.08),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: medColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      medicine.formEmoji,
                      style: const TextStyle(fontSize: 20),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        medicine.name,
                        style: GoogleFonts.nunito(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${DateFormat('HH:mm').format(dose.scheduledTime)} · ${medicine.formName}',
                        style: GoogleFonts.nunito(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? const Color(0xFFC4B7E9)
                              : AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: status.$3,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: status.$2.withValues(alpha: 0.45),
                    ),
                  ),
                  child: Icon(status.$5, size: 12, color: status.$2),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: status.$4,
                minHeight: 4,
                backgroundColor:
                    isDark ? AppTheme.darkSurface : AppTheme.accentColor,
                color: status.$2,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: status.$3,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    status.$1,
                    style: GoogleFonts.nunito(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: status.$2,
                    ),
                  ),
                ),
                const Spacer(),
                if (dose.status == DoseStatus.pending ||
                    dose.status == DoseStatus.snoozed) ...[
                  FilledButton(
                    onPressed: () => _markAsTaken(dose),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      minimumSize: const Size(0, 34),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    child: Text(
                      'Aldım',
                      style: GoogleFonts.nunito(fontWeight: FontWeight.w800),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: () => _snoozeDose(dose),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primaryColor,
                      minimumSize: const Size(0, 34),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    child: Text(
                      'Ertele',
                      style: GoogleFonts.nunito(fontSize: 11),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMedicineCard(Medicine medicine, bool isDark) {
    final medColor = Color(medicine.colorValue);
    final selectedDayDoses =
        HiveService.getDoseLogsForMedicineOnDate(medicine.id, _selectedDay);
    final takenCount = selectedDayDoses
        .where((dose) => dose.status == DoseStatus.taken)
        .length;
    final totalCount = selectedDayDoses.isEmpty
        ? medicine.remindersPerDay
        : selectedDayDoses.length;
    final progress = totalCount == 0 ? 0.0 : takenCount / totalCount;
    final hasMissed =
        selectedDayDoses.any((dose) => dose.status == DoseStatus.missed);
    final hasPending = selectedDayDoses.any(
      (dose) =>
          dose.status == DoseStatus.pending ||
          dose.status == DoseStatus.snoozed,
    );
    final statusColor = hasMissed
        ? AppTheme.missedColor
        : progress >= 1
            ? AppTheme.takenColor
            : hasPending
                ? AppTheme.pendingColor
                : medColor;
    final statusBackground = hasMissed
        ? const Color(0xFFFEE2E2)
        : progress >= 1
            ? const Color(0xFFD1FAE5)
            : hasPending
                ? const Color(0xFFFEF3C7)
                : medColor.withValues(alpha: 0.12);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasMissed || hasPending
              ? statusColor.withValues(alpha: 0.45)
              : (isDark ? AppTheme.darkBorder : AppTheme.borderColor),
        ),
        boxShadow: [
          BoxShadow(
            color: statusColor.withValues(alpha: isDark ? 0.12 : 0.08),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => _navigateToDetail(medicine),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: medColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    medicine.formEmoji,
                    style: const TextStyle(fontSize: 20),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      medicine.name,
                      style: GoogleFonts.nunito(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${medicine.scheduleDescription} · $takenCount/${medicine.remindersPerDay} alındı',
                      style: GoogleFonts.nunito(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? const Color(0xFFC4B7E9)
                            : AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: LinearProgressIndicator(
                        value: progress.clamp(0, 1).toDouble(),
                        minHeight: 4,
                        backgroundColor: isDark
                            ? AppTheme.darkSurface
                            : AppTheme.accentColor,
                        color: statusColor,
                      ),
                    ),
                    if (medicine.lowStockThreshold != null) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: medicine.isStockLow
                              ? const Color(0xFFFEF3C7)
                              : const Color(0xFFD1FAE5),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          'Stok: ${medicine.stockCount} adet',
                          style: GoogleFonts.nunito(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: medicine.isStockLow
                                ? const Color(0xFF92400E)
                                : const Color(0xFF065F46),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: statusBackground,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  progress >= 1
                      ? 'Tamam'
                      : hasMissed
                          ? 'Atlandı'
                          : hasPending
                              ? 'Bekliyor'
                              : 'Plan',
                  style: GoogleFonts.nunito(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark
              ? AppTheme.darkBorder
              : AppTheme.primaryColor.withValues(alpha: 0.14),
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withValues(alpha: isDark ? 0.12 : 0.1),
            blurRadius: 26,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppTheme.primaryColor, AppTheme.primaryLight],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryColor.withValues(alpha: 0.28),
                  blurRadius: 22,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: const Icon(
              Icons.medication_liquid_rounded,
              size: 38,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'İlk hatırlatıcını birlikte kuralım',
            style: GoogleFonts.nunito(
              fontSize: 19,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : AppTheme.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Text(
            'İlaç adı, saatleri ve stok takibi eklendiğinde ana ekran günlük sağlık akışına dönüşür.',
            style: GoogleFonts.nunito(
              fontSize: 12,
              height: 1.45,
              fontWeight: FontWeight.w600,
              color: isDark ? const Color(0xFFC4B7E9) : AppTheme.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 18),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildEmptyStepChip('Saat', Icons.schedule_rounded, isDark),
              _buildEmptyStepChip('Stok', Icons.inventory_2_rounded, isDark),
              _buildEmptyStepChip('Rutin', Icons.auto_awesome_rounded, isDark),
            ],
          ),
          const SizedBox(height: 16),
          _buildEmptyStateAddButton(),
        ],
      ),
    );
  }

  Widget _buildEmptyStepChip(String label, IconData icon, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : AppTheme.accentColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: AppTheme.primaryColor.withValues(alpha: isDark ? 0.24 : 0.12),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppTheme.primaryColor),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.nunito(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              color: isDark ? const Color(0xFFD6D0E8) : AppTheme.primaryColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyStateAddButton() {
    return GestureDetector(
      onTap: () async {
        final result = await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const AddMedicineScreen(),
          ),
        );
        if (result != null && mounted) {
          await _loadData();
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [
              AppTheme.primaryColor,
              AppTheme.primaryLight,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryColor.withValues(alpha: 0.3),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.add_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              'İlk İlacı Ekle',
              style: GoogleFonts.nunito(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _markAsTaken(DoseLog dose) async {
    await HiveService.markDoseAsTaken(dose.id);
    await _loadData();

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Doz alındı olarak işaretlendi.',
          style: GoogleFonts.nunito(),
        ),
        backgroundColor: AppTheme.takenColor,
      ),
    );
  }

  Future<void> _snoozeDose(DoseLog dose) async {
    final snoozedLog = await HiveService.snoozeDose(dose.id);
    if (snoozedLog != null) {
      await NotificationService.scheduleDoseLogNotifications(snoozedLog);
    }
    await _loadData();

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'İlaç 15 dakika ertelendi.',
          style: GoogleFonts.nunito(),
        ),
        backgroundColor: AppTheme.snoozedColor,
      ),
    );
  }

  Future<void> _navigateToDetail(Medicine medicine) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MedicineDetailScreen(medicine: medicine),
      ),
    );
    if (mounted) {
      await _loadData();
    }
  }

  void _showProfileSwitcherSheet(Profile activeProfile) {
    final profiles = HiveService.getAllProfiles();

    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(sheetContext).size.height * 0.78,
          ),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1F1535), Color(0xFF2D1F4E)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.28),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Text(
                    'Kim kullanıyor?',
                    style: GoogleFonts.nunito(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.of(sheetContext).pop(),
                    icon: Icon(
                      Icons.close_rounded,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (profiles.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 12, bottom: 8),
                  child: Text(
                    'Henüz profil yok. Yeni profil oluşturarak devam edin.',
                    style: GoogleFonts.nunito(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFFC4B7E9),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              Flexible(
                child: GridView.count(
                  shrinkWrap: true,
                  crossAxisCount: 2,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 0.92,
                  children: [
                    ...profiles.map(
                      (profile) => _buildProfileSwitchCard(
                        profile: profile,
                        isActive: profile.id == activeProfile.id,
                        onTap: () async {
                          await HiveService.setActiveProfile(profile.id);
                          if (!sheetContext.mounted) {
                            return;
                          }
                          Navigator.of(sheetContext).pop();
                          await _loadData();
                          if (mounted) {
                            setState(() {});
                          }
                        },
                      ),
                    ),
                    _buildAddProfileSwitchCard(
                      onTap: () {
                        Navigator.of(sheetContext).pop();
                        _showAddProfileDialog();
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    Navigator.of(sheetContext).pop();
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const FamilyProfilesScreen(),
                      ),
                    );
                    if (mounted) {
                      await _loadData();
                    }
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(
                      color: Colors.white.withValues(alpha: 0.18),
                    ),
                    backgroundColor: Colors.white.withValues(alpha: 0.04),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.manage_accounts_rounded, size: 18),
                  label: Text(
                    'Profilleri Yonet',
                    style: GoogleFonts.nunito(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProfileSwitchCard({
    required Profile profile,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    final summary = _profileDoseSummary(profile);
    final baseColor = Color(profile.colorValue);
    final avatarEnd = Color.lerp(baseColor, Colors.white, 0.35) ?? baseColor;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isActive
                ? AppTheme.primaryColor.withValues(alpha: 0.24)
                : Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isActive
                  ? AppTheme.primaryColor
                  : Colors.white.withValues(alpha: 0.10),
              width: isActive ? 2 : 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [baseColor, avatarEnd],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      _profileAvatarLabel(profile),
                      style: GoogleFonts.nunito(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  if (summary.missed > 0)
                    Positioned(
                      top: -4,
                      right: -4,
                      child: Container(
                        width: 22,
                        height: 22,
                        decoration: const BoxDecoration(
                          color: Color(0xFFEF4444),
                          shape: BoxShape.circle,
                          border: Border.fromBorderSide(
                            BorderSide(color: Color(0xFF2D1F4E), width: 2),
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '${summary.missed}',
                          style: GoogleFonts.nunito(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                _profileDisplayName(profile),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: GoogleFonts.nunito(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                profile.relation.trim().isEmpty ? 'Profil' : profile.relation,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: GoogleFonts.nunito(
                  color: Colors.white.withValues(alpha: 0.52),
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: summary.backgroundColor,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  summary.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.nunito(
                    color: summary.textColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAddProfileSwitchCard({required VoidCallback onTap}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: CustomPaint(
          painter: _DashedBorderPainter(
            color: Colors.white.withValues(alpha: 0.24),
            radius: 18,
          ),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.add_rounded,
                    color: Colors.white.withValues(alpha: 0.42),
                    size: 30,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Profil Ekle',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.nunito(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  _ProfileDoseSummary _profileDoseSummary(Profile profile) {
    final logs = HiveService.getDoseLogsForProfileDate(
      profile.id,
      DateTime.now(),
    );
    final total = logs.length;
    final taken = logs.where((log) => log.status == DoseStatus.taken).length;
    final missed = logs.where((log) => log.status == DoseStatus.missed).length;

    if (missed > 0) {
      return _ProfileDoseSummary(
        label: '$missed atlandi',
        missed: missed,
        textColor: const Color(0xFFFCA5A5),
        backgroundColor: const Color(0xFFEF4444).withValues(alpha: 0.28),
      );
    }

    if (total == 0) {
      return _ProfileDoseSummary(
        label: 'Bugun doz yok',
        missed: 0,
        textColor: const Color(0xFFD8B4FE),
        backgroundColor: Colors.white.withValues(alpha: 0.08),
      );
    }

    return _ProfileDoseSummary(
      label: '$taken/$total alindi',
      missed: 0,
      textColor: const Color(0xFF6EE7B7),
      backgroundColor: const Color(0xFF10B981).withValues(alpha: 0.28),
    );
  }

  void _showAddProfileDialog() {
    final nameController = TextEditingController();
    final profileColors = [
      Colors.blue,
      Colors.pink,
      Colors.orange,
      Colors.purple,
      Colors.teal,
    ];
    var selectedColor = profileColors.first;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final isDark = Theme.of(sheetContext).brightness == Brightness.dark;

        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.darkCard : Colors.white,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(28)),
                ),
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 42,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey[400],
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Yeni Profil',
                      style: GoogleFonts.nunito(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Kendiniz, anneniz veya başka bir yakınınız için ayrı takip alanı oluşturun.',
                      style: GoogleFonts.nunito(
                        fontSize: 14,
                        color: Colors.grey[500],
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 18),
                    TextField(
                      controller: nameController,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Profil adı',
                        hintText: 'Örn: Annem',
                        prefixIcon: Icon(Icons.person_rounded),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Renk Seç',
                      style: GoogleFonts.nunito(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: profileColors.map((color) {
                        final isSelected =
                            color.toARGB32() == selectedColor.toARGB32();
                        return GestureDetector(
                          onTap: () {
                            setSheetState(() {
                              selectedColor = color;
                            });
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: isSelected
                                  ? Border.all(color: Colors.white, width: 3)
                                  : null,
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: color.withValues(alpha: 0.55),
                                        blurRadius: 10,
                                        offset: const Offset(0, 3),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: isSelected
                                ? const Icon(
                                    Icons.check,
                                    color: Colors.white,
                                    size: 18,
                                  )
                                : null,
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () async {
                          final profileName = nameController.text.trim();
                          if (profileName.isEmpty) {
                            return;
                          }

                          final profile = Profile(
                            id: DateTime.now()
                                .millisecondsSinceEpoch
                                .toString(),
                            name: profileName,
                            colorValue: selectedColor.toARGB32(),
                            avatarUrl: '',
                          );

                          await HiveService.addProfile(profile);
                          await HiveService.setActiveProfile(profile.id);

                          if (!sheetContext.mounted) {
                            return;
                          }
                          Navigator.of(sheetContext).pop();
                          await _loadData();
                          if (mounted) {
                            setState(() {});
                          }
                        },
                        child: Text(
                          'Profili Oluştur',
                          style:
                              GoogleFonts.nunito(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).whenComplete(nameController.dispose);
  }
}

class _ProfileDoseSummary {
  const _ProfileDoseSummary({
    required this.label,
    required this.missed,
    required this.textColor,
    required this.backgroundColor,
  });

  final String label;
  final int missed;
  final Color textColor;
  final Color backgroundColor;
}

class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({
    required this.color,
    required this.radius,
  });

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Offset.zero & size,
          Radius.circular(radius),
        ),
      );

    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        canvas.drawPath(metric.extractPath(distance, distance + 7), paint);
        distance += 12;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) {
    return color != oldDelegate.color || radius != oldDelegate.radius;
  }
}
