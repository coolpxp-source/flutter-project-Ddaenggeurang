import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../services/community_service.dart';
import '../../models/community_post_model.dart';
import '../../widgets/common/bottom_nav_bar.dart';
import 'ranking_screen.dart';
import 'post_detail_screen.dart';
import 'post_write_screen.dart';
import 'package:circular_menu/circular_menu.dart';
import '../market/market_home_screen.dart';
import '../../widgets/common/app_header.dart';
import '../../widgets/common/app_drawer.dart';

class CommunityHomeScreen extends StatefulWidget {
  const CommunityHomeScreen({super.key});

  @override
  State<CommunityHomeScreen> createState() => _CommunityHomeScreenState();
}

class _CommunityHomeScreenState extends State<CommunityHomeScreen> {
  final _service = CommunityService();
  String _selectedCategory = '전체';
  final _searchController = TextEditingController();
  String _searchQuery = '';
  static const _categories = ['전체', '절약팁', '소비고민', '자유', '거지방'];
  static const _writeCategories = ['절약팁', '소비고민', '자유', '거지방'];

  static const _green = Color(0xFFFF8A3D);
  static const _greenLight = Color(0xFFFFF0E8);
  static const _gradientStart = Color(0xFFFFA351);
  static const _gradientEnd = Color(0xFFFF6B1A);

  bool _showMarketHint = true;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) setState(() => _showMarketHint = false);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      drawer: const AppDrawer(),
      appBar: buildDdaengHeader(
        context,
        uid,
        inkColor: Colors.black87,
        extraActions: [
          if (_showMarketHint)
            GestureDetector(
              onTap: () {
                setState(() => _showMarketHint = false);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const MarketHomeScreen()),
                );
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: _green,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: _green.withOpacity(0.3),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('마켓 바로가기!',
                            style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                        const SizedBox(width: 4),
                        GestureDetector(
                          onTap: () => setState(() => _showMarketHint = false),
                          child: const Icon(Icons.close, size: 12, color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                  ClipPath(
                    clipper: _RightTailClipper(),
                    child: Container(width: 6, height: 12, color: _green),
                  ),
                ],
              ),
            ),
          IconButton(
            icon: Icon(Icons.storefront_outlined, color: Colors.grey[700]),
            tooltip: '마켓',
            onPressed: () {
              setState(() => _showMarketHint = false);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MarketHomeScreen()),
              );
            },
          ),
          const SizedBox(width: 4),
        ],
      ),

      body: CircularMenu(
        alignment: Alignment.bottomRight,
        radius: 90,
        toggleButtonColor: _green,
        toggleButtonIconColor: Colors.white,
        toggleButtonSize: 30,
        toggleButtonPadding: 18,
        toggleButtonMargin: 20,
        toggleButtonBoxShadow: [
          BoxShadow(
            color: _green.withOpacity(0.4),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        items: _writeCategories.map((cat) {
          return CircularMenuItem(
            icon: _categoryIcon(cat),
            color: _categoryColor(cat),
            iconColor: Colors.white,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PostWriteScreen(initialCategory: cat),
                ),
              );
            },
          );
        }).toList(),
        backgroundWidget: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // 히어로 배너
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [_gradientStart, _gradientEnd],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('돈 이야기, 편하게 해요',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                        const SizedBox(height: 4),
                        Text('절약 팁부터 소소한 이야기까지',
                            style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.9))),
                      ],
                    ),
                  ),
                  const CircleAvatar(radius: 20, backgroundColor: Colors.white24),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 카테고리 탭
            SizedBox(
              height: 82,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _categories.length,
                separatorBuilder: (_, __) => const SizedBox(width: 14),
                itemBuilder: (context, i) {
                  final cat = _categories[i];
                  final selected = cat == _selectedCategory;
                  final catColor = _categoryColor(cat);
                  final catColorLight = _categoryColorLight(cat);

                  return GestureDetector(
                    onTap: () => setState(() => _selectedCategory = cat),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: selected ? catColor : catColorLight,
                            shape: BoxShape.circle,
                            boxShadow: selected
                                ? [
                              BoxShadow(
                                color: catColor.withOpacity(0.3),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ]
                                : [],
                          ),
                          child: Icon(
                            _categoryIcon(cat),
                            color: selected ? Colors.white : catColor,
                            size: 22,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          cat,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                            color: selected ? catColor : Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),

            // 검색바
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(Icons.search, color: Colors.grey[500], size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      style: const TextStyle(fontSize: 13),
                      decoration: InputDecoration(
                        hintText: '궁금한 주제나 태그를 검색해보세요',
                        hintStyle: TextStyle(color: Colors.grey[500], fontSize: 13),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onChanged: (value) => setState(() => _searchQuery = value.trim()),
                    ),
                  ),
                  if (_searchQuery.isNotEmpty)
                    GestureDetector(
                      onTap: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                      child: Icon(Icons.close, color: Colors.grey[400], size: 18),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 랭킹 TOP3 배너
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

                // 검색어로 본문/해시태그 필터링
                final filteredPosts = _searchQuery.isEmpty
                    ? posts
                    : posts.where((p) {
                  final query = _searchQuery.toLowerCase();
                  final matchesContent = p.content.toLowerCase().contains(query);
                  final matchesHashtag =
                  p.hashtags.any((tag) => tag.toLowerCase().contains(query));
                  return matchesContent || matchesHashtag;
                }).toList();

                if (filteredPosts.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(20),
                    child: Center(
                      child: Text(
                        _searchQuery.isEmpty ? '아직 게시글이 없어요' : '검색 결과가 없어요',
                        style: TextStyle(color: Colors.grey[500]),
                      ),
                    ),
                  );
                }
                return Column(
                  children: filteredPosts.map((p) => _buildPostCard(p)).toList(),
                );
              },
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavBar(
        currentTab: NavTab.community,
        onTabSelected: (tab) {
          if (tab == NavTab.community) return;
          Navigator.of(context).pop();
        },
      ),
    );
  }

  IconData _categoryIcon(String cat) {
    switch (cat) {
      case '전체':
        return Icons.grid_view_rounded;
      case '절약팁':
        return Icons.savings_outlined;
      case '소비고민':
        return Icons.psychology_alt_outlined;
      case '자유':
        return Icons.chat_bubble_outline;
      case '거지방':
        return Icons.money_off_rounded;
      default:
        return Icons.circle_outlined;
    }
  }

  Color _categoryColor(String cat) {
    switch (cat) {
      case '전체':
        return _green;
      case '절약팁':
        return const Color(0xFF4CAF87);
      case '소비고민':
        return const Color(0xFF9B7EDE);
      case '자유':
        return const Color(0xFF5B9BD5);
      case '거지방':
        return const Color(0xFFE5735A);
      default:
        return _green;
    }
  }

  Color _categoryColorLight(String cat) {
    switch (cat) {
      case '전체':
        return _greenLight;
      case '절약팁':
        return const Color(0xFFE6F5EF);
      case '소비고민':
        return const Color(0xFFF1ECFA);
      case '자유':
        return const Color(0xFFEAF2FA);
      case '거지방':
        return const Color(0xFFFBECE9);
      default:
        return _greenLight;
    }
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
          color: const Color(0xFFFFFBF8),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _green.withOpacity(0.15)),
          boxShadow: [
            BoxShadow(
              color: _green.withOpacity(0.18),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('이번 달', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                Text('7.1 - 7.13 기준',
                    style: TextStyle(color: Colors.grey[400], fontSize: 11)),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [_gradientStart, _gradientEnd],
                    ),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: const Text('👑', style: TextStyle(fontSize: 15)),
                ),
                const SizedBox(width: 8),
                const Text('최다 저축 랭킹 TOP 3',
                    style: TextStyle(color: Colors.black87, fontSize: 17, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 20),
            StreamBuilder(
              stream: _service.getAmountRanking(limit: 3),
              builder: (context, snapshot) {
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Text('아직 랭킹 데이터가 없어요',
                      style: TextStyle(color: Colors.grey[400], fontSize: 12));
                }
                final top3 = snapshot.data!;
                if (top3.length < 3) {
                  return Row(
                    children: top3
                        .asMap()
                        .entries
                        .map((e) => Expanded(child: _rankBox(e.value, e.key)))
                        .toList(),
                  );
                }

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
                                style: TextStyle(
                                    color: isFirst ? _gradientEnd : Colors.grey[700],
                                    fontWeight: FontWeight.bold,
                                    fontSize: isFirst ? 15 : 13)),
                            const SizedBox(height: 8),
                            Container(
                              height: isFirst ? 110 : 90,
                              decoration: BoxDecoration(
                                gradient: isFirst
                                    ? const LinearGradient(
                                  colors: [_gradientStart, _gradientEnd],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                )
                                    : null,
                                color: isFirst ? null : _greenLight,
                                borderRadius: BorderRadius.circular(12),
                                border: isFirst ? null : Border.all(color: _green.withOpacity(0.2)),
                                boxShadow: isFirst
                                    ? [
                                  BoxShadow(
                                    color: _gradientEnd.withOpacity(0.35),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ]
                                    : [],
                              ),
                              alignment: Alignment.center,
                              child: Text('$rank',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: isFirst ? Colors.white : _green,
                                  )),
                            ),
                            const SizedBox(height: 8),
                            Text(stat.nicknameMasked,
                                style: TextStyle(
                                    color: isFirst ? Colors.black87 : Colors.grey[600],
                                    fontSize: 12,
                                    fontWeight: isFirst ? FontWeight.bold : FontWeight.normal),
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
              color: _greenLight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _green.withOpacity(0.2)),
            ),
            alignment: Alignment.center,
            child: Text('${index + 1}',
                style: TextStyle(color: _green, fontWeight: FontWeight.bold, fontSize: 20)),
          ),
          const SizedBox(height: 8),
          Text(stat.nicknameMasked, style: TextStyle(color: Colors.grey[700], fontSize: 12)),
        ],
      ),
    );
  }

  String _formatAmount(num value) {
    // 저축률(%)이 아니라 금액(원) 표시가 필요하면 이 함수에서 계산
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
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 12,
                        backgroundColor: _greenLight,
                        child: Icon(Icons.person, size: 14, color: _green),
                      ),
                      const SizedBox(width: 8),
                      Text(post.authorName,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(post.content,
                      style: const TextStyle(fontSize: 13, height: 1.4),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [post.category, ...post.hashtags].map((tag) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: _categoryColorLight(post.category),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text('#$tag',
                            style: TextStyle(
                                fontSize: 11,
                                color: _categoryColor(post.category),
                                fontWeight: FontWeight.w500)),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 10),
                  Text('좋아요 ${post.likeCount} · 댓글 ${post.commentCount}',
                      style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                ],
              ),
            ),
            if (post.imageUrls.isNotEmpty) ...[
              const SizedBox(width: 12),
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      post.imageUrls.first,
                      width: 72,
                      height: 72,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        width: 72,
                        height: 72,
                        color: Colors.grey[200],
                        child: const Icon(Icons.broken_image, color: Colors.grey, size: 20),
                      ),
                    ),
                  ),
                  if (post.imageUrls.length > 1)
                    Positioned(
                      right: 4,
                      bottom: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text('+${post.imageUrls.length - 1}',
                            style: const TextStyle(color: Colors.white, fontSize: 10)),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
class _RightTailClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.moveTo(0, 0);
    path.lineTo(size.width, size.height / 2);
    path.lineTo(0, size.height);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}