import 'package:flutter_test/flutter_test.dart';

import 'package:dozara/cubit/profile_cubit.dart';
import 'package:dozara/data/repositories/profile_repository.dart';
import 'package:dozara/models/profile.dart';
import 'package:dozara/services/notification_scheduler.dart';

void main() {
  group('ProfileCubit', () {
    test('hydrates from injected repository without static service access',
        () async {
      final repository = _FakeProfileRepository([
        _profile('p1', 'Ben'),
        _profile('p2', 'Anne'),
      ]);
      final scheduler = _FakeNotificationScheduler();
      final cubit = ProfileCubit(
        repository: repository,
        notificationScheduler: scheduler,
      );

      expect(cubit.state.activeProfileId, 'p1');
      expect(cubit.state.profiles, hasLength(2));

      repository.activeId = 'p2';
      await cubit.hydrate();

      expect(cubit.state.activeProfileId, 'p2');
      expect(cubit.state.activeProfile.name, 'Anne');
      await cubit.close();
    });

    test('switching profile persists active id and reschedules notifications',
        () async {
      final repository = _FakeProfileRepository([
        _profile('p1', 'Ben'),
        _profile('p2', 'Baba'),
      ]);
      final scheduler = _FakeNotificationScheduler();
      final cubit = ProfileCubit(
        repository: repository,
        notificationScheduler: scheduler,
      );

      await cubit.switchTo('p2');

      expect(repository.activeId, 'p2');
      expect(cubit.state.activeProfileId, 'p2');
      expect(scheduler.rescheduleCount, 1);
      await cubit.close();
    });

    test('createProfile can add without making it active', () async {
      final repository = _FakeProfileRepository([_profile('p1', 'Ben')]);
      final scheduler = _FakeNotificationScheduler();
      final cubit = ProfileCubit(
        repository: repository,
        notificationScheduler: scheduler,
      );

      await cubit.createProfile(_profile('p2', 'Kardeş'), makeActive: false);

      expect(repository.profiles.map((profile) => profile.id), ['p1', 'p2']);
      expect(cubit.state.activeProfileId, 'p1');
      expect(scheduler.rescheduleCount, 0);
      await cubit.close();
    });
  });
}

Profile _profile(String id, String name) {
  return Profile(
    id: id,
    name: name,
    colorValue: 0xFF7C3AED,
    avatarUrl: '',
  );
}

class _FakeProfileRepository implements ProfileRepository {
  _FakeProfileRepository(List<Profile> profiles)
      : profiles = List<Profile>.of(profiles),
        activeId = profiles.first.id;

  final List<Profile> profiles;
  String activeId;

  @override
  List<Profile> getAll() => List<Profile>.of(profiles);

  @override
  Profile getActive() {
    return profiles.firstWhere((profile) => profile.id == activeId);
  }

  @override
  Future<void> setActive(String id) async {
    activeId = id;
  }

  @override
  Future<void> add(Profile profile) async {
    profiles.add(profile);
  }

  @override
  Future<void> update(Profile profile) async {
    final index = profiles.indexWhere((item) => item.id == profile.id);
    profiles[index] = profile;
  }

  @override
  Future<void> delete(String id) async {
    profiles.removeWhere((profile) => profile.id == id);
    if (activeId == id && profiles.isNotEmpty) {
      activeId = profiles.first.id;
    }
  }

  @override
  Future<void> pushLocalSnapshot() async {}
}

class _FakeNotificationScheduler implements NotificationScheduler {
  int rescheduleCount = 0;

  @override
  Future<void> rescheduleAllNotifications() async {
    rescheduleCount++;
  }
}
