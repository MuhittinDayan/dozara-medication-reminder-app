import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../models/dose_log.dart';
import '../../models/medicine.dart';
import '../../theme/app_theme.dart';

class DoseCard extends StatefulWidget {
  final DoseLog dose;
  final Medicine medicine;
  final bool isDark;
  final VoidCallback onTake;
  final VoidCallback onSnooze;

  const DoseCard({
    super.key,
    required this.dose,
    required this.medicine,
    required this.isDark,
    required this.onTake,
    required this.onSnooze,
  });

  @override
  State<DoseCard> createState() => _DoseCardState();
}

class _DoseCardState extends State<DoseCard> {
  bool _isTaking = false;

  (String, Color, Color, double, IconData) _statusMeta(DoseStatus status) {
    return switch (status) {
      DoseStatus.taken => (
          'Alındı',
          AppTheme.takenColor,
          const Color(0xFFD1FAE5),
          1.0,
          Icons.check_rounded,
        ),
      DoseStatus.missed => (
          'Atlandı',
          AppTheme.missedColor,
          const Color(0xFFFEE2E2),
          0.15,
          Icons.close_rounded,
        ),
      DoseStatus.snoozed => (
          'Ertelendi',
          AppTheme.snoozedColor,
          const Color(0xFFDBEAFE),
          0.48,
          Icons.schedule_rounded,
        ),
      DoseStatus.pending => (
          'Bekliyor',
          AppTheme.pendingColor,
          const Color(0xFFFEF3C7),
          0.6,
          Icons.priority_high_rounded,
        ),
    };
  }

  Future<void> _handleTake() async {
    if (_isTaking) return;
    setState(() => _isTaking = true);
    await Future.delayed(const Duration(milliseconds: 600));
    widget.onTake();
  }

  @override
  Widget build(BuildContext context) {
    final status = _statusMeta(
      _isTaking ? DoseStatus.taken : widget.dose.status,
    );
    final medColor = Color(widget.medicine.colorValue);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      decoration: BoxDecoration(
        color: _isTaking
            ? AppTheme.takenColor.withValues(alpha: isDark ? 0.18 : 0.08)
            : (widget.isDark ? AppTheme.darkCard : Colors.white),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: status.$2.withValues(alpha: 0.45),
        ),
        boxShadow: [
          BoxShadow(
            color: status.$2.withValues(
              alpha: widget.isDark ? 0.12 : 0.08,
            ),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _isTaking
                        ? AppTheme.takenColor.withValues(alpha: 0.2)
                        : medColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: _isTaking
                        ? const Icon(
                            Icons.check_rounded,
                            color: AppTheme.takenColor,
                            size: 22,
                          )
                            .animate()
                            .scale(
                              begin: const Offset(0, 0),
                              end: const Offset(1, 1),
                              duration: 300.ms,
                              curve: Curves.elasticOut,
                            )
                        : Text(
                            widget.medicine.formEmoji,
                            style: const TextStyle(fontSize: 20),
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.medicine.name,
                        style: GoogleFonts.nunito(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${DateFormat('HH:mm').format(widget.dose.scheduledTime)} · ${widget.medicine.formName}',
                        style: GoogleFonts.nunito(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: widget.isDark
                              ? const Color(0xFFC4B7E9)
                              : AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Container(
                    key: ValueKey(status.$1),
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: status.$3,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: status.$2.withValues(alpha: 0.45),
                      ),
                    ),
                    child: Icon(status.$5, size: 12, color: status.$2),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                height: 4,
                child: LinearProgressIndicator(
                  value: status.$4,
                  minHeight: 4,
                  backgroundColor: widget.isDark
                      ? AppTheme.darkSurface
                      : AppTheme.accentColor,
                  color: status.$2,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: Container(
                    key: ValueKey(status.$1),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: status.$3,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      status.$1,
                      style: GoogleFonts.nunito(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: status.$2,
                      ),
                    ),
                  ),
                ),
                const Spacer(),
                if (!_isTaking &&
                    (widget.dose.status == DoseStatus.pending ||
                        widget.dose.status == DoseStatus.snoozed)) ...[
                  FilledButton(
                    onPressed: _handleTake,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      minimumSize: const Size(0, 34),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    child: Text(
                      'Aldım',
                      style: GoogleFonts.nunito(fontWeight: FontWeight.w800),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: widget.onSnooze,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primaryColor,
                      minimumSize: const Size(0, 34),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    child: Text(
                      'Ertele',
                      style: GoogleFonts.nunito(fontSize: 11),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(
          begin: 0.04,
          end: 0,
          duration: 300.ms,
          curve: Curves.easeOut,
        );
  }

  bool get isDark => widget.isDark;
}
