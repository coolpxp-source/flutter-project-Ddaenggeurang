import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../services/community_service.dart';
import '../../models/community_post_model.dart';
import 'post_detail_screen.dart';

class MyActivityScreen extends StatefulWidget {
  const MyActivityScreen({super.key});

  @override
  State<MyActivityScreen> createState() => _MyActivityScreenState();
}

class _MyActivityScreenState extends State<MyActivityScreen>
    with SingleTickerProviderStateMixin {
  final _service = CommunityService();
  late final TabController _tabController;

  static const _green = Color(0xFFFF8A3D);
  static const _greenLight = Color(0xFFFFF0E8);

  final String _myId = FirebaseAuth.instance.currentUser!.uid;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Color _categoryColor(String cat) {
    switch (cat) {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        backgroundColor: const Color(0xFFF8F9FA),
        surfaceTintColor: Colors.transparent,
        foregroundColor: Colors.black87,
        title: const Text('내 활동', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        bottom: TabBar(
          controller: _tabController,
          labelColor: _green,
          unselectedLabelColor: Colors.grey[500],
          indicatorColor: _green,
          labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
          tabs: const [
            Tab(text: '내가 쓴 글'),
            Tab(text: '좋아요한 글'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildMyPostsTab(),
          _buildLikedPostsTab(),
        ],
      ),
    );
  }

  Widget _buildMyPostsTab() {
    return StreamBuilder<List<CommunityPost>>(
      stream: _service.getMyPosts(_myId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(color: _green));
        }
        final posts = snapshot.data!;
        if (posts.isEmpty) {
          return _buildEmptyView(
            icon: Icons.edit_note_rounded,
            message: '아직 작성한 글이 없어요',
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: posts.length,
          itemBuilder: (context, i) => _buildPostCard(posts[i]),
        );
      },
    );
  }

  Widget _buildLikedPostsTab() {
    return StreamBuilder<List<String>>(
      stream: _service.getLikedPostIds(_myId),
      builder: (context, idsSnapshot) {
        if (idsSnapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                '좋아요 목록을 불러오지 못했어요.\n${idsSnapshot.error}',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[500], fontSize: 12),
              ),
            ),
          );
        }
        if (!idsSnapshot.hasData) {
          return const Center(child: CircularProgressIndicator(color: _green));
        }
        final postIds = idsSnapshot.data!;
        if (postIds.isEmpty) {
          return _buildEmptyView(
            icon: Icons.favorite_border_rounded,
            message: '아직 좋아요한 글이 없어요',
          );
        }
        return FutureBuilder<List<CommunityPost>>(
          future: _service.getPostsByIds(postIds),
          builder: (context, postsSnapshot) {
            if (postsSnapshot.hasError) {
              return Center(
                child: Text('오류: ${postsSnapshot.error}',
                    style: TextStyle(color: Colors.grey[500], fontSize: 12)),
              );
            }
            if (!postsSnapshot.hasData) {
              return const Center(child: CircularProgressIndicator(color: _green));
            }
            final posts = postsSnapshot.data!;
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: posts.length,
              itemBuilder: (context, i) => _buildPostCard(posts[i]),
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyView({required IconData icon, required String message}) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(color: _greenLight, shape: BoxShape.circle),
            child: Icon(icon, size: 32, color: _green),
          ),
          const SizedBox(height: 16),
          Text(message, style: TextStyle(color: Colors.grey[500], fontSize: 13)),
        ],
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
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 3)),
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
            ],
          ],
        ),
      ),
    );
  }
}