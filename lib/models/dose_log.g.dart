// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'dose_log.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class DoseLogAdapter extends TypeAdapter<DoseLog> {
  @override
  final int typeId = 1;

  @override
  DoseLog read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return DoseLog(
      id: fields[0] as String,
      medicineId: fields[1] as String,
      scheduledTime: fields[2] as DateTime,
      status: fields[3] as DoseStatus,
      actionTime: fields[4] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, DoseLog obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.medicineId)
      ..writeByte(2)
      ..write(obj.scheduledTime)
      ..writeByte(3)
      ..write(obj.status)
      ..writeByte(4)
      ..write(obj.actionTime);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DoseLogAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class DoseStatusAdapter extends TypeAdapter<DoseStatus> {
  @override
  final int typeId = 2;

  @override
  DoseStatus read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return DoseStatus.pending;
      case 1:
        return DoseStatus.taken;
      case 2:
        return DoseStatus.snoozed;
      case 3:
        return DoseStatus.missed;
      default:
        return DoseStatus.pending;
    }
  }

  @override
  void write(BinaryWriter writer, DoseStatus obj) {
    switch (obj) {
      case DoseStatus.pending:
        writer.writeByte(0);
        break;
      case DoseStatus.taken:
        writer.writeByte(1);
        break;
      case DoseStatus.snoozed:
        writer.writeByte(2);
        break;
      case DoseStatus.missed:
        writer.writeByte(3);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DoseStatusAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
