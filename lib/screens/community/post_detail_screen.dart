import 'post_edit_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../services/community_service.dart';
import '../../models/community_post_model.dart';
import '../../models/post_comment_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PostDetailScreen extends StatefulWidget {
  final CommunityPost post;
  const PostDetailScreen({super.key, required this.post});

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  final _service = CommunityService();
  final _commentController = TextEditingController();
  static const _green = Color(0xFFFF9166);
  static const _greenLight = Color(0xFFFFF0E8);

  final String _myId = FirebaseAuth.instance.currentUser!.uid;

  Future<String> _getAuthorName() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(_myId).get();
      final nickname = doc.data()?['nickname'] as String?;
      if (nickname != null && nickname.trim().isNotEmpty) return nickname;
    } catch (_) {}
    return FirebaseAuth.instance.currentUser?.displayName ?? '나';
  }

  bool _isLiked = false;

  String? _editingCommentId;
  TextEditingController? _editCommentController;

  @override
  void initState() {
    super.initState();
    _service.isPostLiked(widget.post.postId, _myId).listen((liked) {
      if (mounted) setState(() => _isLiked = liked);
    });
  }

  Future<void> _toggleLike() async {
    final next = !_isLiked;
    setState(() => _isLiked = next); // 낙관적 업데이트로 즉각 반응
    try {
      await _service.toggleLike(widget.post.postId, _myId, next);
    } catch (e) {
      if (mounted) setState(() => _isLiked = !next); // 실패 시 롤백
      debugPrint('좋아요 처리 실패: $e');
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

  void _submitComment() async {
    if (_commentController.text.trim().isEmpty) return;
    final authorName = await _getAuthorName();
    _service.addComment(
      postId: widget.post.postId,
      authorId: _myId,
      authorName: authorName,
      content: _commentController.text.trim(),
    );
    _commentController.clear();
  }

  void _confirmDeletePost(BuildContext context, String postId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        titlePadding: const EdgeInsets.fromLTRB(20, 24, 20, 6),
        contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        title: const Text('게시글을 삭제할까요?',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A))),
        content: const Text('삭제하면 되돌릴 수 없어요.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Color(0xFF8A8A8A))),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF555555),
                    backgroundColor: const Color(0xFFF7F7F7),
                    side: const BorderSide(color: Color(0xFFE0E0E0)),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('취소', style: TextStyle(fontWeight: FontWeight.w500)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: () async {
                    await _service.deletePost(postId);
                    if (context.mounted) {
                      Navigator.pop(context);
                      Navigator.pop(context);
                    }
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFD9532A),
                    backgroundColor: const Color(0xFFFFF0E8),
                    side: const BorderSide(color: Color(0xFFFF9166)),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('삭제', style: TextStyle(fontWeight: FontWeight.w500)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _confirmDeleteComment(BuildContext context, String postId, String commentId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        titlePadding: const EdgeInsets.fromLTRB(20, 24, 20, 6),
        contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        title: const Text('댓글을 삭제할까요?',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A))),
        content: const Text('삭제하면 되돌릴 수 없어요.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Color(0xFF8A8A8A))),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF555555),
                    backgroundColor: const Color(0xFFF7F7F7),
                    side: const BorderSide(color: Color(0xFFE0E0E0)),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('취소', style: TextStyle(fontWeight: FontWeight.w500)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: () async {
                    await _service.deleteComment(postId, commentId);
                    if (context.mounted) Navigator.pop(context);
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFD9532A),
                    backgroundColor: const Color(0xFFFFF0E8),
                    side: const BorderSide(color: Color(0xFFFF9166)),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('삭제', style: TextStyle(fontWeight: FontWeight.w500)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _startEditComment(PostComment c) {
    setState(() {
      _editingCommentId = c.commentId;
      _editCommentController = TextEditingController(text: c.content);
    });
  }

  void _cancelEditComment() {
    setState(() => _editingCommentId = null);
  }

  Future<void> _saveEditComment(String postId, String commentId) async {
    final content = _editCommentController?.text.trim() ?? '';
    if (content.isEmpty) return;
    await _service.updateComment(postId, commentId, content);
    setState(() => _editingCommentId = null);
  }

  void _editPost(BuildContext context, CommunityPost post) {
    final controller = TextEditingController(text: post.content);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('게시글 수정'),
        content: TextField(
          controller: controller,
          maxLines: 5,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () async {
              if (controller.text.trim().isEmpty) return;
              await _service.updatePost(post.postId, controller.text.trim());
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('저장'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<CommunityPost>(
      stream: _service.getPostStream(widget.post.postId),
      initialData: widget.post,
      builder: (context, postSnapshot) {
        final post = postSnapshot.data ?? widget.post;
        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            title: const Text('게시글', style: TextStyle(color: Colors.black)),
            actions: [
              if (post.authorId == _myId) ...[
                IconButton(
                  icon: const Icon(Icons.edit_outlined, color: Colors.grey),
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => PostEditScreen(post: post)),
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.grey),
                  onPressed: () => _confirmDeletePost(context, post.postId),
                ),
              ],
            ],
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
                    if (post.updatedAt != null) ...[
                      const SizedBox(height: 4),
                      Text('(수정됨)', style: TextStyle(fontSize: 11, color: Colors.grey[400])),
                    ],

                    if (post.imageUrls.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      SizedBox(
                        height: 220,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: post.imageUrls.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 8),
                          itemBuilder: (context, index) {
                            final url = post.imageUrls[index];
                            return ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(
                                url,
                                width: 220,
                                height: 220,
                                fit: BoxFit.cover,
                                loadingBuilder: (context, child, progress) {
                                  if (progress == null) return child;
                                  return const SizedBox(
                                    width: 220,
                                    height: 220,
                                    child: Center(child: CircularProgressIndicator(color: _green)),
                                  );
                                },
                                errorBuilder: (context, error, stackTrace) => Container(
                                  width: 220,
                                  height: 220,
                                  color: Colors.grey[200],
                                  child: const Icon(Icons.broken_image, color: Colors.grey),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],


                    const SizedBox(height: 12),

                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [post.category, ...post.hashtags].map((tag) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: _categoryColorLight(post.category),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text('#$tag',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: _categoryColor(post.category),
                                  fontWeight: FontWeight.w500)),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),

                    StreamBuilder<List<PostComment>>(
                      stream: _service.getComments(post.postId),
                      builder: (context, snapshot) {
                        final commentCount = snapshot.data?.length ?? 0;
                        return Row(
                          children: [
                            GestureDetector(
                              onTap: _toggleLike,
                              child: Row(
                                children: [
                                  Icon(
                                    _isLiked ? Icons.favorite : Icons.favorite_border,
                                    size: 18,
                                    color: _isLiked ? Colors.redAccent : Colors.grey[600],
                                  ),
                                  const SizedBox(width: 4),
                                  Text('좋아요 ${post.likeCount}',
                                      style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            Icon(Icons.chat_bubble_outline, size: 18, color: Colors.grey[600]),
                            const SizedBox(width: 4),
                            Text('댓글 $commentCount',
                                style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                          ],
                        );
                      },
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
                            ...comments.map((c) {
                              final isEditing = _editingCommentId == c.commentId;

                              return Padding(
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
                                          const SizedBox(height: 4),
                                          if (isEditing) ...[
                                            TextField(
                                              controller: _editCommentController,
                                              autofocus: true,
                                              maxLines: null,
                                              style: const TextStyle(fontSize: 13),
                                              decoration: InputDecoration(
                                                isDense: true,
                                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                                filled: true,
                                                fillColor: Colors.grey[100],
                                                border: OutlineInputBorder(
                                                  borderRadius: BorderRadius.circular(10),
                                                  borderSide: BorderSide.none,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            Row(
                                              children: [
                                                GestureDetector(
                                                  onTap: _cancelEditComment,
                                                  child: Text('취소', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                                                ),
                                                const SizedBox(width: 12),
                                                GestureDetector(
                                                  onTap: () => _saveEditComment(post.postId, c.commentId),
                                                  child: const Text('저장',
                                                      style: TextStyle(fontSize: 12, color: _green, fontWeight: FontWeight.bold)),
                                                ),
                                              ],
                                            ),
                                          ] else ...[
                                            Text(c.content, style: const TextStyle(fontSize: 13)),
                                            if (c.updatedAt != null) ...[
                                              const SizedBox(height: 2),
                                              Text('(수정됨)', style: TextStyle(fontSize: 10, color: Colors.grey[400])),
                                            ],
                                          ],
                                        ],
                                      ),
                                    ),
                                    if (!isEditing && c.authorId == _myId) ...[
                                      GestureDetector(
                                        onTap: () => _startEditComment(c),
                                        child: Icon(Icons.edit, size: 15, color: Colors.grey[400]),
                                      ),
                                      const SizedBox(width: 10),
                                      GestureDetector(
                                        onTap: () => _confirmDeleteComment(context, post.postId, c.commentId),
                                        child: Icon(Icons.close, size: 16, color: Colors.grey[400]),
                                      ),
                                    ],
                                  ],
                                ),
                              );
                            }),
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
      },
    );
  }
}