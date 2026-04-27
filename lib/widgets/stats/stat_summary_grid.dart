import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/app_theme.dart';

class StatSummaryGrid extends StatelessWidget {
  final int adherenceRate;
  final String adherenceTrend;
  final bool isAdherencePositive;
  final int streak;
  final int takenCount;
  final int totalCount;
  final int missedCount;
  final String missedTrend;
  final bool isMissedPositive;
  final bool isDark;

  const StatSummaryGrid({
    super.key,
    required this.adherenceRate,
    required this.adherenceTrend,
    required this.isAdherencePositive,
    required this.streak,
    required this.takenCount,
    required this.totalCount,
    required this.missedCount,
    required this.missedTrend,
    required this.isMissedPositive,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 1.3,
      children: [
        _buildStatCard(
          label: 'Genel Uyum',
          value: '%$adherenceRate',
          subtext: adherenceTrend,
          subColor: isAdherencePositive ? AppTheme.takenColor : AppTheme.errorColor,
        ),
        _buildStatCard(
          label: 'Gün Serisi',
          value: '$streak',
          subtext: streak >= 5 ? 'Rekor seviyesinde' : 'Seriyi sürdür',
          subColor: AppTheme.warningColor,
        ),
        _buildStatCard(
          label: 'Alınan Doz',
          value: '$takenCount',
          subtext: '/ $totalCount toplam',
          subColor: isDark ? const Color(0xFFC4B7E9) : AppTheme.textSecondary,
        ),
        _buildStatCard(
          label: 'Atlanan Doz',
          value: '$missedCount',
          subtext: missedTrend,
          subColor: isMissedPositive ? AppTheme.takenColor : AppTheme.errorColor,
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String label,
    required String value,
    required String subtext,
    required Color subColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppTheme.darkBorder : AppTheme.borderColor,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withValues(alpha: isDark ? 0.08 : 0.04),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: GoogleFonts.nunito(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: isDark ? const Color(0xFFC4B7E9) : AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.nunito(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtext,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.nunito(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: subColor,
            ),
          ),
        ],
      ),
    );
  }
}
