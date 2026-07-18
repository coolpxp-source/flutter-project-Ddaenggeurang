import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/login_history_entry.dart';

/// 로그인 성공 기록 — "최근 로그인" 배지와 별개로, 언제/어떤 방법으로
/// 로그인했는지 이력을 남겨서 마이페이지 > 설정 > 로그인 활동에서 보여준다.
class LoginHistoryService {
  final _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _col(String uid) =>
      _db.collection('users').doc(uid).collection('loginHistory');

  Future<void> record({required String uid, required String method}) {
    return _col(uid).add({
      'method': method,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<LoginHistoryEntry>> watchHistory(String uid) {
    return _col(uid)
        .orderBy('createdAt', descending: true)
        .limit(30)
        .snapshots()
        .map((snap) => snap.docs.map(LoginHistoryEntry.fromFirestore).toList());
  }

  /// 회원탈퇴 시 호출 — users/{uid} 문서를 지워도 서브컬렉션은 자동으로
  /// 안 지워지므로, 로그인 이력 전체를 직접 배치 삭제해서 고아 데이터를 막는다.
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
