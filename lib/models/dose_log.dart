import 'package:hive/hive.dart';

part 'dose_log.g.dart';

@HiveType(typeId: 2)
enum DoseStatus {
  @HiveField(0)
  pending,

  @HiveField(1)
  taken,

  @HiveField(2)
  snoozed,

  @HiveField(3)
  missed,
}

@HiveType(typeId: 1)
class DoseLog extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String medicineId;

  @HiveField(2)
  final DateTime scheduledTime;

  @HiveField(3)
  DoseStatus status;

  @HiveField(4)
  DateTime? actionTime;

  DoseLog({
    required this.id,
    required this.medicineId,
    required this.scheduledTime,
    this.status = DoseStatus.pending,
    this.actionTime,
  });
}
