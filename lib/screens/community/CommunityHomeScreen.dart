import 'package:flutter/material.dart';
import '../../services/community_service.dart';
import '../../widgets/common/bottom_nav_bar.dart';
import 'ranking_screen.dart';
import 'peer_compare_screen.dart';
import 'saving_share_screen.dart';

class CommunityHomeScreen extends StatelessWidget {
  const CommunityHomeScreen({super.key});

  // TODO: 실제 로그인 유저 정보로 교체
  static const String currentUserId = 'test_user_id';
  static const String myAgeGroup = '20대';
  static const String myJob = '학생';

  @override
  Widget build(BuildContext context) {
    final service = CommunityService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('커뮤니티'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 내 저축 비율 카드
            _buildMySavingCard(context, service),
            const SizedBox(height: 16),

            // 랭킹 / 또래비교 진입 버튼 2개
            Row(
              children: [
                Expanded(
                  child: _buildEntryButton(
                    context,
                    icon: Icons.emoji_events,
                    label: '랭킹 보기',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const RankingScreen()),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildEntryButton(
                    context,
                    icon: Icons.groups,
                    label: '또래 비교',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const PeerCompareScreen(
                          ageGroup: myAgeGroup,
                          job: myJob,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // 저축 비율 공유 안내
            _buildShareBanner(context),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavBar(
        currentTab: NavTab.community,
        onTabSelected: (tab) {
          // TODO: 팀 라우팅 구조 확정되면 연결
        },
      ),
    );
  }

  Widget _buildMySavingCard(BuildContext context, CommunityService service) {
    return StreamBuilder(
      stream: service.getRanking(limit: 1000),
      builder: (context, snapshot) {
        num? myRate;
        if (snapshot.hasData) {
          final mine = snapshot.data!
              .where((s) => s.userId == currentUserId)
              .toList();
          if (mine.isNotEmpty) myRate = mine.first.savingRate;
        }

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFEE5586).withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '내 저축 비율',
                style: TextStyle(fontSize: 13, color: Color(0xFFEE5586)),
              ),
              const SizedBox(height: 4),
              Text(
                myRate != null ? '$myRate%' : '아직 공유 안 함',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFEE5586),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEntryButton(
      BuildContext context, {
        required IconData icon,
        required String label,
        required VoidCallback onTap,
      }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.grey[700]),
            const SizedBox(height: 6),
            Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[700])),
          ],
        ),
      ),
    );
  }

  Widget _buildShareBanner(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const SavingShareScreen()),
      ),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Expanded(
              child: Text('내 저축 비율 공유하고 랭킹에 참여해보세요',
                  style: TextStyle(fontSize: 13)),
            ),
            Icon(Icons.chevron_right, color: Colors.grey[500]),
          ],
        ),
      ),
    );
  }
}