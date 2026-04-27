import '../../models/dose_log.dart';

class HomeDaySummary {
  final int takenCount;
  final int pendingCount;
  final int missedCount;
  final double completionRate;
  final DoseLog? nextDose;
  final int totalCount;

  const HomeDaySummary({
    required this.takenCount,
    required this.pendingCount,
    required this.missedCount,
    required this.completionRate,
    this.nextDose,
    required this.totalCount,
  });
}
