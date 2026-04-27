import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/dose_log.dart';
import '../models/medicine.dart';
import '../services/hive_service.dart';
import '../services/notification_service.dart';
import '../utils/stats_calculator.dart';
import '../widgets/stats/stat_summary_grid.dart';
import '../widgets/stats/weekly_bar_chart.dart';
import '../widgets/stats/heatmap_card.dart';
import '../widgets/stats/medicine_breakdown_card.dart';

import '../services/pdf_service.dart';
import '../theme/app_theme.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> with WidgetsBindingObserver {
  _StatsView _selectedView = _StatsView.week;
  bool _isGeneratingPdf = false;
  bool _isApplyingInsight = false;

  

  

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      setState(() {});
    }
  }

  List<Medicine> get _medicines => HiveService.getActiveMedicines();

  List<DoseLog> get _logs90Days => HiveService.getRecentDoseLogs(days: 90);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final medicines = _medicines;
    final logs90Days = _logs90Days;
    final overallPercent = StatsCalculator.overallPercent(medicines, logs90Days);

    return Scaffold(
      backgroundColor:
          isDark ? AppTheme.darkBackground : AppTheme.backgroundColor,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            if (mounted) {
              setState(() {});
            }
          },
          color: AppTheme.primaryColor,
          child: ListView(
            padding: const EdgeInsets.only(bottom: 28),
            children: [
              _buildHeaderCard(
                medicines: medicines,
                overallPercent: overallPercent,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Column(
                  children: [
                    _buildViewSelector(isDark),
                    const SizedBox(height: 16),
                    _buildSelectedView(
                      isDark: isDark,
                      medicines: medicines,
                      logs90Days: logs90Days,
                      overallPercent: overallPercent,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderCard({
    required List<Medicine> medicines,
    required int overallPercent,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.primaryColor, AppTheme.primaryLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(28),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'İstatistikler',
                      style: GoogleFonts.nunito(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Haftalık genel bakış ve günlük uyum',
                      style: GoogleFonts.nunito(
                        fontSize: 12,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
              _buildPdfButton(),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _buildHeaderStatCard(
                  label: 'Genel Uyum',
                  value: '$overallPercent%',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildHeaderStatCard(
                  label: 'Aktif İlaç',
                  value: '${medicines.length}',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderStatCard({
    required String label,
    required String value,
  }) {
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
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPdfButton() {
    if (_isGeneratingPdf) {
      return Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Padding(
          padding: EdgeInsets.all(10),
          child: CircularProgressIndicator(
            color: Colors.white,
            strokeWidth: 2,
          ),
        ),
      );
    }

    return TextButton.icon(
      onPressed: () async {
        final messenger = ScaffoldMessenger.of(context);
        setState(() => _isGeneratingPdf = true);
        try {
          await PdfService.generateAndShareReport();
        } catch (e) {
          if (!mounted) {
            return;
          }
          messenger.showSnackBar(
            SnackBar(
              content: Text('Hata: $e', style: GoogleFonts.nunito()),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        } finally {
          if (mounted) {
            setState(() => _isGeneratingPdf = false);
          }
        }
      },
      style: TextButton.styleFrom(
        foregroundColor: Colors.white,
        backgroundColor: Colors.white.withValues(alpha: 0.16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      icon: const Icon(Icons.picture_as_pdf_rounded, size: 16),
      label: Text(
        'PDF',
        style: GoogleFonts.nunito(
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _buildViewSelector(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : AppTheme.accentColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: _StatsView.values.map((view) {
          final isSelected = _selectedView == view;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedView = view),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color:
                      isSelected ? AppTheme.primaryColor : Colors.transparent,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Text(
                  _viewLabel(view),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.nunito(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: isSelected
                        ? Colors.white
                        : (isDark ? Colors.white : AppTheme.primaryColor),
                  ),
                ),
              ),
            ),
          );
        }).toList(growable: false),
      ),
    );
  }

  String _viewLabel(_StatsView view) {
    return switch (view) {
      _StatsView.week => 'Hafta',
      _StatsView.month => 'Ay',
      _StatsView.quarter => '3 Ay',
    };
  }

  Widget _buildSelectedView({
    required bool isDark,
    required List<Medicine> medicines,
    required List<DoseLog> logs90Days,
    required int overallPercent,
  }) {
    return switch (_selectedView) {
      _StatsView.week => _buildWeeklyOverview(
          isDark: isDark,
          medicines: medicines,
          logs90Days: logs90Days,
          overallPercent: overallPercent,
        ),
      _StatsView.month => _buildMonthlyHeatmap(
          isDark: isDark,
          medicines: medicines,
          logs90Days: logs90Days,
        ),
      _StatsView.quarter => _buildQuarterHeatmap(
          isDark: isDark,
          medicines: medicines,
          logs90Days: logs90Days,
        ),
    };
  }

  Widget _buildWeeklyOverview({
    required bool isDark,
    required List<Medicine> medicines,
    required List<DoseLog> logs90Days,
    required int overallPercent,
  }) {
    final weekLogs = StatsCalculator.logsForDays(logs90Days, 7);
    final isUsingDemoData = medicines.isEmpty;
    final weeklyData =
        isUsingDemoData ? StatsCalculator.demoWeeklyData : StatsCalculator.calculateRealWeeklyData(weekLogs);
    final previousWeekLogs = StatsCalculator.logsInPastWindow(logs90Days, days: 7, offset: 7);
    final daySummaries = isUsingDemoData
        ? StatsCalculator.dailySummariesFromRates(weeklyData)
        : StatsCalculator.dailySummaries(weekLogs, 7);
    final adherenceRate = overallPercent;
    final takenCount = weekLogs.where((log) => log.status == DoseStatus.taken).length;
    final missedCount = weekLogs.where((log) => log.status == DoseStatus.missed).length;
    final totalCount = weekLogs.length;
    final streak = isUsingDemoData ? 3 : StatsCalculator.calculateStreak(logs90Days);
    final previousMissedCount =
        previousWeekLogs.where((log) => log.status == DoseStatus.missed).length;
    final insight = StatsCalculator.buildInsight(
      medicines: medicines,
      logs: StatsCalculator.logsForDays(logs90Days, 30),
      title: 'Gemini Tespiti',
      summaryPrefix: 'düzenli kaçırıyorsun.',
      improvementPrefix: 'Genel uyumun toparlanıyor.',
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Haftalık Genel Bakış', isDark),
        const SizedBox(height: 10),
        StatSummaryGrid(
          adherenceRate: adherenceRate,
          adherenceTrend: StatsCalculator.trendLabel(adherenceRate - StatsCalculator.adherenceRate(previousWeekLogs)),
          isAdherencePositive: adherenceRate >= StatsCalculator.adherenceRate(previousWeekLogs),
          streak: streak,
          takenCount: takenCount,
          totalCount: totalCount,
          missedCount: missedCount,
          missedTrend: StatsCalculator.missedTrendLabel(missedCount, previousMissedCount),
          isMissedPositive: missedCount <= previousMissedCount,
          isDark: isDark,
        ),
        const SizedBox(height: 16),
        WeeklyBarChart(
          weeklyData: weeklyData,
          daySummaries: daySummaries,
          isUsingDemoData: isUsingDemoData,
          isDark: isDark,
        ),
        const SizedBox(height: 12),
        MedicineBreakdownCard(
          medicines: medicines,
          logs: weekLogs,
          isDark: isDark,
          trailing: 'Son 7 gün',
        ),
        const SizedBox(height: 12),
        _buildInsightCard(
          insight: insight,
          isDark: isDark,
        ),
      ],
    );
  }

  Widget _buildMonthlyHeatmap({
    required bool isDark,
    required List<Medicine> medicines,
    required List<DoseLog> logs90Days,
  }) {
    final isUsingDemoData = medicines.isEmpty;
    final monthLogs = StatsCalculator.logsForDays(logs90Days, 35);
    final heatmapData =
        isUsingDemoData ? StatsCalculator.demoHeatmapData(35) : StatsCalculator.heatmapData(monthLogs, 35);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Aylık Isı Haritası', isDark),
        const SizedBox(height: 10),
        HeatmapCard(
          data: heatmapData,
          isDark: isDark,
          title: 'Uyum Isı Haritası',
          trailing: '35 gün',
          crossAxisCount: 7,
          showDemoBanner: isUsingDemoData,
        ),
        const SizedBox(height: 12),
        MedicineBreakdownCard(
          medicines: medicines,
          logs: monthLogs,
          isDark: isDark,
          trailing: 'Son 35 gün',
        ),
      ],
    );
  }

  Widget _buildQuarterHeatmap({
    required bool isDark,
    required List<Medicine> medicines,
    required List<DoseLog> logs90Days,
  }) {
    final isUsingDemoData = medicines.isEmpty;
    final heatmapData =
        isUsingDemoData ? StatsCalculator.demoHeatmapData(35) : StatsCalculator.heatmapData(logs90Days, 90);
    final lastSeven = isUsingDemoData
        ? StatsCalculator.dailySummariesFromRates(StatsCalculator.demoWeeklyData)
        : StatsCalculator.dailySummaries(StatsCalculator.logsForDays(logs90Days, 7), 7);
    final current30 = isUsingDemoData
        ? ((StatsCalculator.demoHeatmapPattern.reduce((a, b) => a + b) /
                    StatsCalculator.demoHeatmapPattern.length) *
                100)
            .round()
        : StatsCalculator.adherenceRate(StatsCalculator.logsForDays(logs90Days, 30));
    final previous30 =
        StatsCalculator.adherenceRate(StatsCalculator.logsInPastWindow(logs90Days, days: 30, offset: 30));
    final insight = StatsCalculator.buildInsight(
      medicines: medicines,
      logs: logs90Days,
      title: '3 Aylık Özet',
      summaryPrefix: 'hala zayıf noktan.',
      improvementPrefix: 'Geçen aya göre daha istikrarlısın.',
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('3 Aylık Isı Haritası', isDark),
        const SizedBox(height: 10),
        HeatmapCard(
          data: heatmapData,
          isDark: isDark,
          title: 'Uyum Isı Haritası',
          trailing: isUsingDemoData ? '35 gün demo' : '90 gün',
          crossAxisCount: 7,
          showDemoBanner: isUsingDemoData,
        ),
        const SizedBox(height: 12),
        _buildCardShell(
          isDark: isDark,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildCardTitle(
                title: 'Haftalık Seri',
                trailing: current30 >= previous30
                    ? '+${current30 - previous30}%'
                    : '${current30 - previous30}%',
                isDark: isDark,
              ),
              const SizedBox(height: 12),
              Row(
                children: lastSeven.map((day) {
                  final fullyTaken = day.total > 0 && day.taken == day.total;
                  final hasMissed = day.missed > 0;
                  final background = fullyTaken
                      ? AppTheme.primaryColor
                      : (hasMissed
                          ? AppTheme.errorColor.withValues(alpha: 0.82)
                          : (isDark
                              ? AppTheme.darkBorder
                              : const Color(0xFFE5E7EB)));
                  final mark = fullyTaken ? '✓' : (hasMissed ? '×' : '•');
                  return Expanded(
                    child: Column(
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: background,
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            StatsCalculator.weekdayShort(day.date),
                            style: GoogleFonts.nunito(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          mark,
                          style: GoogleFonts.nunito(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            color: fullyTaken
                                ? AppTheme.primaryColor
                                : (hasMissed
                                    ? AppTheme.errorColor
                                    : (isDark
                                        ? const Color(0xFFC4B7E9)
                                        : AppTheme.textSecondary)),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(growable: false),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _buildInsightCard(
          insight: insight,
          isDark: isDark,
        ),
      ],
    );
  }

  Widget _buildCardShell({
    required bool isDark,
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(16),
  }) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? AppTheme.darkBorder : AppTheme.borderColor,
        ),
      ),
      child: child,
    );
  }

  Widget _buildCardTitle({
    required String title,
    required String trailing,
    required bool isDark,
  }) {
    return Row(
      children: [
        Text(
          title,
          style: GoogleFonts.nunito(
            fontSize: 14,
            fontWeight: FontWeight.w900,
            color: isDark ? Colors.white : AppTheme.textPrimary,
          ),
        ),
        const Spacer(),
        Text(
          trailing,
          style: GoogleFonts.nunito(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: AppTheme.primaryColor,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title, bool isDark) {
    return Text(
      title,
      style: GoogleFonts.nunito(
        fontSize: 18,
        fontWeight: FontWeight.w900,
        color: isDark ? Colors.white : AppTheme.textPrimary,
      ),
    );
  }

  Widget _buildInsightCard({
    required InsightSuggestion insight,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.primaryColor, AppTheme.primaryLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            insight.title,
            style: GoogleFonts.nunito(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            insight.body,
            style: GoogleFonts.nunito(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              height: 1.45,
              color: Colors.white.withValues(alpha: 0.92),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              FilledButton(
                onPressed: insight.recommendedTime == null || _isApplyingInsight
                    ? null
                    : () => _applyInsight(insight),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppTheme.primaryColor,
                  minimumSize: const Size(0, 38),
                ),
                child: _isApplyingInsight
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppTheme.primaryColor,
                        ),
                      )
                    : Text(
                        insight.actionLabel,
                        style: GoogleFonts.nunito(fontWeight: FontWeight.w900),
                      ),
              ),
              const SizedBox(width: 10),
              OutlinedButton(
                onPressed: () => setState(() {}),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white24),
                  backgroundColor: Colors.white.withValues(alpha: 0.08),
                ),
                child: Text(
                  'Hayır',
                  style: GoogleFonts.nunito(fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _applyInsight(InsightSuggestion insight) async {
    if (insight.recommendedTime == null ||
        insight.targetMedicineId == null ||
        _isApplyingInsight) {
      return;
    }

    final medicine = HiveService.getMedicine(insight.targetMedicineId!);
    if (medicine == null) {
      return;
    }

    final updatedTimes = [...medicine.doseTimes];
    final slotIndex = updatedTimes.indexWhere(
      (value) => StatsCalculator.doseSlot(StatsCalculator.timeFromString(value)) == insight.slot,
    );
    if (slotIndex == -1) {
      return;
    }

    updatedTimes[slotIndex] = StatsCalculator.timeToString(insight.recommendedTime!);
    final normalized = updatedTimes.toSet().toList()..sort();
    final updatedMedicine = medicine.copyWith(
      firstDoseTime: normalized.first,
      reminderTimes: normalized,
    );

    setState(() => _isApplyingInsight = true);
    await NotificationService.cancelMedicineNotifications(medicine);
    await HiveService.updateMedicine(updatedMedicine);
    await HiveService.clearGeminiManagedAlarmsForMedicine(medicine.id);
    await HiveService.setGeminiManagedAlarm(
      medicine.id,
      StatsCalculator.timeToString(insight.recommendedTime!),
    );
    await NotificationService.scheduleMedicineNotifications(updatedMedicine);

    if (!mounted) {
      return;
    }

    setState(() => _isApplyingInsight = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${medicine.name} alarmı ${StatsCalculator.timeToString(insight.recommendedTime!)} saatine çekildi.',
          style: GoogleFonts.nunito(),
        ),
        backgroundColor: AppTheme.primaryColor,
      ),
    );
  }
}

enum _StatsView {
  week,
  month,
  quarter,
}
