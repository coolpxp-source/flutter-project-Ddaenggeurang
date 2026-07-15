import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/recurring_payment_model.dart';
import '../models/expense_model.dart';
import 'expense_service.dart';

class RecurringPaymentService {
  final _db = FirebaseFirestore.instance;
  final _expenseService = ExpenseService();

  Future<String> addRecurringPayment(RecurringPaymentModel payment) async {
    final doc = await _db.collection('recurringPayments').add(payment.toFirestore());
    return doc.id;
  }

  Stream<List<RecurringPaymentModel>> getRecurringPayments(String userId) {
    return _db
        .collection('recurringPayments')
        .where('userId', isEqualTo: userId)
        .where('isDeleted', isEqualTo: false)
        .snapshots()
        .map((s) => s.docs.map((d) => RecurringPaymentModel.fromFirestore(d)).toList());
  }

  Future<void> updateRecurringPayment(String id, Map<String, dynamic> updates) async {
    await _db.collection('recurringPayments').doc(id).update(updates);
  }

  Future<void> deleteRecurringPayment(String id) async {
    await _db.collection('recurringPayments').doc(id).update({
      'isDeleted': true,
      'deletedAt': FieldValue.serverTimestamp(),
    });
  }

  /// nextBillingDate가 오늘 이전/오늘인 항목들을 확인해서 지출을 생성하고
  /// nextBillingDate를 다음 주기로 갱신 (monthly면 +1개월, yearly면 +1년)
  Future<void> generateDuePayments(String userId) async {
    final now = DateTime.now();

    final snap = await _db
        .collection('recurringPayments')
        .where('userId', isEqualTo: userId)
        .where('isDeleted', isEqualTo: false)
        .where('nextBillingDate', isLessThanOrEqualTo: Timestamp.fromDate(now))
        .get();

    for (final doc in snap.docs) {
      final payment = RecurringPaymentModel.fromFirestore(doc);

      final expense = ExpenseModel(
        expenseId: '',
        userId: userId,
        amount: payment.amount,
        date: payment.nextBillingDate,
        categoryId: payment.categoryId,
        nature: ExpenseNature.fixed,
        recurringPaymentId: payment.recurringPaymentId,
      );
      await _expenseService.addExpense(expense);

      final nextDate = payment.billingCycle == BillingCycle.monthly
          ? DateTime(payment.nextBillingDate.year, payment.nextBillingDate.month + 1,
          payment.nextBillingDate.day)
          : DateTime(payment.nextBillingDate.year + 1, payment.nextBillingDate.month,
          payment.nextBillingDate.day);

      await _db.collection('recurringPayments').doc(payment.recurringPaymentId).update({
        'nextBillingDate': Timestamp.fromDate(nextDate),
      });
    }
  }
}