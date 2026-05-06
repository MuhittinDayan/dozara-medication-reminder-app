import '../../models/profile.dart';
import '../../services/hive_service.dart';
import '../remote/supabase_data_source.dart';

abstract class ProfileRepository {
  List<Profile> getAll();

  Profile getActive();

  Future<void> setActive(String id);

  Future<void> add(Profile profile);

  Future<void> update(Profile profile);

  Future<void> delete(String id);

  Future<void> pushLocalSnapshot();
}

class HiveProfileRepository implements ProfileRepository {
  HiveProfileRepository({SupabaseDataSource? remote})
      : _remote = remote ?? SupabaseDataSource();

  final SupabaseDataSource _remote;

  @override
  List<Profile> getAll() => HiveService.getAllProfiles();

  @override
  Profile getActive() => HiveService.getActiveProfile();

  @override
  Future<void> setActive(String id) => HiveService.setActiveProfile(id);

  @override
  Future<void> add(Profile profile) async {
    await HiveService.addProfile(profile);
    await _remote.upsertProfile(profile);
  }

  @override
  Future<void> update(Profile profile) async {
    await HiveService.updateProfile(profile);
    await _remote.upsertProfile(profile);
  }

  @override
  Future<void> delete(String id) => HiveService.deleteProfile(id);

  @override
  Future<void> pushLocalSnapshot() async {
    if (!_remote.isAvailable) {
      return;
    }

    for (final profile in HiveService.getAllProfiles()) {
      await _remote.upsertProfile(profile);
    }
  }
}
