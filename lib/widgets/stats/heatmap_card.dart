import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/app_theme.dart';
import '../../utils/stats_calculator.dart';

class HeatmapCard extends StatelessWidget {
  final List<HeatCell> data;
  final String title;
  final String trailing;
  final int crossAxisCount;
  final bool hasData;
  final bool isDark;

  const HeatmapCard({
    super.key,
    required this.data,
    required this.title,
    required this.trailing,
    required this.crossAxisCount,
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
                title,
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
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: data.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: 4,
              mainAxisSpacing: 4,
              childAspectRatio: 1,
            ),
            itemBuilder: (context, index) {
              final item = data[index];
              return InkWell(
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        '${_dateLabel(item.date)}: %${item.rate}',
                        style: GoogleFonts.nunito(),
                      ),
                      backgroundColor: AppTheme.primaryColor,
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(4),
                child: Container(
                  decoration: BoxDecoration(
                    color: _heatmapColor(item.rate, isDark),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                'Az',
                style: GoogleFonts.nunito(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color:
                      isDark ? const Color(0xFFC4B7E9) : AppTheme.textSecondary,
                ),
              ),
              const SizedBox(width: 6),
              ...[0.1, 0.4, 0.7, 1.0].map((opacity) {
                return Container(
                  width: 10,
                  height: 10,
                  margin: const EdgeInsets.only(left: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: opacity),
                    borderRadius: BorderRadius.circular(3),
                  ),
                );
              }),
              const SizedBox(width: 6),
              Text(
                'Çok',
                style: GoogleFonts.nunito(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color:
                      isDark ? const Color(0xFFC4B7E9) : AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _heatmapColor(int rate, bool isDark) {
    if (rate == 0) {
      return isDark ? AppTheme.darkBorder : AppTheme.accentColor;
    }

    return AppTheme.primaryColor.withValues(
      alpha: (rate / 100).clamp(0.1, 1.0),
    );
  }

  String _dateLabel(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day.$month.${date.year}';
  }
}
