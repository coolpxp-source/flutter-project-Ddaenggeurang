import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/budget_model.dart';

class BudgetService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// 최상위 budgets 컬렉션
  CollectionReference<Map<String, dynamic>> get _budgetCollection {
    return _firestore.collection('budgets');
  }

  /// userId와 month를 조합한 월별 고정 문서 ID
  String getBudgetDocumentId({
    required String userId,
    required String month,
  }) {
    return '${userId}_$month';
  }

  /// 특정 사용자의 특정 월 예산 조회
  Future<BudgetModel?> getBudget({
    required String userId,
    required String month,
  }) async {
    final String documentId = getBudgetDocumentId(
      userId: userId,
      month: month,
    );

    final document = await _budgetCollection.doc(documentId).get();

    if (!document.exists) {
      return null;
    }

    return BudgetModel.fromDocument(document);
  }

  /// 전체 예산과 카테고리별 예산 저장
  ///
  /// 문서가 이미 있으면 수정되고,
  /// 문서가 없으면 새로 생성됨
  Future<void> saveBudget({
    required String userId,
    required String month,
    required int totalBudget,
    required int startDay,
    required int fixedExpenseTotal,
    required int subscriptionTotal,
    required Map<String, int> categoryBudgets,
  }) async {
    final currentUser = _auth.currentUser;

    if (currentUser == null) {
      throw Exception('로그인된 사용자가 없습니다.');
    }

    if (currentUser.uid != userId) {
      throw Exception('사용자 UID가 일치하지 않습니다.');
    }

    final int availableBudget =
        totalBudget - fixedExpenseTotal - subscriptionTotal;

    if (availableBudget < 0) {
      throw Exception('전체 예산이 고정지출과 구독료 합계보다 적습니다.');
    }

    final int categoryTotal = categoryBudgets.values.fold(
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

    final document = await reference.get();

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

    // 처음 등록할 때만 createdAt 추가
    if (!document.exists) {
      data['createdAt'] = FieldValue.serverTimestamp();
    }

    await reference.set(
      data,
      SetOptions(merge: true),
    );

    debugPrint('예산 저장 완료: $documentId');
  }

  /// 현재 사용자의 활성 구독 총액 계산
  Future<int> getSubscriptionTotal(String userId) async {
    final snapshot = await _firestore
        .collection('subscriptions')
        .where('userId', isEqualTo: userId)
        .where('isActive', isEqualTo: true)
        .get();

    return snapshot.docs.fold<int>(
      0,
          (sum, document) {
        final data = document.data();
        return sum + ((data['amount'] as num?)?.toInt() ?? 0);
      },
    );
  }
}