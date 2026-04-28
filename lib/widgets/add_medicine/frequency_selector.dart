import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';

class FrequencySelector extends StatelessWidget {
  const FrequencySelector({
    super.key,
    required this.selectedFrequency,
    required this.onFrequencySelected,
    required this.isDark,
  });

  final int selectedFrequency;
  final ValueChanged<int> onFrequencySelected;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [1, 2, 3, 4, 6].map((freq) {
        final isSelected = selectedFrequency == freq;
        return InkWell(
          onTap: () => onFrequencySelected(freq),
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
              '$freq kez',
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
