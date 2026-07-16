import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'budget_service.dart';

class PsychologyTestService {
  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;
  final BudgetService _budgetService = BudgetService();

  String get _currentUserId {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      throw StateError('로그인된 사용자가 없습니다.');
    }

    return user.uid;
  }
// 심리 유형별 카테고리 예산을 계산하는 메서드
  Map<String, int> buildRecommendedCategoryBudgets({
    required int availableBudget,
    required String resultType,
  }) {
    if (availableBudget < 0) {
      throw Exception('가용 예산은 0원 이상이어야 합니다.');
    }

    final Map<String, int> recommendation =
    _getRecommendationPercent(resultType);

    final int livingPercent =
        recommendation['living'] ?? 0;

    final int flexiblePercent =
        recommendation['flexible'] ?? 0;

    final int livingBudget =
        availableBudget * livingPercent ~/ 100;

    final int flexibleBudget =
        availableBudget * flexiblePercent ~/ 100;

    final int housingBudget =
        livingBudget * 35 ~/ 100;

    final int foodBudget =
        livingBudget * 30 ~/ 100;

    final int transportBudget =
        livingBudget * 20 ~/ 100;

    final int etcBudget =
        livingBudget -
            housingBudget -
            foodBudget -
            transportBudget;

    final int shoppingBudget =
        flexibleBudget * 55 ~/ 100;

    final int cultureBudget =
        flexibleBudget - shoppingBudget;

    return {
      'food': foodBudget,
      'transport': transportBudget,
      'shopping': shoppingBudget,
      'culture': cultureBudget,
      'housing': housingBudget,
      'etc': etcBudget,
    };
  }

  // 소비심리 유형별 추천 비율을 반환하는 메서드
  Map<String, int> _getRecommendationPercent(
      String resultType,
      ) {
    switch (resultType) {
      case 'impulsive_spender':
        return {
          'living': 50,
          'saving': 30,
          'flexible': 20,
        };

      case 'emotion_spender':
        return {
          'living': 50,
          'saving': 25,
          'flexible': 25,
        };

      case 'balanced_spender':
        return {
          'living': 50,
          'saving': 30,
          'flexible': 20,
        };

      case 'planned_spender':
        return {
          'living': 45,
          'saving': 40,
          'flexible': 15,
        };

      default:
        throw Exception('지원하지 않는 소비심리 유형입니다.');
    }
  }

  // 현재 월 예산에 소비심리 추천 예산을 적용하는 메서드
  Future<Map<String, int>> applyRecommendedBudget({
    required String resultType,
  }) async {
    final DateTime now = DateTime.now();

    final String month =
        '${now.year}-${now.month.toString().padLeft(2, '0')}';

    final budget = await _budgetService.getBudget(
      userId: _currentUserId,
      month: month,
    );

    if (budget == null) {
      throw StateError(
        '현재 월의 예산이 없습니다. 먼저 전체 예산을 등록해 주세요.',
      );
    }

    final Map<String, int> categoryBudgets =
    buildRecommendedCategoryBudgets(
      availableBudget: budget.availableBudget,
      resultType: resultType,
    );

    await _budgetService.saveBudget(
      userId: _currentUserId,
      month: budget.month,
      totalBudget: budget.totalBudget,
      startDay: budget.startDay,
      fixedExpenseTotal: budget.fixedExpenseTotal,
      subscriptionTotal: budget.subscriptionTotal,
      categoryBudgets: categoryBudgets,
    );

    return categoryBudgets;
  }

  // 테스트 결과 저장 메서드
  Future<String> saveTestResult({
    required String resultType,
    required int totalScore,
  }) async {
    final resultRef = _firestore
        .collection('users')
        .doc(_currentUserId)
        .collection('testResults')
        .doc();

    await resultRef.set({
      'testType': 'consumption_psychology',
      'resultType': resultType,
      'totalScore': totalScore,
      'recommendedProductIds': <String>[],
      'createdAt': FieldValue.serverTimestamp(),
    });

    return resultRef.id;
  }

  // 최신 소비심리 테스트 결과 조회 메서드
  Future<Map<String, dynamic>?> getLatestTestResult() async {
    final querySnapshot = await _firestore
        .collection('users')
        .doc(_currentUserId)
        .collection('testResults')
        .where(
      'testType',
      isEqualTo: 'consumption_psychology',
    )
        .orderBy(
      'createdAt',
      descending: true,
    )
        .limit(1)
        .get();

    if (querySnapshot.docs.isEmpty) {
      return null;
    }

    final document = querySnapshot.docs.first;

    return {
      'id': document.id,
      ...document.data(),
    };
  }
}