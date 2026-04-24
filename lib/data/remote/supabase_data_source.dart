import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/dose_log.dart';
import '../../models/medicine.dart';
import '../../models/profile.dart';
import '../backend/backend_service.dart';
import 'supabase_mappers.dart';

class SupabaseDataSource {
  SupabaseDataSource({SupabaseClient? client})
      : _client = client ?? BackendService.client;

  final SupabaseClient? _client;

  bool get isAvailable {
    final client = _client;
    return client != null && client.auth.currentUser != null;
  }

  String? get _userId => _client?.auth.currentUser?.id;

  String? _remoteProfileId(String userId, String? profileId) {
    if (profileId == null) {
      return null;
    }
    if (profileId.startsWith('$userId:')) {
      return profileId;
    }
    return '$userId:$profileId';
  }

  String? _localProfileId(String userId, String? profileId) {
    if (profileId == null) {
      return null;
    }
    final prefix = '$userId:';
    if (profileId.startsWith(prefix)) {
      return profileId.substring(prefix.length);
    }
    return profileId;
  }

  Future<void> upsertProfile(Profile profile) async {
    final client = _client;
    final userId = _userId;
    if (client == null || userId == null) {
      return;
    }

    final json = profile.toSupabaseJson(userId)
      ..['id'] = _remoteProfileId(userId, profile.id);

    await client.from('profiles').upsert(json);
  }

  Future<List<Profile>> fetchProfiles() async {
    final client = _client;
    final userId = _userId;
    if (client == null || userId == null) {
      return const [];
    }

    final rows = await client
        .from('profiles')
        .select()
        .eq('user_id', userId)
        .isFilter('deleted_at', null)
        .order('created_at');

    return rows.map((row) {
      final json = Map<String, dynamic>.from(row as Map)
        ..['id'] = _localProfileId(userId, row['id'] as String?);
      return ProfileSupabaseMapper.fromSupabaseJson(json);
    }).toList();
  }

  Future<void> upsertMedicine(Medicine medicine) async {
    final client = _client;
    final userId = _userId;
    if (client == null || userId == null) {
      return;
    }

    final json = medicine.toSupabaseJson(userId)
      ..['profile_id'] = _remoteProfileId(userId, medicine.profileId);

    await client.from('medicines').upsert(json);
  }

  Future<void> deleteMedicine(String id) async {
    final client = _client;
    final userId = _userId;
    if (client == null || userId == null) {
      return;
    }

    await client
        .from('medicines')
        .update({'deleted_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', id)
        .eq('user_id', userId);
  }

  Future<List<Medicine>> fetchMedicines({String? profileId}) async {
    final client = _client;
    final userId = _userId;
    if (client == null || userId == null) {
      return const [];
    }

    var query = client
        .from('medicines')
        .select()
        .eq('user_id', userId)
        .isFilter('deleted_at', null);

    if (profileId != null) {
      query = query.eq('profile_id', _remoteProfileId(userId, profileId)!);
    }

    final rows = await query.order('created_at');
    return rows.map((row) {
      final json = Map<String, dynamic>.from(row as Map)
        ..['profile_id'] =
            _localProfileId(userId, row['profile_id'] as String?);
      return MedicineSupabaseMapper.fromSupabaseJson(json);
    }).toList();
  }

  Future<void> upsertDoseLog(DoseLog doseLog, {String? profileId}) async {
    final client = _client;
    final userId = _userId;
    if (client == null || userId == null) {
      return;
    }

    final json = doseLog.toSupabaseJson(
      userId,
      _remoteProfileId(userId, profileId),
    );

    await client.from('dose_logs').upsert(json);
  }

  Future<List<DoseLog>> fetchDoseLogs({
    DateTime? start,
    DateTime? end,
    String? medicineId,
  }) async {
    final client = _client;
    final userId = _userId;
    if (client == null || userId == null) {
      return const [];
    }

    var query = client
        .from('dose_logs')
        .select()
        .eq('user_id', userId)
        .isFilter('deleted_at', null);

    if (start != null) {
      query = query.gte('scheduled_time', start.toUtc().toIso8601String());
    }
    if (end != null) {
      query = query.lt('scheduled_time', end.toUtc().toIso8601String());
    }
    if (medicineId != null) {
      query = query.eq('medicine_id', medicineId);
    }

    final rows = await query.order('scheduled_time');
    return rows
        .map((row) => DoseLogSupabaseMapper.fromSupabaseJson(
              Map<String, dynamic>.from(row as Map),
            ))
        .toList();
  }

  Future<void> insertStockEvent({
    required String medicineId,
    required int delta,
    required int resultingStock,
    required String reason,
  }) async {
    final client = _client;
    final userId = _userId;
    if (client == null || userId == null) {
      return;
    }

    await client.from('stock_events').insert({
      'user_id': userId,
      'medicine_id': medicineId,
      'delta': delta,
      'resulting_stock': resultingStock,
      'reason': reason,
    });
  }
}
