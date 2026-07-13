import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/community_post_model.dart';
import '../models/community_stat_model.dart';
import '../models/post_comment_model.dart';

class CommunityService {
  final _db = FirebaseFirestore.instance;

  // 랭킹 (저축률 높은 순, 상위 N개)
  Stream<List<CommunityStat>> getRanking({int limit = 50}) {
    return _db
        .collection('communityStats')
        .orderBy('savingRate', descending: true)
        .limit(limit)
        .snapshots()
        .map((s) => s.docs.map((d) => CommunityStat.fromFirestore(d)).toList());
  }

  // 또래 비교: 같은 ageGroup+job 그룹 평균 저축률
  Future<double> getPeerAverageSavingRate({
    required String ageGroup,
    required String job,
  }) async {
    final snap = await _db
        .collection('communityStats')
        .where('ageGroup', isEqualTo: ageGroup)
        .where('job', isEqualTo: job)
        .get();

    if (snap.docs.isEmpty) return 0;
    final total = snap.docs.fold<num>(
      0,
          (sum, d) => sum + (d['savingRate'] ?? 0),
    );
    return total / snap.docs.length;
  }

  // 내 저축 비율 공유/갱신 (61_저축비율공유)
  Future<void> updateMyStat(String userId, CommunityStat stat) async {
    await _db.collection('communityStats').doc(userId).set(stat.toMap());
  }

  Stream<List<CommunityPost>> getPosts({String? category}) {
    Query query = _db.collection('communityPosts').orderBy('createdAt', descending: true);
    if (category != null && category != '전체') {
      query = query.where('category', isEqualTo: category);
    }
    return query.snapshots().map(
          (s) => s.docs.map((d) => CommunityPost.fromFirestore(d)).toList(),
    );
  }

  // 댓글 목록 (실시간)
  Stream<List<PostComment>> getComments(String postId) {
    return _db
        .collection('communityPosts')
        .doc(postId)
        .collection('comments')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((s) => s.docs.map((d) => PostComment.fromFirestore(d)).toList());
  }

// 댓글 작성
  Future<void> addComment({
    required String postId,
    required String authorId,
    required String authorName,
    required String content,
  }) async {
    final postRef = _db.collection('communityPosts').doc(postId);
    await postRef.collection('comments').add({
      'authorId': authorId,
      'authorName': authorName,
      'content': content,
      'likeCount': 0,
      'createdAt': Timestamp.now(),
    });
    await postRef.update({'commentCount': FieldValue.increment(1)});
  }

// 게시글 좋아요
  Future<void> togglePostLike(String postId, bool isLiking) async {
    await _db.collection('communityPosts').doc(postId).update({
      'likeCount': FieldValue.increment(isLiking ? 1 : -1),
    });
  }

  Future<void> createPost({
    required String authorId,
    required String authorName,
    required String category,
    required String content,
  }) async {
    await _db.collection('communityPosts').add({
      'authorId': authorId,
      'authorName': authorName,
      'category': category,
      'content': content,
      'likeCount': 0,
      'commentCount': 0,
      'createdAt': Timestamp.now(),
    });
  }

  // 홈 배너 TOP3용 — 저축 금액 기준
  Stream<List<CommunityStat>> getAmountRanking({int limit = 3}) {
    return _db
        .collection('communityStats')
        .orderBy('savingAmount', descending: true)
        .limit(limit)
        .snapshots()
        .map((s) => s.docs.map((d) => CommunityStat.fromFirestore(d)).toList());
  }


}