import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/consultation_model.dart';

class ConsultationService {
  final _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _col(String uid) =>
      _db.collection('users').doc(uid).collection('consultations');

  /// AI가 답변을 준 상담 1건을 기록한다 (에러/레이트리밋 응답은 저장 안 함).
  Future<void> save({
    required String uid,
    required String question,
    required String answer,
    required String? verdictCode,
  }) {
    return _col(uid).add({
      'question': question,
      'answer': answer,
      'verdictCode': verdictCode,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<ConsultationEntry>> watchHistory(String uid) {
    return _col(uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(ConsultationEntry.fromFirestore).toList());
  }

  Future<void> delete({required String uid, required String consultationId}) {
    return _col(uid).doc(consultationId).delete();
  }

  /// 회원탈퇴 시 호출 — users/{uid} 문서를 지워도 서브컬렉션은 자동으로
  /// 안 지워지므로, 상담이력 전체를 직접 배치 삭제해서 고아 데이터를 막는다.
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
