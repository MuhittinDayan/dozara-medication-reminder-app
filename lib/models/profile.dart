import 'package:hive/hive.dart';

part 'profile.g.dart';

@HiveType(typeId: 4)
class Profile extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  int colorValue;

  @HiveField(3)
  String avatarUrl;

  @HiveField(4)
  bool isCaregiverMode;

  @HiveField(5)
  String relation;

  @HiveField(6)
  bool receivesDoseNotifications;

  @HiveField(7)
  bool canManageMedicines;

  @HiveField(8)
  bool isEmergencyContact;

  @HiveField(9)
  String? note;

  Profile({
    required this.id,
    required this.name,
    required this.colorValue,
    required this.avatarUrl,
    this.isCaregiverMode = false,
    this.relation = 'Ben',
    this.receivesDoseNotifications = true,
    this.canManageMedicines = true,
    this.isEmergencyContact = false,
    this.note,
  });

  String get initials {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) {
      return '?';
    }
    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  bool get isPrimarySelf => relation.toLowerCase() == 'ben';

  Profile copyWith({
    String? id,
    String? name,
    int? colorValue,
    String? avatarUrl,
    bool? isCaregiverMode,
    String? relation,
    bool? receivesDoseNotifications,
    bool? canManageMedicines,
    bool? isEmergencyContact,
    String? note,
  }) {
    return Profile(
      id: id ?? this.id,
      name: name ?? this.name,
      colorValue: colorValue ?? this.colorValue,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      isCaregiverMode: isCaregiverMode ?? this.isCaregiverMode,
      relation: relation ?? this.relation,
      receivesDoseNotifications:
          receivesDoseNotifications ?? this.receivesDoseNotifications,
      canManageMedicines: canManageMedicines ?? this.canManageMedicines,
      isEmergencyContact: isEmergencyContact ?? this.isEmergencyContact,
      note: note ?? this.note,
    );
  }
}
