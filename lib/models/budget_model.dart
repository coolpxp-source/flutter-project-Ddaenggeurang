import 'package:cloud_firestore/cloud_firestore.dart';

class BudgetModel {
  // Firestore 문서 ID
  final String id;

  // 예산을 등록한 사용자 UID
  final String userId;

  // 예산 적용 월: 2026-07 형식
  final String month;

  // 한 달 전체 예산
  final int totalBudget;

  // 예산 시작일
  final int startDay;

  // 고정 지출 합계
  final int fixedExpenseTotal;

  // 구독료 합계
  final int subscriptionTotal;

  // 실제로 사용할 수 있는 예산
  final int availableBudget;

  // 카테고리별 예산
  final Map<String, int> categoryBudgets;

  // 최초 생성일
  final DateTime? createdAt;

  // 마지막 수정일
  final DateTime? updatedAt;

  const BudgetModel({
    required this.id,
    required this.userId,
    required this.month,
    required this.totalBudget,
    required this.startDay,
    required this.fixedExpenseTotal,
    required this.subscriptionTotal,
    required this.availableBudget,
    required this.categoryBudgets,
    this.createdAt,
    this.updatedAt,
  });

  /// Firestore 문서를 BudgetModel로 변환
  factory BudgetModel.fromDocument(
      DocumentSnapshot<Map<String, dynamic>> document,
      ) {
    final Map<String, dynamic> data = document.data() ?? {};

    final Map<String, dynamic> rawCategoryBudgets =
    Map<String, dynamic>.from(
      data['categoryBudgets'] as Map? ?? {},
    );

    final Map<String, int> convertedCategoryBudgets =
    rawCategoryBudgets.map(
          (key, value) {
        return MapEntry(
          key,
          (value as num?)?.toInt() ?? 0,
        );
      },
    );

    return BudgetModel(
      id: document.id,
      userId: data['userId'] as String? ?? '',
      month: data['month'] as String? ?? '',
      totalBudget: (data['totalBudget'] as num?)?.toInt() ?? 0,
      startDay: (data['startDay'] as num?)?.toInt() ?? 1,
      fixedExpenseTotal:
      (data['fixedExpenseTotal'] as num?)?.toInt() ?? 0,
      subscriptionTotal:
      (data['subscriptionTotal'] as num?)?.toInt() ?? 0,
      availableBudget:
      (data['availableBudget'] as num?)?.toInt() ?? 0,
      categoryBudgets: convertedCategoryBudgets,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  /// 예산 데이터를 Firestore 저장 형식으로 변환
  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'month': month,
      'totalBudget': totalBudget,
      'startDay': startDay,
      'fixedExpenseTotal': fixedExpenseTotal,
      'subscriptionTotal': subscriptionTotal,
      'availableBudget': availableBudget,
      'categoryBudgets': categoryBudgets,
    };
  }
}