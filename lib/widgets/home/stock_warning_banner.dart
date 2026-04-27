import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/medicine.dart';
import '../../theme/app_theme.dart';

class StockWarningBanner extends StatelessWidget {
  final List<Medicine> lowStockMedicines;

  const StockWarningBanner({
    super.key,
    required this.lowStockMedicines,
  });

  @override
  Widget build(BuildContext context) {
    if (lowStockMedicines.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFCD34D)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded, color: AppTheme.warningColor),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              lowStockMedicines
                  .map((medicine) =>
                      '${medicine.name} (${medicine.stockCount} adet)')
                  .join(', '),
              style: GoogleFonts.nunito(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF92400E),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
