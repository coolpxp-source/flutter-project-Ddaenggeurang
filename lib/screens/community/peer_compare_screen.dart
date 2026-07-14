import 'package:flutter/material.dart';
import '../../services/community_service.dart';

class PeerCompareScreen extends StatelessWidget {
  final String ageGroup;
  final String job;

  const PeerCompareScreen({
    super.key,
    required this.ageGroup,
    required this.job,
  });

  // TODO: 실제 로그인 유저의 저축률로 교체
  static const num myRate = 32;

  @override
  Widget build(BuildContext context) {
    final service = CommunityService();

    return Scaffold(
      appBar: AppBar(title: const Text('또래 비교')),
      body: FutureBuilder<double>(
        future: service.getPeerAverageSavingRate(ageGroup: ageGroup, job: job),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final peerAvg = snapshot.data!;
          final diff = myRate - peerAvg;

          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$ageGroup · $job 평균과 비교', style: const TextStyle(fontSize: 14, color: Colors.grey)),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatColumn('내 저축률', '$myRate%', const Color(0xFFEE5586)),
                    _buildStatColumn('또래 평균', '${peerAvg.toStringAsFixed(1)}%', Colors.grey[700]!),
                  ],
                ),
                const SizedBox(height: 24),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: diff >= 0 ? Colors.green[50] : Colors.orange[50],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    diff >= 0
                        ? '또래보다 ${diff.toStringAsFixed(1)}%p 더 저축하고 있어요 👍'
                        : '또래보다 ${(-diff).toStringAsFixed(1)}%p 적게 저축하고 있어요',
                    style: TextStyle(
                      color: diff >= 0 ? Colors.green[800] : Colors.orange[800],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatColumn(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }
}