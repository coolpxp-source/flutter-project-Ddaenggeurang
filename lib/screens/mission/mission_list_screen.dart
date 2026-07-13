import 'package:flutter/material.dart';

import '../../models/mission_definition_model.dart';
import '../../services/mission_service.dart';
import '../../widgets/mission/mission_card.dart';
import 'attendance_check_screen.dart';

class MissionListScreen extends StatefulWidget {
  const MissionListScreen({super.key});

  @override
  State<MissionListScreen> createState() => _MissionListScreenState();
}

class _MissionListScreenState extends State<MissionListScreen> {
  final MissionService _missionService = MissionService();
  bool _isAttendanceCompleted = false;

  late Future<List<MissionDefinition>> _missionsFuture;

  @override
  void initState() {
    super.initState();
    _missionsFuture = _missionService.getMissions();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('미션'),
      ),
      body: FutureBuilder<List<MissionDefinition>>(
        future: _missionsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return const Center(
              child: Text('미션을 불러오지 못했습니다.'),
            );
          }

          final missions = snapshot.data ?? [];

          if (missions.isEmpty) {
            return const Center(
              child: Text('진행 가능한 미션이 없습니다.'),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: missions.length,
            itemBuilder: (context, index) {
              final mission = missions[index];
              return MissionCard(
                mission: mission,
                isCompleted:
                mission.type == 'attendance' && _isAttendanceCompleted,
                onTap: () async {
                  if (mission.type == 'attendance') {
                    final result = await Navigator.push<bool>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AttendanceCheckScreen(),
                      ),
                    );
                    if (result == true && mounted) {
                      setState(() {
                        _isAttendanceCompleted = true;
                      });
                    }
                    return;
                  }
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${mission.title} 선택'),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}