import 'package:flutter/material.dart';

import '../../models/mission_definition_model.dart';

class MissionCard extends StatelessWidget {
  final MissionDefinition mission;
  final VoidCallback? onTap;

  const MissionCard({
    super.key,
    required this.mission,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        onTap: onTap,
        leading: const CircleAvatar(
          child: Icon(Icons.flag),
        ),
        title: Text(mission.title),
        subtitle: Text(
          '${mission.frequency} · ${mission.points} 포인트',
        ),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}