import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/dose_log.dart';
import '../../models/medicine.dart';
import '../../theme/app_theme.dart';
import '../../utils/stats_calculator.dart';

class MedicineBreakdownCard extends StatelessWidget {
  final List<Medicine> medicines;
  final List<DoseLog> logs;
  final String trailing;
  final bool isDark;

  const MedicineBreakdownCard({
    super.key,
    required this.medicines,
    required this.logs,
    required this.trailing,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final medicineStats = medicines
        .map((medicine) => StatsCalculator.buildMedicineStat(medicine, logs))
        .toList(growable: false)
      ..sort((a, b) => b.volume.compareTo(a.volume));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? AppTheme.darkBorder : AppTheme.borderColor,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Ilac Bazli Dagilim',
                style: GoogleFonts.nunito(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : AppTheme.textPrimary,
                ),
              ),
              const Spacer(),
              Text(
                trailing,
                style: GoogleFonts.nunito(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (medicineStats.isEmpty)
            Text(
              'Ilac ekledikten sonra her ilacin uyum detayi burada gorunecek.',
              style: GoogleFonts.nunito(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                height: 1.4,
                color:
                    isDark ? const Color(0xFFC4B7E9) : AppTheme.textSecondary,
              ),
            )
          else
            ...medicineStats.map(
              (item) => Padding(
                padding: EdgeInsets.only(
                  bottom: item == medicineStats.last ? 0 : 10,
                ),
                child: _buildMedicineBreakdownRow(
                  stat: item,
                  isDark: isDark,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMedicineBreakdownRow({
    required MedicineStat stat,
    required bool isDark,
  }) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: stat.color.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Text(
            stat.medicine.formEmoji,
            style: const TextStyle(fontSize: 16),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            stat.medicine.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.nunito(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : AppTheme.textPrimary,
            ),
          ),
        ),
        Row(
          children: stat.last7Days.map((day) {
            final color = switch ((day.total, day.missed, day.taken)) {
              (0, _, _) => isDark ? AppTheme.darkBorder : AppTheme.borderColor,
              (_, > 0, _) => AppTheme.errorColor,
              (_, _, > 0) => AppTheme.primaryColor,
              _ => isDark ? const Color(0xFF6A5A95) : const Color(0xFFE5E7EB),
            };
            return Container(
              width: 7,
              height: 7,
              margin: const EdgeInsets.only(left: 3),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            );
          }).toList(growable: false),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 38,
          child: Text(
            '%${stat.rate}',
            textAlign: TextAlign.right,
            style: GoogleFonts.nunito(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color:
                  stat.rate < 60 ? AppTheme.errorColor : AppTheme.primaryColor,
            ),
          ),
        ),
      ],
    );
  }
}
