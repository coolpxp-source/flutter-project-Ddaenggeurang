import 'package:flutter/material.dart';
import '../../services/community_service.dart';
import '../../models/community_stat_model.dart';

class RankingScreen extends StatelessWidget {
  const RankingScreen({super.key});

  static const _green = Color(0xFFFF8A3D);
  static const _greenLight = Color(0xFFFFF0E8);
  static const _gradientStart = Color(0xFFFFA351);
  static const _gradientEnd = Color(0xFFFF6B1A);

  // 1/2/3등 메달 색
  static const _gold = Color(0xFFFFC107);
  static const _silver = Color(0xFFB0BEC5);
  static const _bronze = Color(0xFFD7A46A);

  Color _medalColor(int rank) {
    if (rank == 1) return _gold;
    if (rank == 2) return _silver;
    if (rank == 3) return _bronze;
    return _greenLight;
  }

  @override
  Widget build(BuildContext context) {
    final service = CommunityService();

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        backgroundColor: const Color(0xFFF8F9FA),
        surfaceTintColor: Colors.transparent,
        foregroundColor: Colors.black87,
        title: const Text('랭킹', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      ),
      body: StreamBuilder<List<CommunityStat>>(
        stream: service.getRanking(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator(color: _green));
          }
          final list = snapshot.data!;
          if (list.isEmpty) {
            return _buildEmptyView();
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
            children: [
              _buildHeaderCard(list.length),
              const SizedBox(height: 16),
              ...List.generate(list.length, (index) {
                final rank = index + 1;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _buildRankTile(list[index], rank),
                );
              }),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeaderCard(int count) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_gradientStart, _gradientEnd],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: const BoxDecoration(color: Colors.white24, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: const Text('👑', style: TextStyle(fontSize: 22)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('저축률 랭킹',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 3),
                Text('총 $count명 참여 중',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRankTile(CommunityStat stat, int rank) {
    final bool isTopThree = rank <= 3;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: isTopThree ? Border.all(color: _medalColor(rank), width: 1.5) : null,
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 3)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isTopThree ? _medalColor(rank) : _greenLight,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              '$rank',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: isTopThree ? Colors.white : _green,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  stat.nicknameMasked,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF222222)),
                ),
                const SizedBox(height: 3),
                Text(
                  '${stat.ageGroup} · ${stat.job}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${stat.savingRate.toStringAsFixed(1)}%',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: _green),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyView() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(color: _greenLight, shape: BoxShape.circle),
            child: const Icon(Icons.emoji_events_outlined, size: 32, color: _green),
          ),
          const SizedBox(height: 16),
          Text('아직 랭킹 데이터가 없어요', style: TextStyle(color: Colors.grey[500], fontSize: 13)),
        ],
      ),
    );
  }
}