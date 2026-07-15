import 'package:flutter/material.dart';
import '../../services/community_service.dart';
import '../../models/community_post_model.dart';
import '../../widgets/common/bottom_nav_bar.dart';
import 'ranking_screen.dart';
import 'post_detail_screen.dart';
import 'post_write_screen.dart';

class CommunityHomeScreen extends StatefulWidget {
  const CommunityHomeScreen({super.key});

  @override
  State<CommunityHomeScreen> createState() => _CommunityHomeScreenState();
}

class _CommunityHomeScreenState extends State<CommunityHomeScreen> {
  final _service = CommunityService();
  String _selectedCategory = '전체';
  static const _categories = ['전체', '절약팁', '소비고민', '자유', '거지방'];

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
      floatingActionButton: FloatingActionButton(
        backgroundColor: _green,
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const PostWriteScreen()),
        ),
        child: const Icon(Icons.edit, color: Colors.white),
      ),
      bottomNavigationBar: BottomNavBar(
        currentTab: NavTab.community,
        // 이 화면은 홈에서 push로 열린 별도 화면이라, 다른 탭을 누르면
        // 이 화면을 닫고 그걸 열었던 화면(대부분 홈)으로 돌아간다.
        onTabSelected: (tab) {
          if (tab == NavTab.community) return;
          Navigator.of(context).pop();
        },
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
          color: Colors.black,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('이번 달', style: TextStyle(color: Colors.white54, fontSize: 12)),
                Text('7.1 - 7.13 기준',
                    style: TextStyle(color: Colors.grey[500], fontSize: 11)),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Text('최다 저축 랭킹 TOP 3',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(width: 6),
                const Text('👑', style: TextStyle(fontSize: 16)),
              ],
            ),
            const SizedBox(height: 20),
            StreamBuilder(
              stream: _service.getAmountRanking(limit: 3),
              builder: (context, snapshot) {
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Text('아직 랭킹 데이터가 없어요',
                      style: TextStyle(color: Colors.white70, fontSize: 12));
                }
                final top3 = snapshot.data!;
                if (top3.length < 3) {
                  // 3개 미만이면 그냥 순서대로만 표시 (재배치 로직 생략)
                  return Row(
                    children: top3
                        .asMap()
                        .entries
                        .map((e) => Expanded(child: _rankBox(e.value, e.key)))
                        .toList(),
                  );
                }

                // 화면 순서: 2등 - 1등 - 3등
                final ordered = [top3[1], top3[0], top3[2]];
                final ranks = [2, 1, 3];

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: List.generate(3, (i) {
                    final stat = ordered[i];
                    final rank = ranks[i];
                    final isFirst = rank == 1;

                    return Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(right: i < 2 ? 10 : 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text('${_formatAmount(stat.savingAmount)}원',
                                style: const TextStyle(
                                    color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                            const SizedBox(height: 8),
                            Container(
                              height: isFirst ? 110 : 90,
                              decoration: BoxDecoration(
                                color: isFirst
                                    ? const Color(0xFF3B8B5E)
                                    : const Color(0xFF3B8B5E).withOpacity(0.4),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              alignment: Alignment.center,
                              child: Text('$rank',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  )),
                            ),
                            const SizedBox(height: 8),
                            Text(stat.nicknameMasked,
                                style: const TextStyle(color: Colors.white, fontSize: 12),
                                overflow: TextOverflow.ellipsis),
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

  Widget _rankBox(dynamic stat, int index) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        children: [
          Container(
            height: 90,
            decoration: BoxDecoration(
              color: const Color(0xFF6B5A1E),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Text('${index + 1}', style: const TextStyle(color: Colors.white, fontSize: 20)),
          ),
          const SizedBox(height: 8),
          Text(stat.nicknameMasked, style: const TextStyle(color: Colors.white, fontSize: 12)),
        ],
      ),
    );
  }

  String _formatAmount(num value) {
    // 저축률(%)이 아니라 금액(원) 표시가 필요하면 이 함수에서 계산
    // 지금은 savingRate 값을 그대로 "원"처럼 보여주는 임시 처리
    return value.toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]},',
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