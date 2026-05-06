import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../models/medicine.dart';
import '../../models/profile.dart';
import '../../services/hive_service.dart';
import '../../theme/app_theme.dart';
import 'home_day_summary.dart';

class HomeHeader extends StatelessWidget {
  final Profile activeProfile;
  final HomeDaySummary summary;
  final int currentStreak;
  final bool isDark;
  final bool isSelectedDayToday;
  final Medicine? nextMedicine;
  final VoidCallback onNotificationsTap;
  final ValueChanged<Profile> onProfileTap;

  const HomeHeader({
    super.key,
    required this.activeProfile,
    required this.summary,
    required this.currentStreak,
    required this.isDark,
    required this.isSelectedDayToday,
    this.nextMedicine,
    required this.onNotificationsTap,
    required this.onProfileTap,
  });

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Günaydın';
    if (hour < 17) return 'İyi günler';
    if (hour < 21) return 'İyi akşamlar';
    return 'İyi geceler';
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

  String get _nextDoseLabel {
    final dose = summary.nextDose;
    if (dose == null) {
      return '--:--';
    }
    return DateFormat('HH:mm').format(dose.scheduledTime);
  }

  @override
  Widget build(BuildContext context) {
    final activeProfileName = _profileDisplayName(activeProfile);
    final completionPercent = (summary.completionRate * 100).round();

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
                    Row(
                      children: [
                        Text(
                          isSelectedDayToday ? 'Bugünkü İlaçlar' : 'Seçili Gün',
                          style: GoogleFonts.nunito(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        if (currentStreak > 0) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.orange.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                  color: Colors.orange.withValues(alpha: 0.5)),
                            ),
                            child: Text(
                              '🔥 $currentStreak gün',
                              style: GoogleFonts.nunito(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: Colors.orange.shade100,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      summary.totalCount == 0
                          ? '${_greeting()} Bugün planlı ilaç görünmüyor.'
                          : 'Bugün ${summary.takenCount}/${summary.totalCount} doz tamamlandı.',
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
                    value: summary.completionRate.clamp(0, 1).toDouble(),
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

  Widget _buildHeaderProfiles(Profile activeProfile) {
    final profiles = HiveService.getAllProfiles();
    final visibleProfiles = profiles.take(3).toList(growable: false);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: () => onProfileTap(activeProfile),
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
          onTap: onNotificationsTap,
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
}
