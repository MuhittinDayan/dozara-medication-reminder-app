import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/ai_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/medicine_form_helper.dart';

class ScanReviewSheet extends StatelessWidget {
  const ScanReviewSheet({
    super.key,
    required this.result,
  });

  final MedicineScanResult result;

  static List<_ScanReviewField> _getScanReviewFields(MedicineScanResult result) {
    final entries = <(String, String, IconData)>[
      ('name', 'İlaç adı', Icons.medication_rounded),
      ('form', 'Form', Icons.category_rounded),
      ('dose', 'Doz', Icons.straighten_rounded),
      ('frequency', 'Günlük tekrar', Icons.schedule_rounded),
      ('meal', 'Yemek bilgisi', Icons.restaurant_rounded),
      ('usageNotes', 'Kullanım notu', Icons.notes_rounded),
    ];

    return entries
        .where((entry) => result[entry.$1] != null)
        .map(
          (entry) => _ScanReviewField(
            label: entry.$2,
            icon: entry.$3,
            suggestion: result[entry.$1]!,
            value: MedicineFormHelper.formatScanFieldValue(entry.$1, result[entry.$1]!.value),
          ),
        )
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fields = _getScanReviewFields(result);

    return FractionallySizedBox(
      heightFactor: 0.9,
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkSurface : Colors.white,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(28),
          ),
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 46,
              height: 4,
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.2)
                    : AppTheme.borderColor,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          AppTheme.primaryColor,
                          AppTheme.primaryLight,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.16),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(
                                Icons.auto_awesome_rounded,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'AI tarama sonucu hazır',
                                    style: GoogleFonts.nunito(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${fields.length} alan bulundu. Forma uygulamadan önce kontrol edin.',
                                    style: GoogleFonts.nunito(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white
                                          .withValues(alpha: 0.84),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            const _ScanSummaryChip(
                              icon: Icons.document_scanner_rounded,
                              label: 'OCR + AI inceleme',
                            ),
                            if (result['frequency'] != null)
                              _ScanSummaryChip(
                                icon: Icons.schedule_rounded,
                                label:
                                    '${result['frequency']!.value} kez/gün',
                              ),
                            if (result['meal'] != null)
                              _ScanSummaryChip(
                                icon: Icons.restaurant_rounded,
                                label: result['meal']!.value,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Önerilen alanlar',
                    style: GoogleFonts.nunito(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white : AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ...fields.map(
                    (field) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _ScanReviewFieldWidget(
                        field: field,
                        isDark: isDark,
                      ),
                    ),
                  ),
                  if (result.ocrText.trim().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      'OCR önizleme',
                      style: GoogleFonts.nunito(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppTheme.darkCard
                            : AppTheme.backgroundSecondary,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark
                              ? AppTheme.darkBorder
                              : AppTheme.borderColor,
                        ),
                      ),
                      child: Text(
                        result.ocrText.trim(),
                        maxLines: 6,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.nunito(
                          fontSize: 12,
                          height: 1.5,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? const Color(0xFFD6D0E8)
                              : AppTheme.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkSurface : Colors.white,
                border: Border(
                  top: BorderSide(
                    color:
                        isDark ? AppTheme.darkBorder : AppTheme.borderColor,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () =>
                          Navigator.of(context).pop(false),
                      child: const Text('Vazgeç'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => Navigator.of(context).pop(true),
                      icon: const Icon(Icons.check_rounded, size: 18),
                      label: const Text('Forma uygula'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScanSummaryChip extends StatelessWidget {
  const _ScanSummaryChip({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.nunito(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _ScanReviewFieldWidget extends StatelessWidget {
  const _ScanReviewFieldWidget({
    required this.field,
    required this.isDark,
  });

  final _ScanReviewField field;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final (confidenceLabel, confidenceColor, confidenceBackground) =
        MedicineFormHelper.scanConfidenceMeta(field.suggestion.confidence);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppTheme.darkBorder : AppTheme.borderColor,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkSurface : AppTheme.accentColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              field.icon,
              color: AppTheme.primaryColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        field.label,
                        style: GoogleFonts.nunito(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: confidenceBackground,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        confidenceLabel,
                        style: GoogleFonts.nunito(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          color: confidenceColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  field.value,
                  style: GoogleFonts.nunito(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  field.suggestion.source,
                  style: GoogleFonts.nunito(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? const Color(0xFFC4B7E9)
                        : AppTheme.textSecondary,
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

class _ScanReviewField {
  const _ScanReviewField({
    required this.label,
    required this.icon,
    required this.suggestion,
    required this.value,
  });

  final String label;
  final IconData icon;
  final ScanFieldSuggestion suggestion;
  final String value;
}
