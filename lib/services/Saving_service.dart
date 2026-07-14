import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/saving_model.dart';

class SavingService {
  final _db = FirebaseFirestore.instance;

  Future<String> addSaving(SavingModel saving) async {
    final doc = await _db.collection('savings').add(saving.toFirestore());
    return doc.id;
  }

  Stream<List<SavingModel>> getSavings({required String userId}) {
    return _db
        .collection('savings')
        .where('userId', isEqualTo: userId)
        .where('isDeleted', isEqualTo: false)
        .orderBy('date', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => SavingModel.fromFirestore(d)).toList());
  }

  Future<SavingModel?> getSaving(String savingId) async {
    final doc = await _db.collection('savings').doc(savingId).get();
    if (!doc.exists) return null;
    return SavingModel.fromFirestore(doc);
  }

  Future<void> updateSaving(String savingId, Map<String, dynamic> updates) async {
    await _db.collection('savings').doc(savingId).update(updates);
  }

  Future<void> deleteSaving(String savingId) async {
    await _db.collection('savings').doc(savingId).update({
      'isDeleted': true,
      'deletedAt': FieldValue.serverTimestamp(),
    });
  }

  /// 커뮤니티 저축비율 공유(61번)를 위한 합산 조회
  Future<double> getTotalSavingAmount({
    required String userId,
    required DateTime start,
    required DateTime end,
  }) async {
    final snap = await _db
        .collection('savings')
        .where('userId', isEqualTo: userId)
        .where('isDeleted', isEqualTo: false)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(end))
        .get();

    return snap.docs.fold<double>(
      0,
          (sum, d) => sum + ((d['amount'] as num?)?.toDouble() ?? 0),
    );
  }
}