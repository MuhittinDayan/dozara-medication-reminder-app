import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:flutter_animate/flutter_animate.dart';

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

  void _handleTake() async {
    setState(() => _isTaking = true);
    await Future.delayed(500.ms);
    if (mounted) {
      widget.onTake();
    }
  }

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

  @override
  Widget build(BuildContext context) {
    final status = _statusMeta(_isTaking ? DoseStatus.taken : widget.dose.status);
    final medColor = Color(widget.medicine.colorValue);

    Widget card = Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      decoration: BoxDecoration(
        color: widget.isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: status.$2.withValues(alpha: 0.45),
        ),
        boxShadow: [
          BoxShadow(
            color: status.$2.withValues(alpha: widget.isDark ? 0.12 : 0.08),
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
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: medColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
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
                Container(
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
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: status.$4,
                minHeight: 4,
                backgroundColor:
                    widget.isDark ? AppTheme.darkSurface : AppTheme.accentColor,
                color: status.$2,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
                const Spacer(),
                if (widget.dose.status == DoseStatus.pending ||
                    widget.dose.status == DoseStatus.snoozed) ...[
                  FilledButton(
                    onPressed: _isTaking ? null : _handleTake,
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
                    onPressed: _isTaking ? null : widget.onSnooze,
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
    );

    if (_isTaking) {
      card = card.animate()
          .shimmer(duration: 300.ms, color: AppTheme.takenColor.withValues(alpha: 0.3))
          .scaleXY(end: 0.8, duration: 500.ms, curve: Curves.easeIn)
          .fadeOut(duration: 500.ms);
    }

    return card;
  }
}
