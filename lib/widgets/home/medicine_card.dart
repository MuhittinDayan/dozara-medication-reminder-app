import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/dose_log.dart';
import '../../models/medicine.dart';
import '../../services/hive_service.dart';
import '../../theme/app_theme.dart';

class MedicineCard extends StatelessWidget {
  final Medicine medicine;
  final bool isDark;
  final DateTime selectedDay;
  final VoidCallback onTap;

  const MedicineCard({
    super.key,
    required this.medicine,
    required this.isDark,
    required this.selectedDay,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final medColor = Color(medicine.colorValue);
    final selectedDayDoses =
        HiveService.getDoseLogsForMedicineOnDate(medicine.id, selectedDay);
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
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: statusBackground,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: statusColor.withValues(alpha: 0.2),
                  ),
                ),
                child: Center(
                  child: Text(
                    medicine.formEmoji,
                    style: const TextStyle(fontSize: 22),
                  ),
                ),
              ),
              const SizedBox(width: 14),
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
                      medicine.scheduleDescription,
                      style: GoogleFonts.nunito(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? const Color(0xFFC4B7E9)
                            : AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(99),
                            child: LinearProgressIndicator(
                              value: progress.clamp(0, 1).toDouble(),
                              minHeight: 4,
                              backgroundColor: isDark
                                  ? AppTheme.darkSurface
                                  : AppTheme.backgroundSecondary,
                              color: statusColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '$takenCount / $totalCount',
                          style: GoogleFonts.nunito(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: statusColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: statusBackground,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      hasMissed
                          ? Icons.close_rounded
                          : progress >= 1
                              ? Icons.check_rounded
                              : Icons.schedule_rounded,
                      size: 14,
                      color: statusColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      hasMissed
                          ? 'Eksik'
                          : progress >= 1
                              ? 'Tamam'
                              : 'Bekliyor',
                      style: GoogleFonts.nunito(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
