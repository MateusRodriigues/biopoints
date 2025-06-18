// lib/models/user_unit_details.dart

class UserUnitDetails {
  final int unitId;
  final String? unitName;
  final int points;
  final String? level;

  UserUnitDetails({
    required this.unitId,
    this.unitName,
    required this.points,
    this.level,
  });

  factory UserUnitDetails.fromJson(Map<String, dynamic> json) {
    return UserUnitDetails(
      unitId: json['unitId'] as int? ?? 0,
      unitName: json['unitName'] as String?,
      points: json['points'] as int? ?? 0,
      level: json['level'] as String?,
    );
  }
}
