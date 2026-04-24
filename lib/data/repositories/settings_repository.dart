import '../../services/hive_service.dart';

class SettingsRepository {
  String getThemeModePreference() => HiveService.getThemeModePreference();

  Future<void> setThemeModePreference(String value) {
    return HiveService.setThemeModePreference(value);
  }

  bool getNotificationVibrationEnabled() {
    return HiveService.getNotificationVibrationEnabled();
  }

  Future<void> setNotificationVibrationEnabled(bool value) {
    return HiveService.setNotificationVibrationEnabled(value);
  }

  bool getVoiceReminderEnabled() {
    return HiveService.getVoiceReminderEnabled();
  }

  Future<void> setVoiceReminderEnabled(bool value) {
    return HiveService.setVoiceReminderEnabled(value);
  }

  bool getFamilyNotificationEnabled() {
    return HiveService.getFamilyNotificationEnabled();
  }

  Future<void> setFamilyNotificationEnabled(bool value) {
    return HiveService.setFamilyNotificationEnabled(value);
  }
}
