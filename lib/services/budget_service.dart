import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/budget_model.dart';

class BudgetService {
  // Firestore 접근 객체
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // 현재 로그인 사용자 확인 객체
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// 최상위 budgets 컬렉션
  ///
  /// 구조:
  /// budgets/{userId}_{month}
  CollectionReference<Map<String, dynamic>> get _budgetCollection {
    return _firestore.collection('budgets');
  }

  /// 사용자 UID와 연월을 조합해 문서 ID 생성
  ///
  /// 예:
  /// ByToHEgLxaWTTmKU2IJGafdqFjG3_2026-07
  String getBudgetDocumentId({
    required String userId,
    required String month,
  }) {
    return '${userId}_$month';
  }

  /// 현재 로그인 사용자 확인
  User _requireCurrentUser(String userId) {
    final User? currentUser = _auth.currentUser;

    if (currentUser == null) {
      throw Exception('로그인된 사용자가 없습니다.');
    }

    if (currentUser.uid != userId) {
      throw Exception('사용자 UID가 일치하지 않습니다.');
    }

    return currentUser;
  }

  /// 특정 사용자의 특정 월 예산 조회
  Future<BudgetModel?> getBudget({
    required String userId,
    required String month,
  }) async {
    _requireCurrentUser(userId);

    final String documentId = getBudgetDocumentId(
      userId: userId,
      month: month,
    );

    final DocumentSnapshot<Map<String, dynamic>> document =
    await _budgetCollection.doc(documentId).get();

    // 해당 월의 예산이 아직 저장되지 않은 경우
    if (!document.exists) {
      return null;
    }

    return BudgetModel.fromDocument(document);
  }

  /// 예산 저장 또는 수정
  ///
  /// 같은 사용자와 같은 월은 동일한 문서 ID를 사용하므로
  /// 문서가 없으면 생성되고, 문서가 있으면 수정됨
  Future<void> saveBudget({
    required String userId,
    required String month,
    required int totalBudget,
    required int startDay,
    required int fixedExpenseTotal,
    required int subscriptionTotal,
    required Map<String, int> categoryBudgets,
  }) async {
    final User currentUser = _requireCurrentUser(userId);

    // 전체 예산 검사
    if (totalBudget <= 0) {
      throw Exception('전체 예산은 0원보다 커야 합니다.');
    }

    // 예산 시작일 검사
    if (startDay < 1 || startDay > 31) {
      throw Exception(
        '예산 시작일은 1일부터 31일 사이여야 합니다.',
      );
    }

    // 고정지출 검사
    if (fixedExpenseTotal < 0) {
      throw Exception('고정지출은 0원 이상이어야 합니다.');
    }

    // 구독료 검사
    if (subscriptionTotal < 0) {
      throw Exception('구독료는 0원 이상이어야 합니다.');
    }

    // 전체 예산에서 고정지출과 구독료를 제외한 가용 예산
    final int availableBudget =
        totalBudget - fixedExpenseTotal - subscriptionTotal;

    if (availableBudget < 0) {
      throw Exception(
        '전체 예산이 고정지출과 구독료 합계보다 적습니다.',
      );
    }

    // 카테고리 예산에 음수가 있는지 검사
    final bool hasNegativeCategory = categoryBudgets.values.any(
          (amount) => amount < 0,
    );

    if (hasNegativeCategory) {
      throw Exception(
        '카테고리 예산은 0원 이상이어야 합니다.',
      );
    }

    // 카테고리 예산 합계
    final int categoryTotal = categoryBudgets.values.fold<int>(
      0,
          (sum, amount) => sum + amount,
    );

    if (categoryTotal > availableBudget) {
      throw Exception(
        '카테고리 예산 합계가 가용 예산을 초과했습니다.',
      );
    }

    final String documentId = getBudgetDocumentId(
      userId: userId,
      month: month,
    );

    final DocumentReference<Map<String, dynamic>> reference =
    _budgetCollection.doc(documentId);

    // 기존 문서 존재 여부 확인
    final DocumentSnapshot<Map<String, dynamic>> oldDocument =
    await reference.get();

    final Map<String, dynamic> data = {
      'userId': currentUser.uid,
      'month': month,
      'totalBudget': totalBudget,
      'startDay': startDay,
      'fixedExpenseTotal': fixedExpenseTotal,
      'subscriptionTotal': subscriptionTotal,
      'availableBudget': availableBudget,
      'categoryBudgets': categoryBudgets,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    // 최초 저장 시에만 생성 시간 추가
    if (!oldDocument.exists) {
      data['createdAt'] = FieldValue.serverTimestamp();
    }

    // 문서가 없으면 생성, 있으면 기존 문서 수정
    await reference.set(
      data,
      SetOptions(merge: true),
    );
  }

  /// 현재 사용자의 활성 구독료 총액 조회
  Future<int> getSubscriptionTotal(String userId) async {
    _requireCurrentUser(userId);

    final QuerySnapshot<Map<String, dynamic>> snapshot =
    await _firestore
        .collection('subscriptions')
        .where(
      'userId',
      isEqualTo: userId,
    )
        .where(
      'isActive',
      isEqualTo: true,
    )
        .get();

    return snapshot.docs.fold<int>(
      0,
          (sum, document) {
        final Map<String, dynamic> data = document.data();

        final int amount =
            (data['amount'] as num?)?.toInt() ?? 0;

        return sum + amount;
      },
    );
  }
}