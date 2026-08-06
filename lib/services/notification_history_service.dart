import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/notification_entry_model.dart';

/// 실제로 발송된 로컬 알림의 인앱 기록(알림함). 알림 자체를 띄우는 건
/// NotificationService의 역할이고, 이 서비스는 "떴다는 사실"만 남긴다.
class NotificationHistoryService {
  final _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _col(String uid) =>
      _db.collection('users').doc(uid).collection('notifications');

  Future<void> record({
    required String uid,
    required String title,
    required String body,
    required String type,
  }) {
    return _col(uid).add({
      'title': title,
      'body': body,
      'type': type,
      'read': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<NotificationEntry>> watchHistory(String uid) {
    return _col(uid)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snap) => snap.docs.map(NotificationEntry.fromFirestore).toList());
  }

  Stream<int> watchUnreadCount(String uid) {
    return _col(uid)
        .where('read', isEqualTo: false)
        .snapshots()
        .map((snap) => snap.docs.length);
  }

  Future<void> markRead(String uid, String id) =>
      _col(uid).doc(id).update({'read': true});

  Future<void> delete(String uid, String id) => _col(uid).doc(id).delete();

  /// 회원탈퇴 시 호출 — 서브컬렉션은 자동 삭제되지 않으므로 직접 정리.
  Future<void> deleteAll(String uid) async {
    final docs = await _col(uid).get();
    if (docs.docs.isEmpty) return;
    final batch = _db.batch();
    for (final doc in docs.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }
}
