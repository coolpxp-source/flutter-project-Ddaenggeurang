class BudgetVsExpenseModel {
  final int totalBudget;
  final int totalSpent;

  const BudgetVsExpenseModel({
    required this.totalBudget,
    required this.totalSpent,
  });

  /// 남은 예산
  int get remainingAmount => totalBudget - totalSpent;

  /// 예산 사용률
  double get usageRate {
    if (totalBudget <= 0) {
      return 0;
    }

    return totalSpent / totalBudget;
  }

  /// 화면의 ProgressIndicator에 사용할 값
  /// 100%를 초과해도 최대 1.0까지만 반환
  double get progressValue {
    return usageRate.clamp(0.0, 1.0);
  }

  /// 예산 초과 여부
  bool get isOverBudget => totalSpent > totalBudget;

  /// 초과 금액
  int get overAmount {
    if (!isOverBudget) {
      return 0;
    }

    return totalSpent - totalBudget;
  }
}