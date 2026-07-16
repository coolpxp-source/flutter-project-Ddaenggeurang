/// 카테고리 한 개의 예산 대비 지출 데이터
class CategoryBudgetVsExpenseModel {
  /// 카테고리 키
  ///
  /// 예: food, transport, shopping
  final String categoryKey;

  /// 화면에 표시할 카테고리 이름
  ///
  /// 예: 식비, 교통비, 쇼핑
  final String categoryName;

  /// 카테고리별 설정 예산
  final int budgetAmount;

  /// 카테고리별 실제 지출
  final int spentAmount;

  const CategoryBudgetVsExpenseModel({
    required this.categoryKey,
    required this.categoryName,
    required this.budgetAmount,
    required this.spentAmount,
  });

  /// 카테고리별 남은 예산
  int get remainingAmount {
    return budgetAmount - spentAmount;
  }

  /// 카테고리별 예산 사용률
  double get usageRate {
    if (budgetAmount <= 0) {
      return 0.0;
    }

    return spentAmount / budgetAmount;
  }

  /// 진행 막대에 사용할 값
  ///
  /// 100%를 초과하더라도 진행 막대는 최대 1.0까지만 표시
  double get progressValue {
    return usageRate.clamp(0.0, 1.0).toDouble();
  }

  /// 카테고리 예산 초과 여부
  bool get isOverBudget {
    return spentAmount > budgetAmount;
  }

  /// 카테고리 예산 초과 금액
  int get overAmount {
    if (!isOverBudget) {
      return 0;
    }

    return spentAmount - budgetAmount;
  }
}

/// 전체 예산 대비 지출 화면에서 사용하는 모델
class BudgetVsExpenseModel {
  /// 해당 월 전체 예산
  final int totalBudget;

  /// 해당 월 전체 지출
  final int totalSpent;

  /// 카테고리별 예산 대비 지출 목록
  final List<CategoryBudgetVsExpenseModel> categories;

  const BudgetVsExpenseModel({
    required this.totalBudget,
    required this.totalSpent,
    this.categories = const [],
  });

  /// 전체 남은 예산
  int get remainingAmount {
    return totalBudget - totalSpent;
  }

  /// 전체 예산 사용률
  double get usageRate {
    if (totalBudget <= 0) {
      return 0.0;
    }

    return totalSpent / totalBudget;
  }

  /// 전체 진행 막대에 사용할 값
  double get progressValue {
    return usageRate.clamp(0.0, 1.0).toDouble();
  }

  /// 전체 예산 초과 여부
  bool get isOverBudget {
    return totalSpent > totalBudget;
  }

  /// 전체 예산 초과 금액
  int get overAmount {
    if (!isOverBudget) {
      return 0;
    }

    return totalSpent - totalBudget;
  }
}