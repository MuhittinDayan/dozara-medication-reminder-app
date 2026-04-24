import '../../models/dose_log.dart';
import '../../models/medicine.dart';
import '../../models/profile.dart';

extension MedicineSupabaseMapper on Medicine {
  Map<String, dynamic> toSupabaseJson(String userId) {
    return {
      'id': id,
      'user_id': userId,
      'profile_id': profileId,
      'name': name,
      'daily_frequency': dailyFrequency,
      'total_days': totalDays,
      'first_dose_time': firstDoseTime,
      'start_date': startDate.toIso8601String(),
      'stock_count': stockCount,
      'stock_warning_threshold': stockWarningThreshold,
      'is_active': isActive,
      'color_value': colorValue,
      'form': form.name,
      'note': note,
      'with_food': withFood,
      'dosage': dosage,
      'schedule_type': scheduleTypeValue.name,
      'selected_weekdays': selectedWeekdaysValue,
      'interval_days': intervalDaysValue,
      'reminder_times': doseTimes,
      'low_stock_threshold': lowStockThreshold,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
  }

  static Medicine fromSupabaseJson(Map<String, dynamic> json) {
    return Medicine(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      dailyFrequency: json['daily_frequency'] as int? ?? 1,
      totalDays: json['total_days'] as int? ?? 1,
      firstDoseTime: json['first_dose_time'] as String? ?? '09:00',
      startDate: _dateTime(json['start_date']) ?? DateTime.now(),
      stockCount: json['stock_count'] as int?,
      stockWarningThreshold: json['stock_warning_threshold'] as int? ?? 5,
      isActive: json['is_active'] as bool? ?? true,
      colorValue: json['color_value'] as int? ?? 0xFF2E7D32,
      form: _medicineForm(json['form'] as String?),
      note: json['note'] as String?,
      withFood: json['with_food'] as bool? ?? false,
      profileId: json['profile_id'] as String?,
      dosage: json['dosage'] as String?,
      scheduleType: _scheduleType(json['schedule_type'] as String?),
      selectedWeekdays: _intList(json['selected_weekdays']),
      intervalDays: json['interval_days'] as int?,
      reminderTimes: _stringList(json['reminder_times']),
      lowStockThreshold: json['low_stock_threshold'] as int?,
    );
  }
}

extension DoseLogSupabaseMapper on DoseLog {
  Map<String, dynamic> toSupabaseJson(String userId, String? profileId) {
    return {
      'id': id,
      'user_id': userId,
      'profile_id': profileId,
      'medicine_id': medicineId,
      'scheduled_time': scheduledTime.toUtc().toIso8601String(),
      'status': status.name,
      'action_time': actionTime?.toUtc().toIso8601String(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
  }

  static DoseLog fromSupabaseJson(Map<String, dynamic> json) {
    return DoseLog(
      id: json['id'] as String,
      medicineId: json['medicine_id'] as String,
      scheduledTime: _dateTime(json['scheduled_time']) ?? DateTime.now(),
      status: _doseStatus(json['status'] as String?),
      actionTime: _dateTime(json['action_time']),
    );
  }
}

extension ProfileSupabaseMapper on Profile {
  Map<String, dynamic> toSupabaseJson(String userId) {
    return {
      'id': id,
      'user_id': userId,
      'name': name,
      'color_value': colorValue,
      'avatar_url': avatarUrl,
      'is_caregiver_mode': isCaregiverMode,
      'relation': relation,
      'receives_dose_notifications': receivesDoseNotifications,
      'can_manage_medicines': canManageMedicines,
      'is_emergency_contact': isEmergencyContact,
      'note': note,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
  }

  static Profile fromSupabaseJson(Map<String, dynamic> json) {
    return Profile(
      id: json['id'] as String,
      name: json['name'] as String? ?? 'Ben',
      colorValue: json['color_value'] as int? ?? 0xFF00897B,
      avatarUrl: json['avatar_url'] as String? ?? '',
      isCaregiverMode: json['is_caregiver_mode'] as bool? ?? false,
      relation: json['relation'] as String? ?? 'Ben',
      receivesDoseNotifications:
          json['receives_dose_notifications'] as bool? ?? true,
      canManageMedicines: json['can_manage_medicines'] as bool? ?? true,
      isEmergencyContact: json['is_emergency_contact'] as bool? ?? false,
      note: json['note'] as String?,
    );
  }
}

DateTime? _dateTime(Object? value) {
  if (value == null) {
    return null;
  }
  if (value is DateTime) {
    return value.toLocal();
  }
  return DateTime.tryParse(value.toString())?.toLocal();
}

MedicineForm _medicineForm(String? value) {
  return MedicineForm.values.firstWhere(
    (form) => form.name == value,
    orElse: () => MedicineForm.pill,
  );
}

MedicineScheduleType _scheduleType(String? value) {
  return MedicineScheduleType.values.firstWhere(
    (type) => type.name == value,
    orElse: () => MedicineScheduleType.daily,
  );
}

DoseStatus _doseStatus(String? value) {
  return DoseStatus.values.firstWhere(
    (status) => status.name == value,
    orElse: () => DoseStatus.pending,
  );
}

List<int>? _intList(Object? value) {
  if (value is List) {
    return value.whereType<num>().map((item) => item.toInt()).toList();
  }
  return null;
}

List<String>? _stringList(Object? value) {
  if (value is List) {
    return value.map((item) => item.toString()).toList();
  }
  return null;
}
