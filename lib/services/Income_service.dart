import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/income_model.dart';

class IncomeService {
  final _db = FirebaseFirestore.instance;

  /// 수입 등록 (수동 입력 또는 반복등록 템플릿에서 자동 생성된 것 모두)
  Future<String> addIncome(IncomeModel income) async {
    final doc = await _db.collection('incomes').add(income.toFirestore());
    return doc.id;
  }

  /// 목록 조회 (삭제되지 않은 것만)
  Stream<List<IncomeModel>> getIncomes({required String userId}) {
    return _db
        .collection('incomes')
        .where('userId', isEqualTo: userId)
        .where('isDeleted', isEqualTo: false)
        .orderBy('date', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => IncomeModel.fromFirestore(d)).toList());
  }

  Future<IncomeModel?> getIncome(String incomeId) async {
    final doc = await _db.collection('incomes').doc(incomeId).get();
    if (!doc.exists) return null;
    return IncomeModel.fromFirestore(doc);
  }

  Future<void> updateIncome(String incomeId, Map<String, dynamic> updates) async {
    await _db.collection('incomes').doc(incomeId).update(updates);
  }

  /// 소프트 삭제
  Future<void> deleteIncome(String incomeId) async {
    await _db.collection('incomes').doc(incomeId).update({
      'isDeleted': true,
      'deletedAt': FieldValue.serverTimestamp(),
    });
  }

  /// 기간별 조회 (연말정산 시뮬레이션 등에서 재사용)
  Future<List<IncomeModel>> getIncomesByDateRangeOnce({
    required String userId,
    required DateTime start,
    required DateTime end,
  }) async {
    final snap = await _db
        .collection('incomes')
        .where('userId', isEqualTo: userId)
        .where('isDeleted', isEqualTo: false)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(end))
        .orderBy('date', descending: true)
        .get();

    return snap.docs.map((d) => IncomeModel.fromFirestore(d)).toList();
  }

  // ── 반복등록(월급 등) 템플릿 ──────────────────────────

  Future<String> addRecurringTemplate(RecurringIncomeTemplate template) async {
    final doc = await _db.collection('recurringIncomeTemplates').add(template.toFirestore());
    return doc.id;
  }

  Stream<List<RecurringIncomeTemplate>> getRecurringTemplates(String userId) {
    return _db
        .collection('recurringIncomeTemplates')
        .where('userId', isEqualTo: userId)
        .where('isDeleted', isEqualTo: false)
        .snapshots()
        .map((s) => s.docs.map((d) => RecurringIncomeTemplate.fromFirestore(d)).toList());
  }

  Future<void> updateRecurringTemplate(String templateId, Map<String, dynamic> updates) async {
    await _db.collection('recurringIncomeTemplates').doc(templateId).update(updates);
  }

  Future<void> deleteRecurringTemplate(String templateId) async {
    await _db.collection('recurringIncomeTemplates').doc(templateId).update({
      'isDeleted': true,
      'deletedAt': FieldValue.serverTimestamp(),
    });
  }
}