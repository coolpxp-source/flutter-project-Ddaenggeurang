import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/installment_plan_model.dart';
import '../models/expense_model.dart';
import 'expense_service.dart';

class InstallmentPlanService {
  final _db = FirebaseFirestore.instance;
  final _expenseService = ExpenseService();

  /// 할부 원거래 등록
  Future<String> addPlan(InstallmentPlan plan) async {
    final doc = await _db.collection('installmentPlans').add(plan.toFirestore());
    return doc.id;
  }

  Stream<List<InstallmentPlan>> getPlans(String userId) {
    return _db
        .collection('installmentPlans')
        .where('userId', isEqualTo: userId)
        .where('isDeleted', isEqualTo: false)
        .orderBy('startDate', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => InstallmentPlan.fromFirestore(d)).toList());
  }

  Future<void> updatePlan(String planId, Map<String, dynamic> updates) async {
    await _db.collection('installmentPlans').doc(planId).update(updates);
  }

  Future<void> deletePlan(String planId) async {
    await _db.collection('installmentPlans').doc(planId).update({
      'isDeleted': true,
      'deletedAt': FieldValue.serverTimestamp(),
    });
  }

  /// 진행 중인(완료 안 된) 할부 전체를 확인해서, 이번 달 회차 지출이 아직 안 만들어졌으면 생성
  /// (앱 실행 시 또는 특정 화면 진입 시 한 번씩 호출하는 방식으로 사용)
  Future<void> generateThisMonthExpenses(String userId) async {
    final snap = await _db
        .collection('installmentPlans')
        .where('userId', isEqualTo: userId)
        .where('isDeleted', isEqualTo: false)
        .get();

    final plans = snap.docs.map((d) => InstallmentPlan.fromFirestore(d)).toList();
    final now = DateTime.now();

    for (final plan in plans) {
      if (plan.isFinished) continue;

      final currentNo = plan.currentInstallmentNo(asOf: now);

      // 이번 회차가 이미 생성됐는지 확인
      final existing = await _db
          .collection('expenses')
          .where('installmentPlanId', isEqualTo: plan.installmentPlanId)
          .where('installmentInstallmentNo', isEqualTo: currentNo)
          .limit(1)
          .get();

      if (existing.docs.isNotEmpty) continue;

      final expense = ExpenseModel(
        expenseId: '',
        userId: userId,
        amount: plan.monthlyAmount,
        date: DateTime(now.year, now.month, plan.startDate.day),
        categoryId: plan.categoryId,
        nature: ExpenseNature.fixed,
        installmentPlanId: plan.installmentPlanId,
        installmentInstallmentNo: currentNo,
      );

      await _expenseService.addExpense(expense);
    }
  }
}