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
}