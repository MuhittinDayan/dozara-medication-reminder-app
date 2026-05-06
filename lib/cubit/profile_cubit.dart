import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/repositories/profile_repository.dart';
import '../models/profile.dart';
import '../services/notification_scheduler.dart';

class ProfileState {
  ProfileState({
    required List<Profile> profiles,
    required this.activeProfile,
  }) : profiles = List<Profile>.unmodifiable(profiles);

  final List<Profile> profiles;
  final Profile activeProfile;

  String get activeProfileId => activeProfile.id;

  ProfileState copyWith({
    List<Profile>? profiles,
    Profile? activeProfile,
  }) {
    return ProfileState(
      profiles: profiles ?? this.profiles,
      activeProfile: activeProfile ?? this.activeProfile,
    );
  }
}

class ProfileCubit extends Cubit<ProfileState> {
  ProfileCubit({
    ProfileRepository? repository,
    NotificationScheduler? notificationScheduler,
  }) : this._(
          repository ?? HiveProfileRepository(),
          notificationScheduler ?? const FlutterNotificationScheduler(),
        );

  ProfileCubit._(
    ProfileRepository repository,
    NotificationScheduler notificationScheduler,
  )   : _repository = repository,
        _notificationScheduler = notificationScheduler,
        super(
          ProfileState(
            profiles: repository.getAll(),
            activeProfile: repository.getActive(),
          ),
        );

  final ProfileRepository _repository;
  final NotificationScheduler _notificationScheduler;

  Future<void> hydrate() async {
    emit(
      state.copyWith(
        profiles: _repository.getAll(),
        activeProfile: _repository.getActive(),
      ),
    );
  }

  Future<void> switchTo(String profileId) async {
    await _repository.setActive(profileId);
    await _notificationScheduler.rescheduleAllNotifications();
    await hydrate();
  }

  Future<void> createProfile(Profile profile, {bool makeActive = true}) async {
    await _repository.add(profile);
    if (makeActive) {
      await _repository.setActive(profile.id);
      await _notificationScheduler.rescheduleAllNotifications();
    }
    await hydrate();
  }

  Future<void> updateProfile(Profile profile) async {
    await _repository.update(profile);
    await hydrate();
  }

  Future<void> deleteProfile(String profileId) async {
    await _repository.delete(profileId);
    await _notificationScheduler.rescheduleAllNotifications();
    await hydrate();
  }
}
