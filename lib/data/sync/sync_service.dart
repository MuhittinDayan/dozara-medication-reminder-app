import 'package:flutter/foundation.dart';

import '../backend/backend_service.dart';
import '../repositories/dose_repository.dart';
import '../repositories/medicine_repository.dart';
import '../repositories/profile_repository.dart';
import '../remote/supabase_data_source.dart';
import '../../services/hive_service.dart';

class SyncService {
  SyncService._();

  static Future<void> syncNow() async {
    if (!BackendService.isInitialized || BackendService.currentUser == null) {
      return;
    }

    final remote = SupabaseDataSource();

    try {
      await _pullRemoteSnapshot(remote);
      await _pushLocalSnapshot(remote);
    } catch (error, stackTrace) {
      debugPrint('Supabase sync skipped: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  static Future<void> pushLocalSnapshot() async {
    if (!BackendService.isInitialized || BackendService.currentUser == null) {
      return;
    }

    final remote = SupabaseDataSource();

    try {
      await _pushLocalSnapshot(remote);
    } catch (error, stackTrace) {
      debugPrint('Supabase sync skipped: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  static Future<void> _pullRemoteSnapshot(SupabaseDataSource remote) async {
    if (!remote.isAvailable) {
      return;
    }

    final profiles = await remote.fetchProfiles();
    for (final profile in profiles) {
      await HiveService.upsertSyncedProfile(profile);
    }

    final medicines = await remote.fetchMedicines();
    for (final medicine in medicines) {
      await HiveService.upsertSyncedMedicine(medicine);
    }

    final doseLogs = await remote.fetchDoseLogs();
    for (final doseLog in doseLogs) {
      await HiveService.upsertSyncedDoseLog(doseLog);
    }
  }

  static Future<void> _pushLocalSnapshot(SupabaseDataSource remote) async {
    await ProfileRepository(remote: remote).pushLocalSnapshot();
    await MedicineRepository(remote: remote).pushLocalSnapshot();
    await DoseRepository(remote: remote).pushLocalSnapshot();
  }
}
