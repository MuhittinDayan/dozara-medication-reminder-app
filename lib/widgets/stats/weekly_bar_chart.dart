import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/app_theme.dart';
import '../../utils/stats_calculator.dart';

class WeeklyBarChart extends StatelessWidget {
  final List<double> weeklyData;
  final List<DaySummary> daySummaries;
  final bool hasData;
  final bool isDark;

  const WeeklyBarChart({
    super.key,
    required this.weeklyData,
    required this.daySummaries,
    required this.hasData,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
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
                'Günlük Uyum',
                style: GoogleFonts.nunito(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : AppTheme.textPrimary,
                ),
              ),
              const Spacer(),
              Text(
                'Bu hafta',
                style: GoogleFonts.nunito(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.primaryColor,
                ),
              ),
            ],
          ),
          if (!hasData) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F3FF),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Ilac plani olusturduktan sonra gercek uyum verileri burada gorunecek.',
                style: GoogleFonts.nunito(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF7C3AED),
                ),
              ),
            ),
          ],
          const SizedBox(height: 14),
          SizedBox(
            height: 100,
            child: BarChart(
              BarChartData(
                maxY: 100,
                alignment: BarChartAlignment.spaceAround,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 25,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: isDark
                        ? AppTheme.darkBorder
                        : AppTheme.borderColor.withValues(alpha: 0.6),
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index < 0 || index >= daySummaries.length) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            StatsCalculator.weekdayShort(
                                daySummaries[index].date),
                            style: GoogleFonts.nunito(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: isDark
                                  ? Colors.white
                                  : AppTheme.textSecondary,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                barGroups: weeklyData.asMap().entries.map((entry) {
                  final rate = entry.value * 100;
                  final barColor = rate < 40
                      ? AppTheme.errorColor
                      : (rate <= 70
                          ? AppTheme.warningColor
                          : AppTheme.primaryColor);
                  return BarChartGroupData(
                    x: entry.key,
                    barRods: [
                      BarChartRodData(
                        toY: rate,
                        width: 20,
                        color: barColor,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(4),
                        ),
                      ),
                    ],
                  );
                }).toList(growable: false),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
