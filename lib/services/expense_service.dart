import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/expense_model.dart';

class ExpenseService {
  final _db = FirebaseFirestore.instance;

  /// 10_내역입력_기본, 14_OCR파싱결과_확인및저장
  Future<String> addExpense(ExpenseModel expense) async {
    final docRef = await _db.collection('expenses').add(expense.toFirestore());
    return docRef.id;
  }

  /// 15_내역목록 (삭제되지 않은 것만)
  Stream<List<ExpenseModel>> getExpenses({required String userId}) {
    return _db
        .collection('expenses')
        .where('userId', isEqualTo: userId)
        .where('isDeleted', isEqualTo: false)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => ExpenseModel.fromFirestore(d)).toList());
  }

  /// 16_내역상세 - 단건 조회
  Future<ExpenseModel?> getExpense(String expenseId) async {
    final doc = await _db.collection('expenses').doc(expenseId).get();
    if (!doc.exists) return null;
    return ExpenseModel.fromFirestore(doc);
  }

  /// 16_내역상세 - 수정
  Future<void> updateExpense(String expenseId, Map<String, dynamic> updates) async {
    updates['updatedAt'] = FieldValue.serverTimestamp();
    await _db.collection('expenses').doc(expenseId).update(updates);
  }

  /// 16_내역상세 - 삭제 (소프트 삭제: isDeleted=true, deletedAt 기록)
  Future<void> deleteExpense(String expenseId) async {
    await _db.collection('expenses').doc(expenseId).update({
      'isDeleted': true,
      'deletedAt': FieldValue.serverTimestamp(),
    });
  }

  /// 특정 기간 내 지출 조회 (연말정산 시뮬레이션, 통계 등에서 재사용)
  Future<List<ExpenseModel>> getExpensesByDateRangeOnce({
    required String userId,
    required DateTime start,
    required DateTime end,
  }) async {
    final snap = await _db
        .collection('expenses')
        .where('userId', isEqualTo: userId)
        .where('isDeleted', isEqualTo: false)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(end))
        .orderBy('date', descending: true)
        .get();

    return snap.docs.map((d) => ExpenseModel.fromFirestore(d)).toList();
  }
}