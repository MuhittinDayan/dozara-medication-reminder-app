import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/dose_log.dart';
import '../models/medicine.dart';
import '../services/hive_service.dart';
import '../services/notification_service.dart';
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

  static const List<double> _demoWeeklyData = [
    0.9,
    0.4,
    1.0,
    0.2,
    0.8,
    0.7,
    0.0,
  ];

  static const List<double> _demoHeatmapPattern = [
    0.9,
    0.0,
    1.0,
    0.8,
    0.6,
    1.0,
    0.7,
    0.4,
    1.0,
    0.9,
    0.0,
    1.0,
    0.8,
    0.5,
    1.0,
    0.7,
    0.9,
    0.4,
    1.0,
    0.0,
    0.8,
    0.6,
    1.0,
    0.9,
    0.7,
    0.4,
    1.0,
    0.8,
    0.9,
    0.7,
    1.0,
    0.0,
    0.8,
    0.6,
    1.0,
  ];

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
    final overallPercent = _overallPercent(medicines, logs90Days);

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
    final weekLogs = _logsForDays(logs90Days, 7);
    final isUsingDemoData = medicines.isEmpty;
    final weeklyData =
        isUsingDemoData ? _demoWeeklyData : _calculateRealWeeklyData(weekLogs);
    final previousWeekLogs = _logsInPastWindow(logs90Days, days: 7, offset: 7);
    final daySummaries = isUsingDemoData
        ? _dailySummariesFromRates(weeklyData)
        : _dailySummaries(weekLogs, 7);
    final adherenceRate = overallPercent;
    final takenCount =
        weekLogs.where((log) => log.status == DoseStatus.taken).length;
    final missedCount =
        weekLogs.where((log) => log.status == DoseStatus.missed).length;
    final totalCount = weekLogs.length;
    final streak = _fullCompletionStreak(daySummaries);
    final previousMissedCount =
        previousWeekLogs.where((log) => log.status == DoseStatus.missed).length;
    final insight = _buildInsight(
      medicines: medicines,
      logs: _logsForDays(logs90Days, 30),
      title: 'Gemini Tespiti',
      summaryPrefix: 'duzenli kaciriyorsun.',
      improvementPrefix: 'Genel uyumun toparlaniyor.',
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Haftalik Genel Bakis', isDark),
        const SizedBox(height: 10),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 1.3,
          children: [
            _buildStatCard(
              label: 'Genel Uyum',
              value: '%$adherenceRate',
              subtext:
                  _trendLabel(adherenceRate - _adherenceRate(previousWeekLogs)),
              subColor: adherenceRate >= _adherenceRate(previousWeekLogs)
                  ? AppTheme.takenColor
                  : AppTheme.errorColor,
              isDark: isDark,
            ),
            _buildStatCard(
              label: 'Gun Serisi',
              value: '$streak',
              subtext: streak >= 5 ? 'Rekor seviyesinde' : 'Seriyi surdur',
              subColor: AppTheme.warningColor,
              isDark: isDark,
            ),
            _buildStatCard(
              label: 'Alinan Doz',
              value: '$takenCount',
              subtext: '/ $totalCount toplam',
              subColor:
                  isDark ? const Color(0xFFC4B7E9) : AppTheme.textSecondary,
              isDark: isDark,
            ),
            _buildStatCard(
              label: 'Atlanan Doz',
              value: '$missedCount',
              subtext: _missedTrendLabel(missedCount, previousMissedCount),
              subColor: missedCount <= previousMissedCount
                  ? AppTheme.takenColor
                  : AppTheme.errorColor,
              isDark: isDark,
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildCardShell(
          isDark: isDark,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildCardTitle(
                title: 'Gunluk Uyum',
                trailing: 'Bu hafta',
                isDark: isDark,
              ),
              if (isUsingDemoData) ...[
                const SizedBox(height: 10),
                _buildDemoDataBanner(),
              ],
              const SizedBox(height: 14),
              SizedBox(
                height: 100,
                child: BarChart(
                  BarChartData(
                    maxY: 100,
                    alignment: BarChartAlignment.spaceAround,
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      horizontalInterval: 25,
                      getDrawingHorizontalLine: (value) => FlLine(
                        color: isDark
                            ? AppTheme.darkBorder
                            : AppTheme.borderColor.withValues(alpha: 0.6),
                        strokeWidth: 1,
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    titlesData: FlTitlesData(
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: const SideTitles(showTitles: false),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            final index = value.toInt();
                            if (index < 0 || index >= daySummaries.length) {
                              return const SizedBox.shrink();
                            }
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                _weekdayShort(daySummaries[index].date),
                                style: GoogleFonts.nunito(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: isDark
                                      ? Colors.white
                                      : AppTheme.textSecondary,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    barGroups: weeklyData.asMap().entries.map((entry) {
                      final rate = entry.value * 100;
                      final barColor = rate < 40
                          ? AppTheme.errorColor
                          : (rate <= 70
                              ? AppTheme.warningColor
                              : AppTheme.primaryColor);
                      return BarChartGroupData(
                        x: entry.key,
                        barRods: [
                          BarChartRodData(
                            toY: rate,
                            width: 20,
                            color: barColor,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(4),
                            ),
                          ),
                        ],
                      );
                    }).toList(growable: false),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _buildMedicineBreakdownSection(
          medicines: medicines,
          logs: weekLogs,
          isDark: isDark,
          trailing: 'Son 7 gun',
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
    final monthLogs = _logsForDays(logs90Days, 35);
    final heatmapData =
        isUsingDemoData ? _demoHeatmapData(35) : _heatmapData(monthLogs, 35);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Aylik Isi Haritasi', isDark),
        const SizedBox(height: 10),
        _buildHeatmapCard(
          data: heatmapData,
          isDark: isDark,
          title: 'Uyum Isi Haritasi',
          trailing: '35 gun',
          crossAxisCount: 7,
          showDemoBanner: isUsingDemoData,
        ),
        const SizedBox(height: 12),
        _buildMedicineBreakdownSection(
          medicines: medicines,
          logs: monthLogs,
          isDark: isDark,
          trailing: 'Son 35 gun',
        ),
      ],
    );
  }

  Widget _buildHeatmapCard({
    required List<_HeatCell> data,
    required bool isDark,
    required String title,
    required String trailing,
    required int crossAxisCount,
    bool showDemoBanner = false,
  }) {
    return _buildCardShell(
      isDark: isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCardTitle(
            title: title,
            trailing: trailing,
            isDark: isDark,
          ),
          if (showDemoBanner) ...[
            const SizedBox(height: 10),
            _buildDemoDataBanner(),
          ],
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: SizedBox(
              width: 140,
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: data.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 3,
                  mainAxisSpacing: 3,
                  childAspectRatio: 1,
                ),
                itemBuilder: (context, index) {
                  final item = data[index];
                  return Center(
                    child: InkWell(
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              '${_dateLabel(item.date)}: %${item.rate}',
                              style: GoogleFonts.nunito(),
                            ),
                            backgroundColor: AppTheme.primaryColor,
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(3),
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: _heatmapColor(item.rate, isDark),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                'Az',
                style: GoogleFonts.nunito(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color:
                      isDark ? const Color(0xFFC4B7E9) : AppTheme.textSecondary,
                ),
              ),
              const SizedBox(width: 6),
              ...[0.1, 0.4, 0.7, 1.0].map((opacity) {
                return Container(
                  width: 10,
                  height: 10,
                  margin: const EdgeInsets.only(left: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: opacity),
                    borderRadius: BorderRadius.circular(3),
                  ),
                );
              }),
              const SizedBox(width: 6),
              Text(
                'Cok',
                style: GoogleFonts.nunito(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color:
                      isDark ? const Color(0xFFC4B7E9) : AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMedicineBreakdownSection({
    required List<Medicine> medicines,
    required List<DoseLog> logs,
    required bool isDark,
    required String trailing,
  }) {
    if (medicines.isEmpty) {
      return _buildCardShell(
        isDark: isDark,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCardTitle(
              title: 'Ilac Bazli Breakdown',
              trailing: trailing,
              isDark: isDark,
            ),
            const SizedBox(height: 12),
            Text(
              'Ilac ekledikten sonra her ilacin uyum detayi burada gorunecek',
              style: GoogleFonts.nunito(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                height: 1.4,
                color:
                    isDark ? const Color(0xFFC4B7E9) : AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            _buildDemoMedicineBreakdownRow(isDark),
          ],
        ),
      );
    }

    final medicineStats = medicines
        .map((medicine) => _buildMedicineStat(medicine, logs))
        .toList(growable: false)
      ..sort((a, b) => b.volume.compareTo(a.volume));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildCardShell(
          isDark: isDark,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildCardTitle(
                title: 'Ilac Bazli Breakdown',
                trailing: trailing,
                isDark: isDark,
              ),
              const SizedBox(height: 12),
              ...medicineStats.map(
                (item) => Padding(
                  padding: EdgeInsets.only(
                    bottom: item == medicineStats.last ? 0 : 10,
                  ),
                  child: _buildMedicineBreakdownRow(
                    stat: item,
                    isDark: isDark,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDemoMedicineBreakdownRow(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : AppTheme.backgroundSecondary,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Ornek ilac',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.nunito(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : AppTheme.textPrimary,
              ),
            ),
          ),
          Text(
            '████░░█',
            style: GoogleFonts.nunito(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              color: AppTheme.primaryColor,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '%71',
            style: GoogleFonts.nunito(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: AppTheme.primaryColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMedicineBreakdownRow({
    required _MedicineStat stat,
    required bool isDark,
  }) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: stat.color.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Text(
            stat.medicine.formEmoji,
            style: const TextStyle(fontSize: 16),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            stat.medicine.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.nunito(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : AppTheme.textPrimary,
            ),
          ),
        ),
        Row(
          children: stat.last7Days.map((day) {
            final color = switch ((day.total, day.missed, day.taken)) {
              (0, _, _) => isDark ? AppTheme.darkBorder : AppTheme.borderColor,
              (_, > 0, _) => AppTheme.errorColor,
              (_, _, > 0) => AppTheme.primaryColor,
              _ => isDark ? const Color(0xFF6A5A95) : const Color(0xFFE5E7EB),
            };
            return Container(
              width: 7,
              height: 7,
              margin: const EdgeInsets.only(left: 3),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            );
          }).toList(growable: false),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 38,
          child: Text(
            '%${stat.rate}',
            textAlign: TextAlign.right,
            style: GoogleFonts.nunito(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color:
                  stat.rate < 60 ? AppTheme.errorColor : AppTheme.primaryColor,
            ),
          ),
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
        isUsingDemoData ? _demoHeatmapData(35) : _heatmapData(logs90Days, 90);
    final lastSeven = isUsingDemoData
        ? _dailySummariesFromRates(_demoWeeklyData)
        : _dailySummaries(_logsForDays(logs90Days, 7), 7);
    final current30 = isUsingDemoData
        ? ((_demoHeatmapPattern.reduce((a, b) => a + b) /
                    _demoHeatmapPattern.length) *
                100)
            .round()
        : _adherenceRate(_logsForDays(logs90Days, 30));
    final previous30 =
        _adherenceRate(_logsInPastWindow(logs90Days, days: 30, offset: 30));
    final insight = _buildInsight(
      medicines: medicines,
      logs: logs90Days,
      title: '3 Aylik Ozet',
      summaryPrefix: 'hala zayif noktan.',
      improvementPrefix: 'Gecen aya gore daha istikrarlisin.',
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('3 Aylik Isi Haritasi', isDark),
        const SizedBox(height: 10),
        _buildHeatmapCard(
          data: heatmapData,
          isDark: isDark,
          title: 'Uyum Isi Haritasi',
          trailing: isUsingDemoData ? '35 gun demo' : '90 gun',
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
                title: 'Haftalik Seri',
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
                            _weekdayShort(day.date),
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

  Widget _buildStatCard({
    required String label,
    required String value,
    required String subtext,
    required Color subColor,
    required bool isDark,
  }) {
    return _buildCardShell(
      isDark: isDark,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: GoogleFonts.nunito(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: AppTheme.primaryColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.nunito(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtext,
            style: GoogleFonts.nunito(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: subColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInsightCard({
    required _InsightSuggestion insight,
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
                  'Hayir',
                  style: GoogleFonts.nunito(fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _applyInsight(_InsightSuggestion insight) async {
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
      (value) => _doseSlot(_timeFromString(value)) == insight.slot,
    );
    if (slotIndex == -1) {
      return;
    }

    updatedTimes[slotIndex] = _timeToString(insight.recommendedTime!);
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
      _timeToString(insight.recommendedTime!),
    );
    await NotificationService.scheduleMedicineNotifications(updatedMedicine);

    if (!mounted) {
      return;
    }

    setState(() => _isApplyingInsight = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${medicine.name} alarmi ${_timeToString(insight.recommendedTime!)} saatine cekildi.',
          style: GoogleFonts.nunito(),
        ),
        backgroundColor: AppTheme.primaryColor,
      ),
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

  Widget _buildDemoDataBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F3FF),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '✦ İlaç ekledikçe gerçek veriler burada görünecek',
        style: GoogleFonts.nunito(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: const Color(0xFF7C3AED),
        ),
      ),
    );
  }

  List<DoseLog> _logsForDays(List<DoseLog> logs, int days) {
    final start = DateTime.now().subtract(Duration(days: days - 1));
    final startDate = DateTime(start.year, start.month, start.day);
    return logs
        .where((log) => !log.scheduledTime.isBefore(startDate))
        .toList(growable: false);
  }

  List<DoseLog> _logsInPastWindow(
    List<DoseLog> logs, {
    required int days,
    required int offset,
  }) {
    final end = DateTime.now().subtract(Duration(days: offset));
    final start = end.subtract(Duration(days: days - 1));
    final startDate = DateTime(start.year, start.month, start.day);
    final endDate = DateTime(end.year, end.month, end.day, 23, 59, 59);
    return logs
        .where((log) => !log.scheduledTime.isBefore(startDate))
        .where((log) => !log.scheduledTime.isAfter(endDate))
        .toList(growable: false);
  }

  int _adherenceRate(List<DoseLog> logs) {
    if (logs.isEmpty) {
      return 0;
    }
    final taken = logs.where((log) => log.status == DoseStatus.taken).length;
    return ((taken / logs.length) * 100).round();
  }

  int _overallPercent(List<Medicine> medicines, List<DoseLog> logs90Days) {
    if (medicines.isEmpty) {
      final average =
          _demoWeeklyData.reduce((a, b) => a + b) / _demoWeeklyData.length;
      return (average * 100).round();
    }

    return _adherenceRate(_logsForDays(logs90Days, 7));
  }

  List<double> _calculateRealWeeklyData(List<DoseLog> logs) {
    return _dailySummaries(logs, 7)
        .map((summary) => summary.rate / 100)
        .toList(growable: false);
  }

  List<_DaySummary> _dailySummariesFromRates(List<double> rates) {
    final startDate = rates.length == 7
        ? _startOfCurrentWeek()
        : DateTime.now().subtract(Duration(days: rates.length - 1));
    return List.generate(rates.length, (index) {
      final date = DateTime(
        startDate.year,
        startDate.month,
        startDate.day,
      ).add(Duration(days: index));
      final normalizedRate = rates[index].clamp(0.0, 1.0);
      const total = 10;
      final taken = (normalizedRate * total).round();

      return _DaySummary(
        date: date,
        total: total,
        taken: taken,
        missed: total - taken,
        rate: (normalizedRate * 100).round(),
      );
    });
  }

  List<_DaySummary> _dailySummaries(List<DoseLog> logs, int days) {
    final today = DateTime.now();
    final startDate = days == 7
        ? _startOfCurrentWeek()
        : DateTime(
            today.year,
            today.month,
            today.day,
          ).subtract(Duration(days: days - 1));
    return List.generate(days, (index) {
      final date = DateTime(
        startDate.year,
        startDate.month,
        startDate.day,
      ).add(Duration(days: index));
      final dayLogs = logs.where((log) => _isSameDay(log.scheduledTime, date));
      final total = dayLogs.length;
      final taken =
          dayLogs.where((log) => log.status == DoseStatus.taken).length;
      final missed =
          dayLogs.where((log) => log.status == DoseStatus.missed).length;
      final rate = total == 0 ? 0 : ((taken / total) * 100).round();

      return _DaySummary(
        date: date,
        total: total,
        taken: taken,
        missed: missed,
        rate: rate,
      );
    });
  }

  DateTime _startOfCurrentWeek() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return today.subtract(Duration(days: today.weekday - DateTime.monday));
  }

  int _fullCompletionStreak(List<_DaySummary> summaries) {
    var streak = 0;
    for (final summary in summaries.reversed) {
      if (summary.total > 0 && summary.taken == summary.total) {
        streak++;
      } else {
        break;
      }
    }
    return streak;
  }

  String _trendLabel(int diff) {
    if (diff > 0) {
      return '↑ $diff%';
    }
    if (diff < 0) {
      return '↓ ${diff.abs()}%';
    }
    return '→ degismedi';
  }

  String _missedTrendLabel(int current, int previous) {
    if (previous == 0 && current == 0) {
      return 'hic atlama yok';
    }
    if (current < previous) {
      return '↓ gecen hafta $previous';
    }
    if (current > previous) {
      return '↑ gecen hafta $previous';
    }
    return '→ gecen hafta ile ayni';
  }

  _MedicineStat _buildMedicineStat(Medicine medicine, List<DoseLog> logs) {
    final medicineLogs = logs
        .where((log) => log.medicineId == medicine.id)
        .toList(growable: false);
    final rate = _adherenceRate(medicineLogs);
    final last7 = _dailySummaries(medicineLogs, 7);

    return _MedicineStat(
      medicine: medicine,
      rate: rate,
      volume: medicineLogs.length,
      color: Color(medicine.colorValue),
      last7Days: last7,
    );
  }

  List<_HeatCell> _heatmapData(List<DoseLog> logs, int days) {
    final today = DateTime.now();
    return List.generate(days, (index) {
      final date = DateTime(
        today.year,
        today.month,
        today.day,
      ).subtract(Duration(days: days - 1 - index));
      final dayLogs = logs.where((log) => _isSameDay(log.scheduledTime, date));
      final total = dayLogs.length;
      final taken =
          dayLogs.where((log) => log.status == DoseStatus.taken).length;
      final rate = total == 0 ? 0 : ((taken / total) * 100).round();
      return _HeatCell(date: date, rate: rate);
    });
  }

  List<_HeatCell> _demoHeatmapData(int days) {
    final today = DateTime.now();
    return List.generate(days, (index) {
      final date = DateTime(
        today.year,
        today.month,
        today.day,
      ).subtract(Duration(days: days - 1 - index));
      final value = _demoHeatmapPattern[index % _demoHeatmapPattern.length];
      return _HeatCell(
        date: date,
        rate: (value.clamp(0.0, 1.0) * 100).round(),
      );
    });
  }

  Color _heatmapColor(int rate, bool isDark) {
    if (rate == 0) {
      return isDark ? AppTheme.darkBorder : AppTheme.accentColor;
    }

    return AppTheme.primaryColor.withValues(
      alpha: (rate / 100).clamp(0.1, 1.0),
    );
  }

  String _dateLabel(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day.$month.${date.year}';
  }

  _InsightSuggestion _buildInsight({
    required List<Medicine> medicines,
    required List<DoseLog> logs,
    required String title,
    required String summaryPrefix,
    required String improvementPrefix,
  }) {
    final missedLogs = logs
        .where((log) => log.status == DoseStatus.missed)
        .toList(growable: false);
    if (missedLogs.isEmpty || medicines.isEmpty) {
      return _InsightSuggestion(
        title: title,
        body: '$improvementPrefix Bu donemde kacirilan belirgin bir desen yok.',
        actionLabel: 'Tamam',
      );
    }

    final weekdayCount = <int, int>{};
    final medicineCount = <String, int>{};
    final slotCount = <_DoseSlot, int>{};

    for (final log in missedLogs) {
      weekdayCount.update(log.scheduledTime.weekday, (value) => value + 1,
          ifAbsent: () => 1);
      medicineCount.update(log.medicineId, (value) => value + 1,
          ifAbsent: () => 1);
      slotCount.update(
          _doseSlot(_timeFromDateTime(log.scheduledTime)), (value) => value + 1,
          ifAbsent: () => 1);
    }

    final weakWeekday = weekdayCount.entries.reduce(
      (a, b) => a.value >= b.value ? a : b,
    );
    final weakMedicineId = medicineCount.entries.reduce(
      (a, b) => a.value >= b.value ? a : b,
    );
    final weakSlot = slotCount.entries
        .reduce(
          (a, b) => a.value >= b.value ? a : b,
        )
        .key;

    final medicine = medicines.firstWhere(
      (item) => item.id == weakMedicineId.key,
      orElse: () => medicines.first,
    );
    final currentTime = medicine.doseTimes.map(_timeFromString).firstWhere(
          (time) => _doseSlot(time) == weakSlot,
          orElse: () => medicine.doseTimes.isEmpty
              ? const TimeOfDay(hour: 13, minute: 30)
              : _timeFromString(medicine.doseTimes.first),
        );
    final suggestedTime = _shiftTime(currentTime, -30);

    return _InsightSuggestion(
      title: title,
      body:
          '${_weekdayLong(weakWeekday.key)} ${_slotLabel(weakSlot)} dozlarinda ${medicine.name} $summaryPrefix Alarmi ${_timeToString(suggestedTime)} saatine cekebilirim.',
      actionLabel: 'Evet, ayarla',
      targetMedicineId: medicine.id,
      recommendedTime: suggestedTime,
      slot: weakSlot,
    );
  }

  String _weekdayShort(DateTime date) {
    switch (date.weekday) {
      case DateTime.monday:
        return 'Pt';
      case DateTime.tuesday:
        return 'Sa';
      case DateTime.wednesday:
        return 'Ça';
      case DateTime.thursday:
        return 'Pe';
      case DateTime.friday:
        return 'Cu';
      case DateTime.saturday:
        return 'Ct';
      case DateTime.sunday:
        return 'Pz';
      default:
        return '';
    }
  }

  String _weekdayLong(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return 'Pazartesi';
      case DateTime.tuesday:
        return 'Sali';
      case DateTime.wednesday:
        return 'Carsamba';
      case DateTime.thursday:
        return 'Persembe';
      case DateTime.friday:
        return 'Cuma';
      case DateTime.saturday:
        return 'Cumartesi';
      case DateTime.sunday:
        return 'Pazar';
      default:
        return 'Bu gun';
    }
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  TimeOfDay _timeFromString(String value) {
    final parts = value.split(':');
    return TimeOfDay(
      hour: int.tryParse(parts.first) ?? 8,
      minute: int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0,
    );
  }

  TimeOfDay _timeFromDateTime(DateTime value) {
    return TimeOfDay(hour: value.hour, minute: value.minute);
  }

  TimeOfDay _shiftTime(TimeOfDay time, int minutes) {
    final total = ((time.hour * 60) + time.minute + minutes).clamp(
      5 * 60,
      (23 * 60) + 59,
    );
    return TimeOfDay(hour: total ~/ 60, minute: total % 60);
  }

  String _timeToString(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  _DoseSlot _doseSlot(TimeOfDay time) {
    if (time.hour < 11) {
      return _DoseSlot.morning;
    }
    if (time.hour < 17) {
      return _DoseSlot.noon;
    }
    return _DoseSlot.evening;
  }

  String _slotLabel(_DoseSlot slot) {
    return switch (slot) {
      _DoseSlot.morning => 'sabah',
      _DoseSlot.noon => 'ogle',
      _DoseSlot.evening => 'aksam',
    };
  }
}

enum _StatsView {
  week,
  month,
  quarter,
}

enum _DoseSlot {
  morning,
  noon,
  evening,
}

class _DaySummary {
  const _DaySummary({
    required this.date,
    required this.total,
    required this.taken,
    required this.missed,
    required this.rate,
  });

  final DateTime date;
  final int total;
  final int taken;
  final int missed;
  final int rate;
}

class _MedicineStat {
  const _MedicineStat({
    required this.medicine,
    required this.rate,
    required this.volume,
    required this.color,
    required this.last7Days,
  });

  final Medicine medicine;
  final int rate;
  final int volume;
  final Color color;
  final List<_DaySummary> last7Days;
}

class _HeatCell {
  const _HeatCell({
    required this.date,
    required this.rate,
  });

  final DateTime date;
  final int rate;
}

class _InsightSuggestion {
  const _InsightSuggestion({
    required this.title,
    required this.body,
    required this.actionLabel,
    this.targetMedicineId,
    this.recommendedTime,
    this.slot = _DoseSlot.noon,
  });

  final String title;
  final String body;
  final String actionLabel;
  final String? targetMedicineId;
  final TimeOfDay? recommendedTime;
  final _DoseSlot slot;
}
