import 'package:ddaenggeurang/screens/community/post_detail_screen.dart';
import 'package:flutter/material.dart';
import '../../services/community_service.dart';
import '../../models/community_post_model.dart';
import '../../widgets/common/bottom_nav_bar.dart';
import 'ranking_screen.dart';

class CommunityHomeScreen extends StatefulWidget {
  const CommunityHomeScreen({super.key});

  @override
  State<CommunityHomeScreen> createState() => _CommunityHomeScreenState();
}

class _CommunityHomeScreenState extends State<CommunityHomeScreen> {
  final _service = CommunityService();
  String _selectedCategory = '전체';
  static const _categories = ['전체', '절약팁', '소비고민', '자유'];

  // 메인 컬러: 초록 계열
  static const _green = Color(0xFF3B8B5E);
  static const _greenLight = Color(0xFFE6F4EB);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('커뮤니티', style: TextStyle(color: Colors.black)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(child: Text('땡그랑', style: TextStyle(color: Colors.grey[500]))),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 히어로 배너 (연한 초록 배경 + 초록 텍스트)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _greenLight,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _green.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('돈 이야기, 편하게 해요',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87)),
                      const SizedBox(height: 4),
                      Text('절약 팁부터 소소한 이야기까지',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                    ],
                  ),
                ),
                CircleAvatar(radius: 20, backgroundColor: _green),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 카테고리 탭
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final cat = _categories[i];
                final selected = cat == _selectedCategory;
                return ChoiceChip(
                  label: Text(cat),
                  selected: selected,
                  onSelected: (_) => setState(() => _selectedCategory = cat),
                  selectedColor: _green,
                  backgroundColor: Colors.white,
                  side: BorderSide(color: selected ? _green : Colors.grey[300]!),
                  labelStyle: TextStyle(
                    color: selected ? Colors.white : Colors.black87,
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),

          // 검색바
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Row(
              children: [
                Icon(Icons.search, color: Colors.grey[500], size: 20),
                const SizedBox(width: 8),
                Text('궁금한 주제나 태그를 검색해보세요',
                    style: TextStyle(color: Colors.grey[500], fontSize: 13)),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 랭킹 TOP3 배너 (초록 배경)
          _buildRankingBanner(),
          const SizedBox(height: 16),

          // 피드
          StreamBuilder<List<CommunityPost>>(
            stream: _service.getPosts(category: _selectedCategory),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final posts = snapshot.data!;
              if (posts.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(child: Text('아직 게시글이 없어요')),
                );
              }
              return Column(
                children: posts.map((p) => _buildPostCard(p)).toList(),
              );
            },
          ),
        ],
      ),
      bottomNavigationBar: BottomNavBar(
        currentTab: NavTab.community,
        onTabSelected: (tab) {},
      ),
    );
  }

  Widget _buildRankingBanner() {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const RankingScreen()),
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _green,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('이번 달', style: TextStyle(color: Colors.white70, fontSize: 12)),
            const SizedBox(height: 4),
            const Text('최다 저축 랭킹 TOP 3',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            StreamBuilder(
              stream: _service.getRanking(limit: 3),
              builder: (context, snapshot) {
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Text('아직 랭킹 데이터가 없어요',
                      style: TextStyle(color: Colors.white70, fontSize: 12));
                }
                final top3 = snapshot.data!;
                return Row(
                  children: List.generate(top3.length, (i) {
                    final stat = top3[i];
                    return Expanded(
                      child: Container(
                        margin: EdgeInsets.only(right: i < top3.length - 1 ? 8 : 0),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: i == 0 ? Colors.white : Colors.white.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          children: [
                            Text('${stat.savingRate}%',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: i == 0 ? _green : Colors.white,
                                )),
                            const SizedBox(height: 4),
                            Text('${i + 1}',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: i == 0 ? _green : Colors.white,
                                )),
                          ],
                        ),
                      ),
                    );
                  }),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPostCard(CommunityPost post) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => PostDetailScreen(post: post)),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(radius: 6, backgroundColor: _green),
                const SizedBox(width: 8),
                Text(post.authorName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              ],
            ),
            const SizedBox(height: 8),
            Text(post.content, style: const TextStyle(fontSize: 13), maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 8),
            Text('#${post.category}', style: TextStyle(fontSize: 11, color: _green)),
            const SizedBox(height: 8),
            Text('좋아요 ${post.likeCount} · 댓글 ${post.commentCount}',
                style: TextStyle(fontSize: 11, color: Colors.grey[500])),
          ],
        ),
      ),
    );
  }
}