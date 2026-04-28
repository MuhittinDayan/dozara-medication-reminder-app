import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/medicine.dart';
import '../../theme/app_theme.dart';
import '../../utils/medicine_form_helper.dart';

class FormSelector extends StatelessWidget {
  const FormSelector({
    super.key,
    required this.selectedForm,
    required this.onFormSelected,
    required this.isDark,
  });

  final MedicineForm selectedForm;
  final ValueChanged<MedicineForm> onFormSelected;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    const forms = MedicineForm.values;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: forms.map((form) {
        final isSelected = selectedForm == form;
        return InkWell(
          onTap: () => onFormSelected(form),
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
              '${MedicineFormHelper.localizedFormEmoji(form)} ${MedicineFormHelper.localizedFormName(form)}',
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
