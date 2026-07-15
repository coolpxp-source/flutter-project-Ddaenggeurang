import 'package:cloud_firestore/cloud_firestore.dart';

class CommunityPost {
  final String postId;
  final String authorId;
  final String authorName;
  final String category;
  final String content;
  final int likeCount;
  final int commentCount;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final List<String> imageUrls;
  final List<String> hashtags;

  CommunityPost({
    required this.postId,
    required this.authorId,
    required this.authorName,
    required this.category,
    required this.content,
    required this.likeCount,
    required this.commentCount,
    required this.createdAt,
    this.updatedAt,
    required this.imageUrls,
    this.hashtags = const [],
  });

  factory CommunityPost.fromFirestore(DocumentSnapshot doc) {
    final map = doc.data() as Map<String, dynamic>;
    return CommunityPost(
      postId: doc.id,
      authorId: map['authorId'] ?? '',
      authorName: map['authorName'] ?? '',
      category: map['category'] ?? '자유',
      content: map['content'] ?? '',
      likeCount: map['likeCount'] ?? 0,
      commentCount: map['commentCount'] ?? 0,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate(),
      imageUrls: List<String>.from(map['imageUrls'] ?? []),
      hashtags: List<String>.from(map['hashtags'] ?? []),
    );
  }
}