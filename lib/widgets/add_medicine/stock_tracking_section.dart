import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/medicine.dart';
import '../../theme/app_theme.dart';
import '../../utils/medicine_form_helper.dart';

class StockTrackingSection extends StatelessWidget {
  const StockTrackingSection({
    super.key,
    required this.isDark,
    required this.isEnabled,
    required this.onEnabledChanged,
    required this.stockCount,
    required this.onStockCountChanged,
    required this.selectedForm,
    required this.lowStockThreshold,
    required this.onThresholdChanged,
  });

  final bool isDark;
  final bool isEnabled;
  final ValueChanged<bool> onEnabledChanged;
  final int stockCount;
  final ValueChanged<int> onStockCountChanged;
  final MedicineForm selectedForm;
  final int lowStockThreshold;
  final ValueChanged<int> onThresholdChanged;

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
        boxShadow: [
          BoxShadow(
            color:
                AppTheme.primaryColor.withValues(alpha: isDark ? 0.12 : 0.08),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.zero,
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 18,
                  decoration: BoxDecoration(
                    color: const Color(0xFF7C3AED),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 10),
                const Icon(
                  Icons.inventory_2_rounded,
                  size: 18,
                  color: Color(0xFF7C3AED),
                ),
                const SizedBox(width: 6),
                Text(
                  'Stok Takibi',
                  style: GoogleFonts.nunito(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : AppTheme.textPrimary,
                  ),
                ),
                const Spacer(),
                Switch(
                  value: isEnabled,
                  activeThumbColor: const Color(0xFF7C3AED),
                  onChanged: onEnabledChanged,
                ),
              ],
            ),
          ),
          if (isEnabled)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Mevcut Stok',
                    style: GoogleFonts.nunito(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF7C3AED),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.darkSurface : Colors.white,
                      border: Border.all(color: const Color(0xFFDDD6FE)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () {
                            if (stockCount > 1) {
                              onStockCountChanged(stockCount - 1);
                            }
                          },
                          child: Container(
                            width: 48,
                            height: 48,
                            decoration: const BoxDecoration(
                              color: Color(0xFFEDE9FE),
                              borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(12),
                                bottomLeft: Radius.circular(12),
                              ),
                            ),
                            child: const Icon(
                              Icons.remove_rounded,
                              color: Color(0xFF7C3AED),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Column(
                            children: [
                              Text(
                                '$stockCount',
                                style: GoogleFonts.nunito(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: isDark
                                      ? Colors.white
                                      : const Color(0xFF1f1f1f),
                                ),
                                textAlign: TextAlign.center,
                              ),
                              Text(
                                MedicineFormHelper.localizedFormName(selectedForm).toLowerCase(),
                                style: GoogleFonts.nunito(
                                  fontSize: 10,
                                  color: isDark
                                      ? const Color(0xFFC4B7E9)
                                      : Colors.grey,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: () => onStockCountChanged(stockCount + 1),
                          child: Container(
                            width: 48,
                            height: 48,
                            decoration: const BoxDecoration(
                              color: Color(0xFF7C3AED),
                              borderRadius: BorderRadius.only(
                                topRight: Radius.circular(12),
                                bottomRight: Radius.circular(12),
                              ),
                            ),
                            child: const Icon(
                              Icons.add_rounded,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Uyarı Eşiği',
                    style: GoogleFonts.nunito(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF7C3AED),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [5, 7, 10, 14].map((days) {
                      final isSelected = lowStockThreshold == days;
                      return GestureDetector(
                        onTap: () => onThresholdChanged(days),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFF7C3AED)
                                : (isDark
                                    ? AppTheme.darkSurface
                                    : Colors.white),
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFF7C3AED)
                                  : const Color(0xFFDDD6FE),
                            ),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '$days gün kala',
                            style: GoogleFonts.nunito(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isSelected
                                  ? Colors.white
                                  : const Color(0xFF6D28D9),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F3FF),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.info_outline_rounded,
                          size: 14,
                          color: Color(0xFF7C3AED),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Stok $lowStockThreshold güne düşünce bildirim alacaksın.',
                            style: GoogleFonts.nunito(
                              fontSize: 11,
                              color: const Color(0xFF6D28D9),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
