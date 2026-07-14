import 'package:cloud_firestore/cloud_firestore.dart';

class PostComment {
  final String commentId;
  final String authorId;
  final String authorName;
  final String content;
  final int likeCount;
  final DateTime createdAt;

  PostComment({
    required this.commentId,
    required this.authorId,
    required this.authorName,
    required this.content,
    required this.likeCount,
    required this.createdAt,
  });

  factory PostComment.fromFirestore(DocumentSnapshot doc) {
    final map = doc.data() as Map<String, dynamic>;
    return PostComment(
      commentId: doc.id,
      authorId: map['authorId'] ?? '',
      authorName: map['authorName'] ?? '',
      content: map['content'] ?? '',
      likeCount: map['likeCount'] ?? 0,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}