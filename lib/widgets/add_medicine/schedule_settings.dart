import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/medicine.dart';
import '../../theme/app_theme.dart';

class ScheduleTypeSelector extends StatelessWidget {
  const ScheduleTypeSelector({
    super.key,
    required this.selectedType,
    required this.onTypeSelected,
    required this.isDark,
  });

  final MedicineScheduleType selectedType;
  final ValueChanged<MedicineScheduleType> onTypeSelected;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final options = <(MedicineScheduleType, String)>[
      (MedicineScheduleType.daily, 'Her Gün'),
      (MedicineScheduleType.specificDays, 'Belirli Günler'),
      (MedicineScheduleType.interval, 'Aralıklı'),
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((option) {
        final isSelected = selectedType == option.$1;
        return InkWell(
          onTap: () => onTypeSelected(option.$1),
          borderRadius: BorderRadius.circular(999),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppTheme.primaryColor
                  : (isDark ? AppTheme.darkCard : Colors.white),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color:
                    isSelected ? AppTheme.primaryColor : AppTheme.borderColor,
              ),
            ),
            child: Text(
              option.$2,
              style: GoogleFonts.nunito(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: isSelected
                    ? Colors.white
                    : (isDark ? Colors.white : AppTheme.primaryDark),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class ScheduleSettings extends StatelessWidget {
  const ScheduleSettings({
    super.key,
    required this.selectedType,
    required this.selectedWeekdays,
    required this.onWeekdayToggle,
    required this.intervalDays,
    required this.onIntervalChanged,
    required this.isDark,
  });

  final MedicineScheduleType selectedType;
  final Set<int> selectedWeekdays;
  final ValueChanged<int> onWeekdayToggle;
  final int intervalDays;
  final ValueChanged<int> onIntervalChanged;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    switch (selectedType) {
      case MedicineScheduleType.daily:
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkSurface : AppTheme.backgroundSecondary,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? AppTheme.darkBorder : AppTheme.borderColor,
            ),
          ),
          child: Text(
            'Hatırlatmalar her gün çalışır.',
            style: GoogleFonts.nunito(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: isDark ? const Color(0xFFC4B7E9) : AppTheme.primaryDark,
            ),
          ),
        );
      case MedicineScheduleType.specificDays:
        const options = [
          (DateTime.monday, 'Pzt'),
          (DateTime.tuesday, 'Sal'),
          (DateTime.wednesday, 'Car'),
          (DateTime.thursday, 'Per'),
          (DateTime.friday, 'Cum'),
          (DateTime.saturday, 'Cmt'),
          (DateTime.sunday, 'Paz'),
        ];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: options.map((option) {
                final isSelected = selectedWeekdays.contains(option.$1);
                return InkWell(
                  onTap: () => onWeekdayToggle(option.$1),
                  borderRadius: BorderRadius.circular(999),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppTheme.primaryColor
                          : (isDark ? AppTheme.darkCard : Colors.white),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: isSelected
                            ? AppTheme.primaryColor
                            : AppTheme.borderColor,
                      ),
                    ),
                    child: Text(
                      option.$2,
                      style: GoogleFonts.nunito(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: isSelected
                            ? Colors.white
                            : (isDark ? Colors.white : AppTheme.primaryDark),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        );
      case MedicineScheduleType.interval:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Kaç günde bir hatırlatılsın?',
              style: GoogleFonts.nunito(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [2, 3, 7, 14, 30].map((days) {
                final isSelected = intervalDays == days;
                return InkWell(
                  onTap: () => onIntervalChanged(days),
                  borderRadius: BorderRadius.circular(999),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppTheme.primaryColor
                          : (isDark ? AppTheme.darkCard : Colors.white),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: isSelected
                            ? AppTheme.primaryColor
                            : AppTheme.borderColor,
                      ),
                    ),
                    child: Text(
                      _intervalChipLabel(days),
                      style: GoogleFonts.nunito(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: isSelected
                            ? Colors.white
                            : (isDark ? Colors.white : AppTheme.primaryDark),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        );
    }
  }

  String _intervalChipLabel(int days) {
    switch (days) {
      case 7:
        return 'Haftada bir';
      case 14:
        return '2 haftada bir';
      case 30:
        return 'Ayda bir';
      default:
        return '$days günde bir';
    }
  }
}
