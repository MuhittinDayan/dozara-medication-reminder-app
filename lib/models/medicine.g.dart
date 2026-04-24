// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'medicine.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class MedicineAdapter extends TypeAdapter<Medicine> {
  @override
  final int typeId = 0;

  @override
  Medicine read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Medicine(
      id: fields[0] as String,
      name: fields[1] as String,
      dailyFrequency: fields[2] as int,
      totalDays: fields[3] as int,
      firstDoseTime: fields[4] as String,
      startDate: fields[5] as DateTime,
      stockCount: fields[6] as int?,
      stockWarningThreshold: fields[7] as int,
      isActive: fields[8] as bool,
      colorValue: fields[9] as int,
      form: fields[10] as MedicineForm,
      note: fields[11] as String?,
      withFood: fields[12] as bool,
      profileId: fields[13] as String?,
      dosage: fields[14] as String?,
      scheduleType: fields[15] as MedicineScheduleType?,
      selectedWeekdays: (fields[16] as List?)?.cast<int>(),
      intervalDays: fields[17] as int?,
      reminderTimes: (fields[18] as List?)?.cast<String>(),
      lowStockThreshold: fields.containsKey(19) ? fields[19] as int? : 7,
    );
  }

  @override
  void write(BinaryWriter writer, Medicine obj) {
    writer
      ..writeByte(20)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.dailyFrequency)
      ..writeByte(3)
      ..write(obj.totalDays)
      ..writeByte(4)
      ..write(obj.firstDoseTime)
      ..writeByte(5)
      ..write(obj.startDate)
      ..writeByte(6)
      ..write(obj.stockCount)
      ..writeByte(7)
      ..write(obj.stockWarningThreshold)
      ..writeByte(8)
      ..write(obj.isActive)
      ..writeByte(9)
      ..write(obj.colorValue)
      ..writeByte(10)
      ..write(obj.form)
      ..writeByte(11)
      ..write(obj.note)
      ..writeByte(12)
      ..write(obj.withFood)
      ..writeByte(13)
      ..write(obj.profileId)
      ..writeByte(14)
      ..write(obj.dosage)
      ..writeByte(15)
      ..write(obj.scheduleType)
      ..writeByte(16)
      ..write(obj.selectedWeekdays)
      ..writeByte(17)
      ..write(obj.intervalDays)
      ..writeByte(18)
      ..write(obj.reminderTimes)
      ..writeByte(19)
      ..write(obj.lowStockThreshold);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MedicineAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class MedicineScheduleTypeAdapter extends TypeAdapter<MedicineScheduleType> {
  @override
  final int typeId = 5;

  @override
  MedicineScheduleType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return MedicineScheduleType.daily;
      case 1:
        return MedicineScheduleType.specificDays;
      case 2:
        return MedicineScheduleType.interval;
      default:
        return MedicineScheduleType.daily;
    }
  }

  @override
  void write(BinaryWriter writer, MedicineScheduleType obj) {
    switch (obj) {
      case MedicineScheduleType.daily:
        writer.writeByte(0);
        break;
      case MedicineScheduleType.specificDays:
        writer.writeByte(1);
        break;
      case MedicineScheduleType.interval:
        writer.writeByte(2);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MedicineScheduleTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class MedicineFormAdapter extends TypeAdapter<MedicineForm> {
  @override
  final int typeId = 3;

  @override
  MedicineForm read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return MedicineForm.pill;
      case 1:
        return MedicineForm.syrup;
      case 2:
        return MedicineForm.injection;
      case 3:
        return MedicineForm.drop;
      case 4:
        return MedicineForm.cream;
      case 5:
        return MedicineForm.inhaler;
      default:
        return MedicineForm.pill;
    }
  }

  @override
  void write(BinaryWriter writer, MedicineForm obj) {
    switch (obj) {
      case MedicineForm.pill:
        writer.writeByte(0);
        break;
      case MedicineForm.syrup:
        writer.writeByte(1);
        break;
      case MedicineForm.injection:
        writer.writeByte(2);
        break;
      case MedicineForm.drop:
        writer.writeByte(3);
        break;
      case MedicineForm.cream:
        writer.writeByte(4);
        break;
      case MedicineForm.inhaler:
        writer.writeByte(5);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MedicineFormAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
