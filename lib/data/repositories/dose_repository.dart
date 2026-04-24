import '../../models/dose_log.dart';
import '../../services/hive_service.dart';
import '../remote/supabase_data_source.dart';

class DoseRepository {
  DoseRepository({SupabaseDataSource? remote})
      : _remote = remote ?? SupabaseDataSource();

  final SupabaseDataSource _remote;

  List<DoseLog> getToday() => HiveService.getTodayDoseLogs();

  List<DoseLog> getAll() => HiveService.getAllDoseLogs();

  List<DoseLog> getForRange(DateTime start, DateTime end) {
    return HiveService.getDoseLogsInRange(start, end);
  }

  Future<void> markAsTaken(String doseLogId) async {
    await HiveService.markDoseAsTaken(doseLogId);
    await _pushDoseLog(doseLogId);
  }

  Future<DoseLog?> snooze(String doseLogId) async {
    final snoozedLog = await HiveService.snoozeDose(doseLogId);
    await _pushDoseLog(doseLogId);
    if (snoozedLog != null) {
      await _pushDoseLog(snoozedLog.id);
    }
    return snoozedLog;
  }

  Future<void> markAsMissed(String doseLogId) async {
    await HiveService.markDoseAsMissed(doseLogId);
    await _pushDoseLog(doseLogId);
  }

  Future<void> pushLocalSnapshot() async {
    if (!_remote.isAvailable) {
      return;
    }

    for (final doseLog in HiveService.getStoredDoseLogs()) {
      final medicine = HiveService.getMedicine(doseLog.medicineId);
      await _remote.upsertDoseLog(
        doseLog,
        profileId: medicine?.profileId,
      );
    }
  }

  Future<void> _pushDoseLog(String doseLogId) async {
    if (!_remote.isAvailable) {
      return;
    }

    final doseLog = HiveService.getDoseLog(doseLogId);
    if (doseLog == null) {
      return;
    }

    final medicine = HiveService.getMedicine(doseLog.medicineId);
    await _remote.upsertDoseLog(doseLog, profileId: medicine?.profileId);
  }
}
