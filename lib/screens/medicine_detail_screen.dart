import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../models/dose_log.dart';
import '../models/medicine.dart';
import '../services/hive_service.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';
import 'add_medicine_screen.dart';
import 'ai_assistant_screen.dart';

class MedicineDetailScreen extends StatefulWidget {
  const MedicineDetailScreen({
    super.key,
    required this.medicine,
  });

  final Medicine medicine;

  @override
  State<MedicineDetailScreen> createState() => _MedicineDetailScreenState();
}

class _MedicineDetailScreenState extends State<MedicineDetailScreen> {
  late Medicine _medicine;
  List<DoseLog> _todayDoses = [];
  List<DoseLog> _upcomingDoses = [];

  @override
  void initState() {
    super.initState();
    _medicine = widget.medicine;
    _loadData();
  }

  void _loadData() {
    final updatedMedicine = HiveService.getMedicine(_medicine.id);
    if (updatedMedicine == null) {
      return;
    }

    final now = DateTime.now();
    final upcoming = HiveService.getDoseLogsForMedicine(_medicine.id)
        .where(
          (log) =>
              (log.status == DoseStatus.pending ||
                  log.status == DoseStatus.snoozed) &&
              !log.scheduledTime.isBefore(now),
        )
        .take(8)
        .toList()
      ..sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));

    setState(() {
      _medicine = updatedMedicine;
      _todayDoses = HiveService.getDoseLogsForMedicineOnDate(
        _medicine.id,
        DateTime.now(),
      );
      _upcomingDoses = upcoming;
    });
  }

  int get _remainingDays {
    final today = DateTime.now();
    return _medicine.endDate
            .difference(DateTime(today.year, today.month, today.day))
            .inDays +
        1;
  }

  int get _takenToday =>
      _todayDoses.where((dose) => dose.status == DoseStatus.taken).length;

  double get _todayProgress =>
      _todayDoses.isEmpty ? 0 : _takenToday / _todayDoses.length;

  DoseLog? get _nextDose {
    final doses = [..._todayDoses]
      ..sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));
    final now = DateTime.now();
    for (final dose in doses) {
      if (dose.scheduledTime.isAfter(now) &&
          dose.status != DoseStatus.taken &&
          dose.status != DoseStatus.missed) {
        return dose;
      }
    }
    return doses.isEmpty ? null : doses.first;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final medColor = Color(_medicine.colorValue);

    return Scaffold(
      backgroundColor:
          isDark ? AppTheme.darkBackground : AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: isDark ? Colors.white : AppTheme.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'İlaç Detayı',
          style: GoogleFonts.nunito(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : AppTheme.textPrimary,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          _buildHeroCard(isDark, medColor),
          const SizedBox(height: 16),
          _buildSectionTitle('Tedavi Planı'),
          const SizedBox(height: 10),
          _buildInfoCard(
            isDark: isDark,
            children: [
              _buildInfoRow('Düzen', _medicine.scheduleDescription, isDark),
              _buildDivider(isDark),
              _buildInfoRow(
                'Başlangıç',
                DateFormat('dd.MM.yyyy').format(_medicine.startDate),
                isDark,
              ),
              _buildDivider(isDark),
              _buildInfoRow(
                'Bitiş',
                DateFormat('dd.MM.yyyy').format(_medicine.endDate),
                isDark,
              ),
              _buildDivider(isDark),
              _buildInfoRow('İlk Saat', _medicine.firstDoseTime, isDark),
              _buildDivider(isDark),
              _buildInfoRow(
                'Kullanım',
                _medicine.withFood ? 'Tok karnına' : 'Yemek şartı yok',
                isDark,
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildSectionTitle('Doz Saatleri'),
          const SizedBox(height: 10),
          _buildDoseTimesCard(isDark),
          const SizedBox(height: 16),
          _buildSectionTitle('Bugünkü Durum'),
          const SizedBox(height: 10),
          _buildTodayCard(isDark, medColor),
          const SizedBox(height: 16),
          _buildSectionTitle('Yaklaşan Ajanda'),
          const SizedBox(height: 10),
          _buildUpcomingCard(isDark, medColor),
          const SizedBox(height: 16),
          if (_medicine.lowStockThreshold != null) ...[
            _buildSectionTitle('Stok'),
            const SizedBox(height: 10),
            _buildStockCard(isDark, medColor),
            const SizedBox(height: 16),
          ],
          _buildSectionTitle('Gemini Asistan'),
          const SizedBox(height: 10),
          _buildAssistantCard(),
        ],
      ),
    );
  }

  Widget _buildHeroCard(bool isDark, Color medColor) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [medColor, Color.lerp(medColor, Colors.white, 0.32)!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: medColor.withValues(alpha: 0.28),
            blurRadius: 28,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.18),
                  ),
                ),
                child: Center(
                  child: Text(
                    _medicine.formEmoji,
                    style: const TextStyle(fontSize: 34),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _medicine.name,
                      style: GoogleFonts.nunito(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _medicine.dosage?.trim().isNotEmpty == true
                          ? '${_medicine.formName} · ${_medicine.dosage}'
                          : _medicine.formName,
                      style: GoogleFonts.nunito(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.white.withValues(alpha: 0.82),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildHeroChip(
                          _remainingDays > 0
                              ? '$_remainingDays gün kaldı'
                              : 'Tedavi bitti',
                        ),
                        _buildHeroChip('${_medicine.remindersPerDay}/gün'),
                        _buildHeroChip(_medicine.scheduleDescription),
                        if ((_medicine.note ?? '').trim().isNotEmpty)
                          _buildHeroChip('Not eklendi'),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildHeaderMetric(
                  'Bugün',
                  '$_takenToday/${_todayDoses.length}',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildHeaderMetric(
                  'Sıradaki',
                  _nextDose == null
                      ? '--:--'
                      : DateFormat('HH:mm').format(_nextDose!.scheduledTime),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildHeaderMetric(
                  'Uyum',
                  '${(_todayProgress * 100).round()}%',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: _todayProgress.clamp(0, 1).toDouble(),
              minHeight: 6,
              backgroundColor: Colors.white.withValues(alpha: 0.18),
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _editMedicine,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white24),
                    backgroundColor: Colors.white.withValues(alpha: 0.08),
                  ),
                  icon: const Icon(Icons.edit_rounded, size: 16),
                  label: const Text('Düzenle'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _showDeleteConfirmation,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white24),
                    backgroundColor: Colors.white.withValues(alpha: 0.08),
                  ),
                  icon: const Icon(Icons.delete_outline_rounded, size: 16),
                  label: const Text('Sil'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeroChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: GoogleFonts.nunito(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildHeaderMetric(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.nunito(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: Colors.white.withValues(alpha: 0.76),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.nunito(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            color: AppTheme.primaryColor,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: GoogleFonts.nunito(
            fontSize: 17,
            fontWeight: FontWeight.w900,
            color: isDark ? Colors.white : AppTheme.textPrimary,
          ),
        ),
      ],
    );
  }

  List<BoxShadow> _premiumShadow(bool isDark, [Color? color]) {
    return [
      BoxShadow(
        color: (color ?? AppTheme.primaryColor)
            .withValues(alpha: isDark ? 0.12 : 0.08),
        blurRadius: 22,
        offset: const Offset(0, 10),
      ),
    ];
  }

  Widget _buildInfoCard({
    required bool isDark,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? AppTheme.darkBorder : AppTheme.borderColor,
        ),
        boxShadow: _premiumShadow(isDark),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildDivider(bool isDark) {
    return Divider(
      height: 1,
      thickness: 1,
      color: isDark ? AppTheme.darkBorder : AppTheme.borderColor,
    );
  }

  Widget _buildInfoRow(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 88,
            child: Text(
              label,
              style: GoogleFonts.nunito(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: AppTheme.primaryColor,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.nunito(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : AppTheme.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDoseTimesCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? AppTheme.darkBorder : AppTheme.borderColor,
        ),
        boxShadow: _premiumShadow(isDark),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: _medicine.doseTimes
            .map(
              (time) => Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppTheme.darkSurface
                      : AppTheme.backgroundSecondary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  time,
                  style: GoogleFonts.nunito(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildTodayCard(bool isDark, Color medColor) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? AppTheme.darkBorder : AppTheme.borderColor,
        ),
        boxShadow: _premiumShadow(isDark, medColor),
      ),
      child: _todayDoses.isEmpty
          ? _buildDetailEmptyState(
              isDark: isDark,
              icon: Icons.event_available_rounded,
              title: 'Bugün sakin',
              message:
                  'Bu ilaç için bugün planlı doz yok. Yaklaşan dozlar oluştuğunda burada görünecek.',
            )
          : Column(
              children: _todayDoses
                  .map((dose) => _buildDoseRow(dose, isDark, medColor))
                  .toList(),
            ),
    );
  }

  Widget _buildDoseRow(DoseLog dose, bool isDark, Color medColor) {
    final (statusText, statusColor, badgeColor, icon) = switch (dose.status) {
      DoseStatus.taken => (
          'Alındı',
          AppTheme.takenColor,
          const Color(0xFFD1FAE5),
          Icons.check_rounded,
        ),
      DoseStatus.missed => (
          'Atlandı',
          AppTheme.missedColor,
          const Color(0xFFFEE2E2),
          Icons.close_rounded,
        ),
      DoseStatus.snoozed => (
          'Ertelendi',
          AppTheme.snoozedColor,
          const Color(0xFFDBEAFE),
          Icons.schedule_rounded,
        ),
      DoseStatus.pending => (
          'Bekliyor',
          AppTheme.pendingColor,
          const Color(0xFFFEF3C7),
          Icons.priority_high_rounded,
        ),
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : AppTheme.backgroundSecondary,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: badgeColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: statusColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  DateFormat('HH:mm').format(dose.scheduledTime),
                  style: GoogleFonts.nunito(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : AppTheme.textPrimary,
                  ),
                ),
                Text(
                  statusText,
                  style: GoogleFonts.nunito(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                ),
              ],
            ),
          ),
          if (dose.status == DoseStatus.pending)
            FilledButton(
              onPressed: () async {
                await HiveService.markDoseAsTaken(dose.id);
                _loadData();
                if (!mounted) {
                  return;
                }
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Doz alındı olarak işaretlendi.',
                      style: GoogleFonts.nunito(),
                    ),
                    backgroundColor: AppTheme.takenColor,
                  ),
                );
              },
              style: FilledButton.styleFrom(
                backgroundColor: medColor,
                minimumSize: const Size(0, 34),
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              child: const Text('Aldım'),
            ),
        ],
      ),
    );
  }

  Widget _buildUpcomingCard(bool isDark, Color medColor) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? AppTheme.darkBorder : AppTheme.borderColor,
        ),
        boxShadow: _premiumShadow(isDark, medColor),
      ),
      child: _upcomingDoses.isEmpty
          ? _buildDetailEmptyState(
              isDark: isDark,
              icon: Icons.calendar_month_rounded,
              title: 'Yaklaşan doz yok',
              message:
                  'Plan değiştiğinde ya da yeni hatırlatıcı eklendiğinde sıradaki dozlar burada listelenir.',
            )
          : Column(
              children: _upcomingDoses
                  .map(
                    (dose) => Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppTheme.darkSurface
                            : AppTheme.backgroundSecondary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: medColor.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.event_available_rounded,
                              color: medColor,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  DateFormat(
                                    'd MMMM yyyy, EEEE',
                                    'tr_TR',
                                  ).format(dose.scheduledTime),
                                  style: GoogleFonts.nunito(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: isDark
                                        ? Colors.white
                                        : AppTheme.textPrimary,
                                  ),
                                ),
                                Text(
                                  DateFormat('HH:mm')
                                      .format(dose.scheduledTime),
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
                    ),
                  )
                  .toList(),
            ),
    );
  }

  Widget _buildDetailEmptyState({
    required bool isDark,
    required IconData icon,
    required String title,
    required String message,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : AppTheme.backgroundSecondary,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark
              ? AppTheme.darkBorder
              : AppTheme.primaryColor.withValues(alpha: 0.1),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, size: 20, color: AppTheme.primaryColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.nunito(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  message,
                  style: GoogleFonts.nunito(
                    fontSize: 11,
                    height: 1.35,
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

  Widget _buildStockCard(bool isDark, Color medColor) {
    final stock = _medicine.stockCount ?? 0;
    final statusColor = _medicine.isStockEmpty
        ? AppTheme.errorColor
        : (_medicine.isStockLow ? AppTheme.warningColor : AppTheme.takenColor);
    final statusText = _medicine.isStockEmpty
        ? 'Stok bitti'
        : (_medicine.isStockLow ? 'Stok azalıyor' : 'Stok yeterli');

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? AppTheme.darkBorder : AppTheme.borderColor,
        ),
        boxShadow: _premiumShadow(isDark, statusColor),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.inventory_2_rounded, color: statusColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$stock adet',
                  style: GoogleFonts.nunito(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: statusColor,
                  ),
                ),
                Text(
                  statusText,
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
          OutlinedButton(
            onPressed: _showStockUpdateDialog,
            style: OutlinedButton.styleFrom(
              foregroundColor: medColor,
              side: BorderSide(color: medColor),
            ),
            child: const Text('Güncelle'),
          ),
        ],
      ),
    );
  }

  Widget _buildAssistantCard() {
    return InkWell(
      onTap: _openAssistantScreen,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppTheme.primaryColor, AppTheme.primaryLight],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: _premiumShadow(false, AppTheme.primaryColor),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.auto_awesome_rounded,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Gemini Asistan',
                    style: GoogleFonts.nunito(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    'Bu ilaç hakkında soru sor veya hızlı özet al.',
                    style: GoogleFonts.nunito(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.82),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Colors.white),
          ],
        ),
      ),
    );
  }

  Future<void> _openAssistantScreen() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AiAssistantScreen(medicine: _medicine),
      ),
    );
    if (mounted) {
      _loadData();
    }
  }

  Future<void> _editMedicine() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute<Object?>(
        builder: (_) => AddMedicineScreen(initialMedicine: _medicine),
      ),
    );

    if (!mounted || result == null) {
      return;
    }

    _loadData();

    if (result is Map<String, dynamic>) {
      final name = (result['name'] as String?)?.trim();
      final isEditing = result['isEditing'] == true;
      if (name != null && name.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isEditing ? '$name güncellendi.' : '$name kaydedildi.',
              style: GoogleFonts.nunito(),
            ),
            backgroundColor: AppTheme.primaryColor,
          ),
        );
      }
    }
  }

  void _showStockUpdateDialog() {
    final controller = TextEditingController(
      text: _medicine.stockCount?.toString() ?? '',
    );
    final medColor = Color(_medicine.colorValue);

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          'Stok Güncelle',
          style: GoogleFonts.nunito(fontWeight: FontWeight.w900),
        ),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Kalan miktar',
            suffixText: 'adet',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text('İptal', style: GoogleFonts.nunito()),
          ),
          FilledButton(
            onPressed: () async {
              final stock = int.tryParse(controller.text.trim());
              if (stock == null || stock < 0) {
                return;
              }

              await HiveService.updateStock(_medicine.id, stock);
              if (!dialogContext.mounted) {
                return;
              }
              Navigator.of(dialogContext).pop();
              _loadData();
            },
            style: FilledButton.styleFrom(backgroundColor: medColor),
            child: Text('Kaydet', style: GoogleFonts.nunito()),
          ),
        ],
      ),
    ).whenComplete(controller.dispose);
  }

  void _showDeleteConfirmation() {
    final parentNavigator = Navigator.of(context);

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          'İlacı Sil',
          style: GoogleFonts.nunito(fontWeight: FontWeight.w900),
        ),
        content: Text(
          '${_medicine.name} silinsin mi? Bu işlem geri alınamaz.',
          style: GoogleFonts.nunito(height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text('İptal', style: GoogleFonts.nunito()),
          ),
          FilledButton(
            onPressed: () async {
              await NotificationService.cancelMedicineNotifications(_medicine);
              await HiveService.deleteMedicine(_medicine.id);
              if (!dialogContext.mounted) {
                return;
              }
              Navigator.of(dialogContext).pop();
              parentNavigator.pop(true);
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
            ),
            child: Text('Sil', style: GoogleFonts.nunito()),
          ),
        ],
      ),
    );
  }

  /*
  void _showAIAssistantSheet() {
    final promptController = TextEditingController();
    var isLoading = false;
    var aiResponse = '';

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final isDark = Theme.of(sheetContext).brightness == Brightness.dark;

        return StatefulBuilder(
          builder: (context, setSheetState) {
            Future<void> listen() async {
              if (!_isListening) {
                final available = await _speech.initialize();
                if (!available) {
                  return;
                }
                setSheetState(() => _isListening = true);
                await _speech.listen(
                  localeId: 'tr_TR',
                  onResult: (value) {
                    setSheetState(() {
                      promptController.text = value.recognizedWords;
                    });
                  },
                );
              } else {
                await _speech.stop();
                setSheetState(() => _isListening = false);
              }
            }

            Future<void> askGemini() async {
              if (promptController.text.trim().isEmpty) {
                return;
              }

              setSheetState(() {
                isLoading = true;
                aiResponse = '';
              });

              try {
                final medicines = HiveService.getAllMedicines();
                final history = HiveService.getRecentDoseLogs();
                final response = await AIService.askAssistant(
                  promptController.text.trim(),
                  medicines,
                  history,
                );
                setSheetState(() {
                  aiResponse = response;
                  isLoading = false;
                });
              } on Object catch (e) {
                setSheetState(() {
                  aiResponse = 'Asistan yanıtı alınamadı: $e';
                  isLoading = false;
                });
              }
            }

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.darkCard : Colors.white,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(28),
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 42,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey[400],
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppTheme.primaryColor,
                            AppTheme.primaryLight
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.all(Radius.circular(16)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.auto_awesome_rounded,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Gemini Asistan',
                                  style: GoogleFonts.nunito(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                                Text(
                                  'İlacın kullanımıyla ilgili hızlı soru sorun.',
                                  style: GoogleFonts.nunito(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white.withValues(alpha: 0.82),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: promptController,
                      maxLines: 2,
                      minLines: 1,
                      decoration: InputDecoration(
                        hintText: 'Bu ilacin kullanimini sor...',
                        suffixIcon: IconButton(
                          onPressed: listen,
                          icon: Icon(
                            _isListening ? Icons.mic : Icons.mic_none,
                            color: _isListening
                                ? AppTheme.errorColor
                                : AppTheme.primaryColor,
                          ),
                        ),
                      ),
                    ),
                    if (aiResponse.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppTheme.darkSurface
                              : AppTheme.backgroundSecondary,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isDark
                                ? AppTheme.darkBorder
                                : AppTheme.borderColor,
                          ),
                        ),
                        child: Text(
                          aiResponse,
                          style: GoogleFonts.nunito(
                            fontSize: 13,
                            height: 1.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: isLoading ? null : askGemini,
                        child: isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Gonder'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).whenComplete(() async {
      await _speech.stop();
      if (mounted) {
        setState(() {
          _isListening = false;
        });
      }
      promptController.dispose();
    });
  }
  */
}
