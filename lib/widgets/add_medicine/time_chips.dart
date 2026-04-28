import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';

class TimeChips extends StatelessWidget {
  const TimeChips({
    super.key,
    required this.reminderTimes,
    required this.onTimeTap,
    required this.isDark,
  });

  final List<TimeOfDay> reminderTimes;
  final ValueChanged<int> onTimeTap;
  final bool isDark;

  String _timeToString(TimeOfDay value) {
    return '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ...reminderTimes.asMap().entries.map(
              (entry) => InkWell(
                onTap: () => onTimeTap(entry.key),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.darkCard : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color:
                          isDark ? AppTheme.darkBorder : AppTheme.borderColor,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${entry.key + 1}. doz',
                        style: GoogleFonts.nunito(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            entry.key == 0
                                ? Icons.wb_sunny_rounded
                                : Icons.schedule_rounded,
                            size: 14,
                            color: AppTheme.primaryColor,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            _timeToString(entry.value),
                            style: GoogleFonts.nunito(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color:
                                  isDark ? Colors.white : AppTheme.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: AppTheme.accentColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            'Bir saate dokunup düzenleyin',
            style: GoogleFonts.nunito(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: AppTheme.primaryColor,
            ),
          ),
        ),
      ],
    );
  }
}
