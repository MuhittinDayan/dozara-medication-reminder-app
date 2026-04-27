import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/app_theme.dart';

class CalendarStrip extends StatelessWidget {
  final DateTime selectedDay;
  final bool isDark;
  final ValueChanged<DateTime> onDaySelected;

  const CalendarStrip({
    super.key,
    required this.selectedDay,
    required this.isDark,
    required this.onDaySelected,
  });

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

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final centerDay =
        DateTime(selectedDay.year, selectedDay.month, selectedDay.day);
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
                isSelected: days[index].year == selectedDay.year &&
                    days[index].month == selectedDay.month &&
                    days[index].day == selectedDay.day,
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
    required bool isSelected,
    required bool isDark,
  }) {
    final isToday = day.day == today.day &&
        day.month == today.month &&
        day.year == today.year;

    return GestureDetector(
      onTap: () => onDaySelected(day),
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
}
