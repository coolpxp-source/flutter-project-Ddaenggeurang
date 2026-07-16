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
}
