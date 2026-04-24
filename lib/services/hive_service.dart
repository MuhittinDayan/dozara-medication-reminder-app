import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

import '../models/dose_log.dart';
import '../models/medicine.dart';
import '../models/profile.dart';
import 'notification_service.dart';

class HiveService {
  static const String defaultProfileId = 'default';
  static const String _medicineBoxName = 'medicines';
  static const String _doseLogBoxName = 'dose_logs';
  static const String _profileBoxName = 'profiles';
  static const String _settingsBoxName = 'settings';
  static const String _activeProfileIdKey = 'activeProfileId';
  static const String _themeModeKey = 'themeMode';
  static const String _defaultThemeMode = 'system';
  static const String _onboardingCompletedKey = 'onboardingCompleted';
  static const String _onboardingConditionsKey = 'onboardingConditions';
  static const String _onboardingBirthDateKey = 'onboardingBirthDate';
  static const String _notificationVibrationKey = 'notificationVibration';
  static const String _voiceReminderKey = 'voiceReminder';
  static const String _familyNotificationKey = 'familyNotification';
  static const String _disabledAlarmKeysKey = 'disabledAlarmKeys';
  static const String _geminiManagedAlarmKeysKey = 'geminiManagedAlarmKeys';

  static late Box<Medicine> _medicineBox;
  static late Box<DoseLog> _doseLogBox;
  static late Box<Profile> _profileBox;
  static late Box _settingsBox;

  static const _uuid = Uuid();

  static bool _isInitialized = false;
  static Future<void> Function()? onLocalDataChanged;

  static Future<void> _notifyLocalDataChanged() async {
    final callback = onLocalDataChanged;
    if (callback != null) {
      await callback();
    }
  }

  static Profile _buildDefaultProfile() {
    return Profile(
      id: defaultProfileId,
      name: 'Ben',
      colorValue: 0xFF00897B,
      avatarUrl: '',
      relation: 'Ben',
      receivesDoseNotifications: true,
      canManageMedicines: true,
    );
  }

  static Future<void> _ensureProfileState() async {
    if (_profileBox.isEmpty) {
      final defaultProfile = _buildDefaultProfile();
      await _profileBox.put(defaultProfile.id, defaultProfile);
    }

    final currentActiveId = _settingsBox.get(_activeProfileIdKey,
        defaultValue: defaultProfileId) as String;

    if (!_profileBox.containsKey(currentActiveId)) {
      final repairedId = _profileBox.values.first.id;
      await _settingsBox.put(_activeProfileIdKey, repairedId);
      activeProfileId.value = repairedId;
      return;
    }

    activeProfileId.value = currentActiveId;
  }

  // Aktif profil değişikliğini dinlemek için
  static final ValueNotifier<String> activeProfileId =
      ValueNotifier<String>('default');

  static void registerAdapters() {
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(MedicineAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(DoseLogAdapter());
    }
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(DoseStatusAdapter());
    }
    if (!Hive.isAdapterRegistered(3)) {
      Hive.registerAdapter(MedicineFormAdapter());
    }
    if (!Hive.isAdapterRegistered(4)) {
      Hive.registerAdapter(ProfileAdapter());
    }
    if (!Hive.isAdapterRegistered(5)) {
      Hive.registerAdapter(MedicineScheduleTypeAdapter());
    }
  }

  /// Hive kutularını aç
  static Future<void> init({
    required List<int> encryptionKey,
    bool migrateFromUnencrypted = false,
  }) async {
    if (_isInitialized) {
      return;
    }

    registerAdapters();

    if (migrateFromUnencrypted) {
      await _migrateToEncryptedBoxes(encryptionKey);
    }

    final cipher = HiveAesCipher(encryptionKey);

    _medicineBox = await Hive.openBox<Medicine>(
      _medicineBoxName,
      encryptionCipher: cipher,
    );
    _doseLogBox = await Hive.openBox<DoseLog>(
      _doseLogBoxName,
      encryptionCipher: cipher,
    );
    _profileBox = await Hive.openBox<Profile>(
      _profileBoxName,
      encryptionCipher: cipher,
    );
    _settingsBox = await Hive.openBox(
      _settingsBoxName,
      encryptionCipher: cipher,
    );

    await _ensureProfileState();
    _isInitialized = true;
  }

  static Future<void> _migrateToEncryptedBoxes(List<int> encryptionKey) async {
    final medicinesBox = await Hive.openBox<Medicine>(_medicineBoxName);
    final medicines = medicinesBox.toMap().cast<dynamic, Medicine>();
    await medicinesBox.deleteFromDisk();

    final doseLogsBox = await Hive.openBox<DoseLog>(_doseLogBoxName);
    final doseLogs = doseLogsBox.toMap().cast<dynamic, DoseLog>();
    await doseLogsBox.deleteFromDisk();

    final profilesBox = await Hive.openBox<Profile>(_profileBoxName);
    final profiles = profilesBox.toMap().cast<dynamic, Profile>();
    await profilesBox.deleteFromDisk();

    final settingsBox = await Hive.openBox(_settingsBoxName);
    final settings = settingsBox.toMap();
    await settingsBox.deleteFromDisk();

    if (medicines.isNotEmpty ||
        doseLogs.isNotEmpty ||
        profiles.isNotEmpty ||
        settings.isNotEmpty) {
      final cipher = HiveAesCipher(encryptionKey);
      final encryptedMedicineBox = await Hive.openBox<Medicine>(
        _medicineBoxName,
        encryptionCipher: cipher,
      );
      await encryptedMedicineBox.putAll(medicines);
      await encryptedMedicineBox.close();

      final encryptedDoseLogsBox = await Hive.openBox<DoseLog>(
        _doseLogBoxName,
        encryptionCipher: cipher,
      );
      await encryptedDoseLogsBox.putAll(doseLogs);
      await encryptedDoseLogsBox.close();

      final encryptedProfilesBox = await Hive.openBox<Profile>(
        _profileBoxName,
        encryptionCipher: cipher,
      );
      await encryptedProfilesBox.putAll(profiles);
      await encryptedProfilesBox.close();

      final encryptedSettingsBox = await Hive.openBox(
        _settingsBoxName,
        encryptionCipher: cipher,
      );
      await encryptedSettingsBox.putAll(settings);
      await encryptedSettingsBox.close();
    }
  }

  static Future<void> close() async {
    if (!_isInitialized) {
      return;
    }

    await _medicineBox.close();
    await _doseLogBox.close();
    await _profileBox.close();
    await _settingsBox.close();
    onLocalDataChanged = null;
    _isInitialized = false;
  }

  static void _ensureInitialized() {
    if (!_isInitialized) {
      throw StateError('HiveService.init() çağrılmadan servis kullanılamaz.');
    }
  }

  static bool _belongsToActiveProfile(Medicine medicine) {
    return medicine.profileId == null ||
        medicine.profileId == activeProfileId.value;
  }

  static bool _belongsToMedicineScope(DoseLog log, {String? medicineId}) {
    if (medicineId != null && log.medicineId != medicineId) {
      return false;
    }

    final medicine = _medicineBox.get(log.medicineId);
    if (medicine == null) {
      return false;
    }

    return _belongsToActiveProfile(medicine);
  }

  static DateTime _startOfDay(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  static DateTime _endOfDayExclusive(DateTime date) =>
      _startOfDay(date).add(const Duration(days: 1));

  static DateTime _combineDateAndTime(DateTime date, String hhmm) {
    final parts = hhmm.split(':');
    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);
    return DateTime(date.year, date.month, date.day, hour, minute);
  }

  static List<DoseLog> _sortedDoseLogs(
    Iterable<DoseLog> logs, {
    bool descending = false,
  }) {
    final result = logs.toList()
      ..sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));
    if (descending) {
      return result.reversed.toList();
    }
    return result;
  }

  // ============== PROFİL İŞLEMLERİ ==============

  static List<Profile> getAllProfiles() {
    _ensureInitialized();
    final profiles = _profileBox.values.toList();
    return profiles.isEmpty ? [_buildDefaultProfile()] : profiles;
  }

  static Profile? getProfile(String id) {
    _ensureInitialized();
    return _profileBox.get(id);
  }

  static Profile getActiveProfile() {
    _ensureInitialized();
    final profiles = getAllProfiles();
    return profiles.firstWhere(
      (profile) => profile.id == activeProfileId.value,
      orElse: () => profiles.first,
    );
  }

  static Future<void> setActiveProfile(String id) async {
    _ensureInitialized();
    final nextId = _profileBox.containsKey(id)
        ? id
        : (_profileBox.isNotEmpty
            ? _profileBox.values.first.id
            : defaultProfileId);
    activeProfileId.value = nextId;
    await _settingsBox.put(_activeProfileIdKey, nextId);
    await _notifyLocalDataChanged();
  }

  static String getThemeModePreference() {
    _ensureInitialized();
    return _settingsBox.get(
      _themeModeKey,
      defaultValue: _defaultThemeMode,
    ) as String;
  }

  static Future<void> setThemeModePreference(String value) async {
    _ensureInitialized();
    await _settingsBox.put(_themeModeKey, value);
  }

  static bool isOnboardingCompleted() {
    _ensureInitialized();
    final raw = _settingsBox.get(
      _onboardingCompletedKey,
      defaultValue: 'false',
    );
    return raw == true || raw == 'true';
  }

  static Future<void> setOnboardingCompleted(bool value) async {
    _ensureInitialized();
    await _settingsBox.put(_onboardingCompletedKey, value ? 'true' : 'false');
  }

  static List<String> getOnboardingConditions() {
    _ensureInitialized();
    final raw = _settingsBox.get(
      _onboardingConditionsKey,
      defaultValue: const <String>[],
    );
    if (raw is List) {
      return raw.whereType<String>().toList(growable: false);
    }
    return const <String>[];
  }

  static String getOnboardingBirthDate() {
    _ensureInitialized();
    return _settingsBox.get(
          _onboardingBirthDateKey,
          defaultValue: '',
        ) as String? ??
        '';
  }

  static Future<void> saveOnboardingProfileContext({
    required List<String> conditions,
    required String birthDate,
  }) async {
    _ensureInitialized();
    await _settingsBox.put(_onboardingConditionsKey, conditions);
    await _settingsBox.put(_onboardingBirthDateKey, birthDate);
  }

  static bool getNotificationVibrationEnabled() {
    _ensureInitialized();
    return _settingsBox.get(
          _notificationVibrationKey,
          defaultValue: true,
        ) as bool? ??
        true;
  }

  static Future<void> setNotificationVibrationEnabled(bool value) async {
    _ensureInitialized();
    await _settingsBox.put(_notificationVibrationKey, value);
  }

  static bool getVoiceReminderEnabled() {
    _ensureInitialized();
    return _settingsBox.get(
          _voiceReminderKey,
          defaultValue: true,
        ) as bool? ??
        true;
  }

  static Future<void> setVoiceReminderEnabled(bool value) async {
    _ensureInitialized();
    await _settingsBox.put(_voiceReminderKey, value);
  }

  static bool getFamilyNotificationEnabled() {
    _ensureInitialized();
    return _settingsBox.get(
          _familyNotificationKey,
          defaultValue: false,
        ) as bool? ??
        false;
  }

  static Future<void> setFamilyNotificationEnabled(bool value) async {
    _ensureInitialized();
    await _settingsBox.put(_familyNotificationKey, value);
  }

  static bool isAlarmEnabled(String medicineId, String time) {
    final disabledKeys = _getStringSet(_disabledAlarmKeysKey);
    return !disabledKeys.contains(_alarmKey(medicineId, time));
  }

  static Future<void> setAlarmEnabled(
    String medicineId,
    String time,
    bool enabled,
  ) async {
    _ensureInitialized();
    final disabledKeys = _getStringSet(_disabledAlarmKeysKey);
    final alarmKey = _alarmKey(medicineId, time);

    if (enabled) {
      disabledKeys.remove(alarmKey);
    } else {
      disabledKeys.add(alarmKey);
    }

    await _settingsBox.put(
        _disabledAlarmKeysKey, disabledKeys.toList()..sort());
  }

  static bool isGeminiManagedAlarm(String medicineId, String time) {
    final geminiKeys = _getStringSet(_geminiManagedAlarmKeysKey);
    return geminiKeys.contains(_alarmKey(medicineId, time));
  }

  static Future<void> clearGeminiManagedAlarmsForMedicine(
    String medicineId,
  ) async {
    _ensureInitialized();
    final geminiKeys = _getStringSet(_geminiManagedAlarmKeysKey)
      ..removeWhere((key) => key.startsWith('$medicineId|'));
    await _settingsBox.put(
      _geminiManagedAlarmKeysKey,
      geminiKeys.toList()..sort(),
    );
  }

  static Future<void> setGeminiManagedAlarm(
    String medicineId,
    String time, {
    bool enabled = true,
  }) async {
    _ensureInitialized();
    final geminiKeys = _getStringSet(_geminiManagedAlarmKeysKey);
    final alarmKey = _alarmKey(medicineId, time);

    if (enabled) {
      geminiKeys.add(alarmKey);
    } else {
      geminiKeys.remove(alarmKey);
    }

    await _settingsBox.put(
      _geminiManagedAlarmKeysKey,
      geminiKeys.toList()..sort(),
    );
  }

  static Set<String> _getStringSet(String key) {
    _ensureInitialized();
    final raw = _settingsBox.get(key, defaultValue: const <String>[]);
    if (raw is List) {
      return raw.whereType<String>().toSet();
    }
    return <String>{};
  }

  static String _alarmKey(String medicineId, String time) =>
      '$medicineId|$time';

  static Future<void> addProfile(Profile profile) async {
    _ensureInitialized();
    await _profileBox.put(profile.id, profile);
    if (!_profileBox.containsKey(activeProfileId.value)) {
      await setActiveProfile(profile.id);
    }
    await _notifyLocalDataChanged();
  }

  static Future<void> updateProfile(Profile profile) async {
    _ensureInitialized();
    await _profileBox.put(profile.id, profile);
    await _notifyLocalDataChanged();
  }

  static Future<void> deleteProfile(String id) async {
    _ensureInitialized();
    if (id == defaultProfileId) {
      return;
    }

    await _profileBox.delete(id);
    await _ensureProfileState();
    if (activeProfileId.value == id) {
      await setActiveProfile(defaultProfileId);
    }
    await _notifyLocalDataChanged();
  }

  // ============== İLAÇ İŞLEMLERİ ==============

  static List<Medicine> getAllMedicines() {
    _ensureInitialized();
    return _medicineBox.values.where(_belongsToActiveProfile).toList();
  }

  static List<Medicine> getMedicinesForProfile(
    String profileId, {
    bool activeOnly = false,
  }) {
    _ensureInitialized();
    return _medicineBox.values.where((medicine) {
      final belongs =
          medicine.profileId == null || medicine.profileId == profileId;
      if (!belongs) {
        return false;
      }
      if (!activeOnly) {
        return true;
      }
      return medicine.isActive && !medicine.isExpired;
    }).toList();
  }

  static List<Medicine> getStoredMedicines() {
    _ensureInitialized();
    return _medicineBox.values.toList();
  }

  static List<DoseLog> getStoredDoseLogs() {
    _ensureInitialized();
    return _doseLogBox.values.toList();
  }

  static Future<void> upsertSyncedProfile(Profile profile) async {
    _ensureInitialized();
    await _profileBox.put(profile.id, profile);
    await _ensureProfileState();
  }

  static Future<void> upsertSyncedMedicine(Medicine medicine) async {
    _ensureInitialized();
    await _medicineBox.put(medicine.id, medicine);
  }

  static Future<void> upsertSyncedDoseLog(DoseLog doseLog) async {
    _ensureInitialized();
    await _doseLogBox.put(doseLog.id, doseLog);
  }

  static List<Medicine> getActiveMedicines() {
    _ensureInitialized();
    return _medicineBox.values
        .where((medicine) => medicine.isActive && !medicine.isExpired)
        .where(_belongsToActiveProfile)
        .toList();
  }

  static Future<Medicine> addMedicine(Medicine medicine) async {
    _ensureInitialized();
    await _medicineBox.put(medicine.id, medicine);
    await syncMedicineDoseLogs(medicine);
    await _notifyLocalDataChanged();
    return medicine;
  }

  static Future<void> deleteMedicine(String id) async {
    _ensureInitialized();
    await _medicineBox.delete(id);

    final logsToDelete =
        _doseLogBox.values.where((log) => log.medicineId == id).toList();
    for (final log in logsToDelete) {
      await log.delete();
    }
    await _notifyLocalDataChanged();
  }

  static Future<void> updateMedicine(Medicine medicine) async {
    _ensureInitialized();
    await _rebuildUpcomingDoseLogsForMedicine(medicine.id);
    await _medicineBox.put(medicine.id, medicine);
    await syncMedicineDoseLogs(medicine);
    await _notifyLocalDataChanged();
  }

  static Medicine? getMedicine(String id) {
    _ensureInitialized();
    return _medicineBox.get(id);
  }

  static Future<void> decreaseStock(String medicineId) async {
    _ensureInitialized();
    final medicine = _medicineBox.get(medicineId);
    if (medicine == null ||
        medicine.lowStockThreshold == null ||
        medicine.stockCount == null) {
      return;
    }

    final oldLow = medicine.isStockLow;
    medicine.stockCount = (medicine.stockCount! - 1).clamp(0, 1 << 31);
    await medicine.save();

    if ((!oldLow && medicine.isStockLow) || medicine.isStockEmpty) {
      await NotificationService.showLowStockWarning(medicine);
    }
  }

  static Future<void> updateStock(String medicineId, int newStock) async {
    _ensureInitialized();
    final medicine = _medicineBox.get(medicineId);
    if (medicine == null) {
      return;
    }

    medicine.stockCount = newStock;
    await medicine.save();
    await _notifyLocalDataChanged();
  }

  // ============== DOZ KAYIT İŞLEMLERİ ==============

  static List<DoseLog> getDoseLogsForDate(DateTime date) {
    _ensureInitialized();
    final start = _startOfDay(date);
    final end = _endOfDayExclusive(date);

    return _sortedDoseLogs(
      _doseLogBox.values.where(
        (log) =>
            !log.scheduledTime.isBefore(start) &&
            log.scheduledTime.isBefore(end) &&
            _belongsToMedicineScope(log),
      ),
    );
  }

  static List<DoseLog> getTodayDoseLogs() {
    return getDoseLogsForDate(DateTime.now());
  }

  static List<DoseLog> getDoseLogsForMedicineOnDate(
    String medicineId,
    DateTime date,
  ) {
    return getDoseLogsInRange(
      _startOfDay(date),
      _endOfDayExclusive(date),
      medicineId: medicineId,
    );
  }

  static List<DoseLog> getTodayDoseLogsForMedicine(String medicineId) {
    return getDoseLogsForMedicineOnDate(medicineId, DateTime.now());
  }

  static List<DoseLog> getDoseLogsInRange(
    DateTime start,
    DateTime end, {
    String? medicineId,
  }) {
    _ensureInitialized();
    return _sortedDoseLogs(
      _doseLogBox.values.where(
        (log) =>
            !log.scheduledTime.isBefore(start) &&
            log.scheduledTime.isBefore(end) &&
            _belongsToMedicineScope(log, medicineId: medicineId),
      ),
    );
  }

  static List<DoseLog> getDoseLogsForProfileDate(
    String profileId,
    DateTime date,
  ) {
    final start = _startOfDay(date);
    final end = _endOfDayExclusive(date);
    return getDoseLogsForProfileInRange(profileId, start, end);
  }

  static List<DoseLog> getDoseLogsForProfileInRange(
    String profileId,
    DateTime start,
    DateTime end, {
    String? medicineId,
  }) {
    _ensureInitialized();
    return _sortedDoseLogs(
      _doseLogBox.values.where((log) {
        if (log.scheduledTime.isBefore(start) ||
            !log.scheduledTime.isBefore(end)) {
          return false;
        }

        if (medicineId != null && log.medicineId != medicineId) {
          return false;
        }

        final medicine = _medicineBox.get(log.medicineId);
        if (medicine == null) {
          return false;
        }

        return medicine.profileId == null || medicine.profileId == profileId;
      }),
    );
  }

  static List<DoseLog> getRecentDoseLogs({int days = 30}) {
    final start =
        _startOfDay(DateTime.now().subtract(Duration(days: days - 1)));
    final end = _endOfDayExclusive(DateTime.now());
    return getDoseLogsInRange(start, end);
  }

  static List<DoseLog> getRecentDoseLogsForMedicine(
    String medicineId, {
    int days = 30,
  }) {
    final start =
        _startOfDay(DateTime.now().subtract(Duration(days: days - 1)));
    final end = _endOfDayExclusive(DateTime.now());
    return getDoseLogsInRange(start, end, medicineId: medicineId);
  }

  static List<DoseLog> getAllDoseLogs() {
    _ensureInitialized();
    return _sortedDoseLogs(
      _doseLogBox.values.where((log) => _belongsToMedicineScope(log)),
      descending: true,
    );
  }

  static List<DoseLog> getDoseLogsForMedicine(String medicineId) {
    _ensureInitialized();
    return _sortedDoseLogs(
      _doseLogBox.values.where(
        (log) => _belongsToMedicineScope(log, medicineId: medicineId),
      ),
      descending: true,
    );
  }

  static List<DoseLog> getPendingFutureDoseLogs({int daysAhead = 30}) {
    _ensureInitialized();
    final now = DateTime.now();
    final horizon = now.add(Duration(days: daysAhead));

    return _sortedDoseLogs(
      _doseLogBox.values.where(
        (log) =>
            log.status == DoseStatus.pending &&
            !log.scheduledTime.isBefore(now) &&
            log.scheduledTime.isBefore(horizon) &&
            _belongsToMedicineScope(log),
      ),
    );
  }

  static Future<void> _rebuildUpcomingDoseLogsForMedicine(
      String medicineId) async {
    final todayStart = _startOfDay(DateTime.now());
    final logsToDelete = _doseLogBox.values
        .where(
          (log) =>
              log.medicineId == medicineId &&
              !log.scheduledTime.isBefore(todayStart) &&
              log.status != DoseStatus.taken,
        )
        .toList();

    for (final log in logsToDelete) {
      await NotificationService.cancelDoseNotifications(log.id);
      await _doseLogBox.delete(log.id);
    }
  }

  static Future<void> markDoseAsTaken(String doseLogId) async {
    _ensureInitialized();
    final log = _doseLogBox.get(doseLogId);
    if (log == null) {
      return;
    }

    log.status = DoseStatus.taken;
    log.actionTime = DateTime.now();
    await log.save();

    await decreaseStock(log.medicineId);
    await NotificationService.cancelDoseNotifications(log.id);
    await _notifyLocalDataChanged();
  }

  static Future<DoseLog?> snoozeDose(String doseLogId) async {
    _ensureInitialized();
    final log = _doseLogBox.get(doseLogId);
    if (log == null) {
      return null;
    }

    log.status = DoseStatus.snoozed;
    log.actionTime = DateTime.now();
    await log.save();
    await NotificationService.cancelDoseNotifications(log.id);

    final snoozedLog = DoseLog(
      id: _uuid.v4(),
      medicineId: log.medicineId,
      scheduledTime: DateTime.now().add(const Duration(minutes: 15)),
      status: DoseStatus.pending,
    );
    await _doseLogBox.put(snoozedLog.id, snoozedLog);
    await _notifyLocalDataChanged();
    return snoozedLog;
  }

  static Future<void> markDoseAsMissed(String doseLogId) async {
    _ensureInitialized();
    final log = _doseLogBox.get(doseLogId);
    if (log == null) {
      return;
    }

    log.status = DoseStatus.missed;
    log.actionTime = DateTime.now();
    await log.save();
    await NotificationService.cancelDoseNotifications(log.id);
    await _notifyLocalDataChanged();
  }

  static Future<void> syncMedicineDoseLogs(
    Medicine medicine, {
    int futureDays = 30,
  }) async {
    _ensureInitialized();
    if (!medicine.isActive || medicine.totalDays <= 0) {
      return;
    }

    final syncEnd = medicine.endDate.isBefore(
      DateTime.now().add(Duration(days: futureDays)),
    )
        ? medicine.endDate
        : _startOfDay(DateTime.now().add(Duration(days: futureDays)));

    for (var current = medicine.startDateOnly;
        !current.isAfter(syncEnd);
        current = current.add(const Duration(days: 1))) {
      if (!medicine.isScheduledForDate(current)) {
        continue;
      }

      for (final time in medicine.doseTimes) {
        final scheduledTime = _combineDateAndTime(current, time);
        final exists = _doseLogBox.values.any(
          (log) =>
              log.medicineId == medicine.id &&
              log.scheduledTime.year == scheduledTime.year &&
              log.scheduledTime.month == scheduledTime.month &&
              log.scheduledTime.day == scheduledTime.day &&
              log.scheduledTime.hour == scheduledTime.hour &&
              log.scheduledTime.minute == scheduledTime.minute,
        );

        if (!exists) {
          final log = DoseLog(
            id: _uuid.v4(),
            medicineId: medicine.id,
            scheduledTime: scheduledTime,
            status: DoseStatus.pending,
          );
          await _doseLogBox.put(log.id, log);
        }
      }
    }
  }

  static Future<void> syncDoseLogs({int futureDays = 30}) async {
    _ensureInitialized();
    for (final medicine in _medicineBox.values) {
      await syncMedicineDoseLogs(medicine, futureDays: futureDays);
    }
    await markOverdueDosesAsMissed();
  }

  static Future<void> generateTodayDoseLogs() async {
    await syncDoseLogs();
  }

  static Future<void> markOverdueDosesAsMissed({
    Duration gracePeriod = const Duration(minutes: 30),
  }) async {
    _ensureInitialized();
    final cutoff = DateTime.now().subtract(gracePeriod);

    final overdueLogs = _doseLogBox.values
        .where(
          (log) =>
              log.status == DoseStatus.pending &&
              log.scheduledTime.isBefore(cutoff),
        )
        .toList();

    for (final log in overdueLogs) {
      log.status = DoseStatus.missed;
      log.actionTime = DateTime.now();
      await log.save();
      await NotificationService.cancelDoseNotifications(log.id);
    }
  }

  static List<Medicine> getLowStockMedicines() {
    return getActiveMedicines()
        .where((medicine) => medicine.isStockLow)
        .toList();
  }

  static DoseLog? getDoseLog(String id) {
    _ensureInitialized();
    return _doseLogBox.get(id);
  }
}
