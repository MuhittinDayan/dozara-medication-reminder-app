import '../models/dose_log.dart';
import '../models/medicine.dart';
import '../utils/stats_calculator.dart';

class WeeklyStatsViewModel {
  const WeeklyStatsViewModel({
    required this.logs,
    required this.hasData,
    required this.weeklyData,
    required this.daySummaries,
    required this.adherenceRate,
    required this.adherenceTrend,
    required this.isAdherencePositive,
    required this.streak,
    required this.takenCount,
    required this.totalCount,
    required this.missedCount,
    required this.missedTrend,
    required this.isMissedPositive,
    required this.insight,
  });

  final List<DoseLog> logs;
  final bool hasData;
  final List<double> weeklyData;
  final List<DaySummary> daySummaries;
  final int adherenceRate;
  final String adherenceTrend;
  final bool isAdherencePositive;
  final int streak;
  final int takenCount;
  final int totalCount;
  final int missedCount;
  final String missedTrend;
  final bool isMissedPositive;
  final InsightSuggestion insight;
}

class MonthlyStatsViewModel {
  const MonthlyStatsViewModel({
    required this.logs,
    required this.heatmapData,
  });

  final List<DoseLog> logs;
  final List<HeatCell> heatmapData;
}

class QuarterStatsViewModel {
  const QuarterStatsViewModel({
    required this.heatmapData,
    required this.lastSeven,
    required this.current30,
    required this.previous30,
    required this.insight,
  });

  final List<HeatCell> heatmapData;
  final List<DaySummary> lastSeven;
  final int current30;
  final int previous30;
  final InsightSuggestion insight;
}

class StatsDashboardViewModel {
  StatsDashboardViewModel({
    required List<Medicine> medicines,
    required List<DoseLog> logs90Days,
  })  : medicines = List<Medicine>.unmodifiable(medicines),
        logs90Days = List<DoseLog>.unmodifiable(logs90Days) {
    overallPercent = StatsCalculator.overallPercent(medicines, logs90Days);
    weekly = _buildWeekly();
    monthly = _buildMonthly();
    quarter = _buildQuarter();
  }

  StatsDashboardViewModel.empty()
      : this(
          medicines: const [],
          logs90Days: const [],
        );

  final List<Medicine> medicines;
  final List<DoseLog> logs90Days;

  late final int overallPercent;
  late final WeeklyStatsViewModel weekly;
  late final MonthlyStatsViewModel monthly;
  late final QuarterStatsViewModel quarter;

  WeeklyStatsViewModel _buildWeekly() {
    final weekLogs = StatsCalculator.logsForDays(logs90Days, 7);
    final previousWeekLogs =
        StatsCalculator.logsInPastWindow(logs90Days, days: 7, offset: 7);
    final adherenceRate = overallPercent;
    final previousAdherenceRate =
        StatsCalculator.adherenceRate(previousWeekLogs);
    final missedCount =
        weekLogs.where((log) => log.status == DoseStatus.missed).length;
    final previousMissedCount =
        previousWeekLogs.where((log) => log.status == DoseStatus.missed).length;

    return WeeklyStatsViewModel(
      logs: weekLogs,
      hasData: weekLogs.isNotEmpty,
      weeklyData: StatsCalculator.calculateRealWeeklyData(weekLogs),
      daySummaries: StatsCalculator.dailySummaries(weekLogs, 7),
      adherenceRate: adherenceRate,
      adherenceTrend:
          StatsCalculator.trendLabel(adherenceRate - previousAdherenceRate),
      isAdherencePositive: adherenceRate >= previousAdherenceRate,
      streak: StatsCalculator.calculateStreak(logs90Days),
      takenCount:
          weekLogs.where((log) => log.status == DoseStatus.taken).length,
      totalCount: weekLogs.length,
      missedCount: missedCount,
      missedTrend:
          StatsCalculator.missedTrendLabel(missedCount, previousMissedCount),
      isMissedPositive: missedCount <= previousMissedCount,
      insight: StatsCalculator.buildInsight(
        medicines: medicines,
        logs: StatsCalculator.logsForDays(logs90Days, 30),
        title: 'Gemini Tespiti',
        summaryPrefix: 'dÃ¼zenli kaÃ§Ä±rÄ±yorsun.',
        improvementPrefix: 'Genel uyumun toparlanÄ±yor.',
      ),
    );
  }

  MonthlyStatsViewModel _buildMonthly() {
    final monthLogs = StatsCalculator.logsForDays(logs90Days, 35);
    return MonthlyStatsViewModel(
      logs: monthLogs,
      heatmapData: StatsCalculator.heatmapData(monthLogs, 35),
    );
  }

  QuarterStatsViewModel _buildQuarter() {
    return QuarterStatsViewModel(
      heatmapData: StatsCalculator.heatmapData(logs90Days, 90),
      lastSeven: StatsCalculator.dailySummaries(
        StatsCalculator.logsForDays(logs90Days, 7),
        7,
      ),
      current30: StatsCalculator.adherenceRate(
        StatsCalculator.logsForDays(logs90Days, 30),
      ),
      previous30: StatsCalculator.adherenceRate(
        StatsCalculator.logsInPastWindow(logs90Days, days: 30, offset: 30),
      ),
      insight: StatsCalculator.buildInsight(
        medicines: medicines,
        logs: logs90Days,
        title: '3 AylÄ±k Ã–zet',
        summaryPrefix: 'hala zayÄ±f noktan.',
        improvementPrefix: 'GeÃ§en aya gÃ¶re daha istikrarlÄ±sÄ±n.',
      ),
    );
  }
}
