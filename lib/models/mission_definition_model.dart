class MissionDefinition {
  final String id;
  final String title;
  final String type;
  final int points;
  final String frequency;
  final bool requiresApproval;
  final bool isActive;

  const MissionDefinition({
    required this.id,
    required this.title,
    required this.type,
    required this.points,
    required this.frequency,
    required this.requiresApproval,
    required this.isActive,
  });

  factory MissionDefinition.fromMap(
      String id,
      Map<String, dynamic> map,
      ) {
    return MissionDefinition(
      id: id,
      title: map['title'] as String? ?? '',
      type: map['type'] as String? ?? '',
      points: (map['points'] as num?)?.toInt() ?? 0,
      frequency: map['frequency'] as String? ?? '',
      requiresApproval:
      map['requiresApproval'] as bool? ?? false,
      isActive: map['isActive'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'type': type,
      'points': points,
      'frequency': frequency,
      'requiresApproval': requiresApproval,
      'isActive': isActive,
    };
  }
}