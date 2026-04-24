import 'package:flutter_bloc/flutter_bloc.dart';

import '../models/profile.dart';
import '../services/hive_service.dart';
import '../services/notification_service.dart';

class ProfileState {
  const ProfileState({
    required this.profiles,
    required this.activeProfileId,
  });

  final List<Profile> profiles;
  final String activeProfileId;

  Profile get activeProfile {
    if (profiles.isEmpty) {
      return HiveService.getActiveProfile();
    }

    for (final profile in profiles) {
      if (profile.id == activeProfileId) {
        return profile;
      }
    }

    return profiles.first;
  }

  ProfileState copyWith({
    List<Profile>? profiles,
    String? activeProfileId,
  }) {
    return ProfileState(
      profiles: profiles ?? this.profiles,
      activeProfileId: activeProfileId ?? this.activeProfileId,
    );
  }
}

class ProfileCubit extends Cubit<ProfileState> {
  ProfileCubit()
      : super(
          ProfileState(
            profiles: HiveService.getAllProfiles(),
            activeProfileId: HiveService.getActiveProfile().id,
          ),
        );

  Future<void> hydrate() async {
    emit(
      state.copyWith(
        profiles: HiveService.getAllProfiles(),
        activeProfileId: HiveService.getActiveProfile().id,
      ),
    );
  }

  Future<void> switchTo(String profileId) async {
    await HiveService.setActiveProfile(profileId);
    await NotificationService.rescheduleAllNotifications();
    await hydrate();
  }

  Future<void> createProfile(Profile profile, {bool makeActive = true}) async {
    await HiveService.addProfile(profile);
    if (makeActive) {
      await HiveService.setActiveProfile(profile.id);
      await NotificationService.rescheduleAllNotifications();
    }
    await hydrate();
  }

  Future<void> updateProfile(Profile profile) async {
    await HiveService.updateProfile(profile);
    await hydrate();
  }

  Future<void> deleteProfile(String profileId) async {
    await HiveService.deleteProfile(profileId);
    await NotificationService.rescheduleAllNotifications();
    await hydrate();
  }
}
