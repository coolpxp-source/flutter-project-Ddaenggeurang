import 'package:flutter/material.dart';

import '../../models/mission_definition_model.dart';

class MissionCard extends StatelessWidget {
  final MissionDefinition mission;
  final VoidCallback? onTap;
  final bool isCompleted;

  const MissionCard({
    super.key,
    required this.mission,
    this.onTap,
    this.isCompleted = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        onTap: isCompleted ? null : onTap,
        leading: CircleAvatar(
          child: Icon(
            isCompleted ? Icons.check : Icons.flag,
          ),
        ),
        title: Text(
          mission.title,
          style: TextStyle(
            decoration: isCompleted
                ? TextDecoration.lineThrough
                : TextDecoration.none,
          ),
        ),
        subtitle: Text(
          isCompleted
              ? '완료 · ${mission.points} 포인트 획득'
              : '${mission.frequency} · ${mission.points} 포인트',
        ),
        trailing: isCompleted
            ? const Chip(
          label: Text('완료'),
        )
            : const Icon(Icons.chevron_right),
      ),
    );
  }
}