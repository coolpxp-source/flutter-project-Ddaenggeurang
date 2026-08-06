import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/community_post_model.dart';
import '../models/community_stat_model.dart';
import '../models/post_comment_model.dart';

/// 또래 평균 조회 결과
class PeerAverages {
  final double savingRate;
  final double expenseAmount;
  final double incomeAmount;
  final int sampleSize;

  /// 'exact' | 'ageGroupOnly' | 'all' | 'none'
  final String matchLevel;

  PeerAverages({
    required this.savingRate,
    required this.expenseAmount,
    required this.incomeAmount,
    required this.sampleSize,
    required this.matchLevel,
  });
}

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
  //
  // 표본이 부족한 상태에서 조건이 너무 좁으면 항상 0%만 나오는 문제가 있어
  // getPeerAverages()로 대체하는 것을 권장. 기존 호출부 호환을 위해 유지.
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

  /// 또래 평균 저축률/지출/수입을 한 번에 조회
  Future<PeerAverages> getPeerAverages({
    required String ageGroup,
    required String job,
  }) async {
    QuerySnapshot<Map<String, dynamic>> snap = await _db
        .collection('communityStats')
        .where('ageGroup', isEqualTo: ageGroup)
        .where('job', isEqualTo: job)
        .get();

    String matchLevel = 'exact';

    if (snap.docs.isEmpty) {
      snap = await _db
          .collection('communityStats')
          .where('ageGroup', isEqualTo: ageGroup)
          .get();
      matchLevel = 'ageGroupOnly';
    }

    if (snap.docs.isEmpty) {
      snap = await _db.collection('communityStats').limit(200).get();
      matchLevel = 'all';
    }

    if (snap.docs.isEmpty) {
      return PeerAverages(
        savingRate: 0,
        expenseAmount: 0,
        incomeAmount: 0,
        sampleSize: 0,
        matchLevel: 'none',
      );
    }

    final stats = snap.docs.map((d) => CommunityStat.fromFirestore(d)).toList();

    double average(num Function(CommunityStat stat) select) {
      final total = stats.fold<num>(0, (sum, stat) => sum + select(stat));
      return total / stats.length;
    }

    return PeerAverages(
      savingRate: average((s) => s.savingRate),
      expenseAmount: average((s) => s.expenseAmount),
      incomeAmount: average((s) => s.incomeAmount),
      sampleSize: stats.length,
      matchLevel: matchLevel,
    );
  }

  /// 현재 로그인 유저의 공유된 저축비율 통계 (없으면 null — 아직 공유 안 한 상태)
  Future<CommunityStat?> getMyStat(String userId) async {
    final doc = await _db.collection('communityStats').doc(userId).get();
    if (!doc.exists) return null;
    return CommunityStat.fromFirestore(doc);
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

  Future<void> createPost({
    required String authorId,
    required String authorName,
    required String category,
    required String content,
    List<String> imageUrls = const [],
    List<String> hashtags = const [],
  }) async {
    await _db.collection('communityPosts').add({
      'authorId': authorId,
      'authorName': authorName,
      'category': category,
      'content': content,
      'imageUrls': imageUrls,
      'hashtags': hashtags,
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

  // 좋아요 여부 확인
  Stream<bool> isPostLiked(String postId, String userId) {
    return _db
        .collection('communityPosts')
        .doc(postId)
        .collection('likedBy')
        .doc(userId)
        .snapshots()
        .map((doc) => doc.exists);
  }

// 좋아요 토글
  Future<void> toggleLike(String postId, String userId, bool isLiking) async {
    final ref = _db
        .collection('communityPosts')
        .doc(postId)
        .collection('likedBy')
        .doc(userId);

    if (isLiking) {
      await ref.set({'userId': userId, 'createdAt': Timestamp.now()});
    } else {
      await ref.delete();
    }

    await _db.collection('communityPosts').doc(postId).update({
      'likeCount': FieldValue.increment(isLiking ? 1 : -1),
    });
  }

  // 게시글 단건 실시간 구독
  Stream<CommunityPost> getPostStream(String postId) {
    return _db
        .collection('communityPosts')
        .doc(postId)
        .snapshots()
        .map((doc) => CommunityPost.fromFirestore(doc));
  }

  // 게시글 삭제
  Future<void> deletePost(String postId) async {
    await _db.collection('communityPosts').doc(postId).delete();
  }

// 댓글 삭제
  Future<void> deleteComment(String postId, String commentId) async {
    await _db
        .collection('communityPosts')
        .doc(postId)
        .collection('comments')
        .doc(commentId)
        .delete();
    await _db.collection('communityPosts').doc(postId).update({
      'commentCount': FieldValue.increment(-1),
    });
  }

  // 게시글 수정
  Future<void> updatePost(String postId, String content, {List<String>? imageUrls, List<String>? hashtags}) async {
    final data = <String, dynamic>{
      'content': content,
      'updatedAt': Timestamp.now(),
    };
    if (imageUrls != null) {
      data['imageUrls'] = imageUrls;
    }
    if (hashtags != null) {
      data['hashtags'] = hashtags;
    }
    await _db.collection('communityPosts').doc(postId).update(data);
  }

// 댓글 수정
  Future<void> updateComment(String postId, String commentId, String newContent) async {
    await _db
        .collection('communityPosts')
        .doc(postId)
        .collection('comments')
        .doc(commentId)
        .update({
      'content': newContent,
      'updatedAt': Timestamp.now(),
    });
  }

  // 내가 쓴 글
  Stream<List<CommunityPost>> getMyPosts(String userId) {
    return _db
        .collection('communityPosts')
        .where('authorId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => CommunityPost.fromFirestore(d)).toList());
  }

// 내가 좋아요한 글의 postId 목록 (likedBy 서브컬렉션을 collectionGroup으로 가로질러 조회)
  Stream<List<String>> getLikedPostIds(String userId) {
    return _db
        .collectionGroup('likedBy')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => d.reference.parent.parent!.id).toList());
  }

// postId 목록으로 실제 게시글 조회 (whereIn은 10개 제한이 있어 10개씩 나눠 조회)
  Future<List<CommunityPost>> getPostsByIds(List<String> postIds) async {
    if (postIds.isEmpty) return [];

    final List<CommunityPost> result = [];
    for (var i = 0; i < postIds.length; i += 10) {
      final chunk = postIds.sublist(i, i + 10 > postIds.length ? postIds.length : i + 10);
      final snap = await _db
          .collection('communityPosts')
          .where(FieldPath.documentId, whereIn: chunk)
          .get();
      result.addAll(snap.docs.map((d) => CommunityPost.fromFirestore(d)));
    }

    // whereIn 결과는 순서가 안 보장되므로, 좋아요한 순서(postIds 순서)대로 재정렬
    final byId = {for (final p in result) p.postId: p};
    return postIds.map((id) => byId[id]).whereType<CommunityPost>().toList();
  }

}