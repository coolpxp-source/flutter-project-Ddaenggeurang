import 'package:flutter/material.dart';
import '../../services/community_service.dart';
import '../../models/community_post_model.dart';
import '../../models/post_comment_model.dart';

class PostDetailScreen extends StatefulWidget {
  final CommunityPost post;
  const PostDetailScreen({super.key, required this.post});

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  final _service = CommunityService();
  final _commentController = TextEditingController();
  static const _green = Color(0xFF3B8B5E);
  static const _greenLight = Color(0xFFE6F4EB);

  static const _myId = 'test_user_id';
  static const _myName = '나';

  void _submitComment() {
    if (_commentController.text.trim().isEmpty) return;
    _service.addComment(
      postId: widget.post.postId,
      authorId: _myId,
      authorName: _myName,
      content: _commentController.text.trim(),
    );
    _commentController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('게시글', style: TextStyle(color: Colors.black)),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  children: [
                    CircleAvatar(radius: 16, backgroundColor: _green),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(post.authorName,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: _greenLight,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(post.category,
                              style: const TextStyle(fontSize: 10, color: _green, fontWeight: FontWeight.w500)),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(post.content, style: const TextStyle(fontSize: 14, height: 1.6)),
                const SizedBox(height: 12),

                // 해시태그 배지
                Wrap(
                  spacing: 6,
                  children: [post.category, '땡그랑'].map((tag) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: _greenLight,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text('#$tag',
                          style: const TextStyle(fontSize: 11, color: _green, fontWeight: FontWeight.w500)),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),

                Row(
                  children: [
                    Icon(Icons.favorite_border, size: 18, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text('좋아요 ${post.likeCount}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                    const SizedBox(width: 16),
                    Icon(Icons.chat_bubble_outline, size: 18, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text('댓글 ${post.commentCount}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                  ],
                ),
                Divider(height: 32, color: Colors.grey[200]),

                StreamBuilder<List<PostComment>>(
                  stream: _service.getComments(post.postId),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator(color: _green));
                    }
                    final comments = snapshot.data!;
                    if (comments.isEmpty) {
                      return Text('첫 댓글을 남겨보세요', style: TextStyle(color: Colors.grey[500]));
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('댓글 ${comments.length}개',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        const SizedBox(height: 12),
                        ...comments.map((c) => Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CircleAvatar(radius: 12, backgroundColor: Colors.grey[300]),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(c.authorName,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                    const SizedBox(height: 2),
                                    Text(c.content, style: const TextStyle(fontSize: 13)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        )),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),

          SafeArea(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Colors.grey[200]!)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commentController,
                      style: const TextStyle(fontSize: 13),
                      decoration: InputDecoration(
                        hintText: '댓글을 남겨보세요',
                        hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
                        filled: true,
                        fillColor: Colors.grey[100],
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: const BorderSide(color: _green, width: 1.5),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: _green,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_upward, color: Colors.white, size: 18),
                      onPressed: _submitComment,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}