import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/travel_model.dart';
import '../models/expense_model.dart';

class TravelService {
  final _db = FirebaseFirestore.instance;

  /// 여행 등록. 한 번에 하나만 isActive=true여야 하므로,
  /// 새 여행을 활성화하기 전 기존 활성 여행을 먼저 비활성화한다.
  Future<String> addTravel(TravelModel travel) async {
    if (travel.isActive) {
      await _deactivateAllActive(travel.userId);
    }
    final doc = await _db.collection('travels').add(travel.toFirestore());
    return doc.id;
  }

  Stream<List<TravelModel>> getTravels(String userId) {
    return _db
        .collection('travels')
        .where('userId', isEqualTo: userId)
        .where('isDeleted', isEqualTo: false)
        .orderBy('startDate', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => TravelModel.fromFirestore(d)).toList());
  }

  Future<TravelModel?> getActiveTravel(String userId) async {
    final snap = await _db
        .collection('travels')
        .where('userId', isEqualTo: userId)
        .where('isActive', isEqualTo: true)
        .where('isDeleted', isEqualTo: false)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return TravelModel.fromFirestore(snap.docs.first);
  }

  Future<void> updateTravel(String travelId, Map<String, dynamic> updates) async {
    await _db.collection('travels').doc(travelId).update(updates);
  }

  Future<void> deleteTravel(String travelId) async {
    await _db.collection('travels').doc(travelId).update({
      'isDeleted': true,
      'deletedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _deactivateAllActive(String userId) async {
    final snap = await _db
        .collection('travels')
        .where('userId', isEqualTo: userId)
        .where('isActive', isEqualTo: true)
        .get();
    for (final doc in snap.docs) {
      await doc.reference.update({'isActive': false});
    }
  }

  /// 지출 등록 시 이 메서드로 현재 활성 여행이 있는지 확인하고,
  /// TravelModel.shouldAutoTag 조건에 맞으면 travelId를 반환 (아니면 null)
  Future<String?> resolveTravelIdForExpense({
    required String userId,
    required DateTime expenseDate,
    required ExpenseNature nature,
    String? installmentPlanId,
    String? recurringPaymentId,
  }) async {
    final activeTravel = await getActiveTravel(userId);
    if (activeTravel == null) return null;

    final shouldTag = activeTravel.shouldAutoTag(
      expenseDate: expenseDate,
      isFixedNature: nature == ExpenseNature.fixed,
      hasInstallmentPlan: installmentPlanId != null,
      hasRecurringPayment: recurringPaymentId != null,
    );

    return shouldTag ? activeTravel.travelId : null;
  }
}