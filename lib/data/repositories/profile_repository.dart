import '../../models/profile.dart';
import '../../services/hive_service.dart';
import '../remote/supabase_data_source.dart';

class ProfileRepository {
  ProfileRepository({SupabaseDataSource? remote})
      : _remote = remote ?? SupabaseDataSource();

  final SupabaseDataSource _remote;

  List<Profile> getAll() => HiveService.getAllProfiles();

  Profile getActive() => HiveService.getActiveProfile();

  Future<void> setActive(String id) => HiveService.setActiveProfile(id);

  Future<void> add(Profile profile) async {
    await HiveService.addProfile(profile);
    await _remote.upsertProfile(profile);
  }

  Future<void> update(Profile profile) async {
    await HiveService.updateProfile(profile);
    await _remote.upsertProfile(profile);
  }

  Future<void> pushLocalSnapshot() async {
    if (!_remote.isAvailable) {
      return;
    }

    for (final profile in HiveService.getAllProfiles()) {
      await _remote.upsertProfile(profile);
    }
  }
}
