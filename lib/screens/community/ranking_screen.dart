import 'package:flutter/material.dart';
import '../../services/community_service.dart';

class RankingScreen extends StatelessWidget {
  const RankingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = CommunityService();

    return Scaffold(
      appBar: AppBar(title: const Text('랭킹')),
      body: StreamBuilder(
        stream: service.getRanking(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final list = snapshot.data!;
          if (list.isEmpty) {
            return const Center(child: Text('아직 랭킹 데이터가 없어요'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final stat = list[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: index < 3
                      ? const Color(0xFFEE5586)
                      : Colors.grey[300],
                  foregroundColor: index < 3 ? Colors.white : Colors.grey[700],
                  child: Text('${index + 1}'),
                ),
                title: Text(stat.nicknameMasked),
                subtitle: Text('${stat.ageGroup} · ${stat.job}'),
                trailing: Text(
                  '${stat.savingRate}%',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFEE5586),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}