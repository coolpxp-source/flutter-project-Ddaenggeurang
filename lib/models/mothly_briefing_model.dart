/// 월간 브리핑 화면에서 사용하는 데이터 모델
///
/// 한 달 동안의 예산, 총지출, 지출 성격별 금액,
/// 카테고리별 지출, 감정 태그별 지출 등의 정보를 담는다.
class MonthlyBriefingModel {
  /// 조회한 월
  ///
  /// 예:
  /// 2026-07
  final String monthKey;

  /// 해당 월에 설정한 전체 예산
  final int totalBudget;

  /// 해당 월의 총지출 금액
  final int totalSpent;

  /// 남은 예산
  ///
  /// 예산보다 많이 사용한 경우 음수가 될 수 있다.
  final int remainingBudget;

  /// 고정비 총금액
  final int fixedExpense;

  /// 변동비 총금액
  final int variableExpense;

  /// 기타 지출 총금액
  final int otherExpense;

  /// 예산 사용률
  ///
  /// 계산 예:
  /// 총지출 500,000원 / 예산 1,000,000원 × 100
  /// = 50%
  final double budgetUsageRate;

  /// 하루 평균 지출 금액
  final double dailyAverage;

  /// 가장 많이 지출한 카테고리 이름
  ///
  /// 지출 데이터가 없으면 null
  final String? topCategoryName;

  /// 가장 많이 지출한 카테고리의 금액
  final int topCategoryAmount;

  /// 가장 많은 지출이 발생한 감정 태그
  ///
  /// 감정 태그 데이터가 없으면 null
  final String? topEmotionName;

  /// 가장 많이 지출한 감정 태그의 금액
  final int topEmotionAmount;

  /// 해당 월의 전체 지출 건수
  final int expenseCount;

  /// 카테고리별 지출 금액
  ///
  /// 예:
  /// {
  ///   '식비': 300000,
  ///   '교통비': 100000,
  ///   '쇼핑': 150000,
  /// }
  final Map<String, int> categoryAmounts;

  /// 감정 태그별 지출 금액
  ///
  /// 예:
  /// {
  ///   '충동적': 100000,
  ///   '스트레스': 80000,
  ///   '계획적': 200000,
  /// }
  final Map<String, int> emotionAmounts;

  const MonthlyBriefingModel({
    required this.monthKey,
    required this.totalBudget,
    required this.totalSpent,
    required this.remainingBudget,
    required this.fixedExpense,
    required this.variableExpense,
    required this.otherExpense,
    required this.budgetUsageRate,
    required this.dailyAverage,
    required this.topCategoryName,
    required this.topCategoryAmount,
    required this.topEmotionName,
    required this.topEmotionAmount,
    required this.expenseCount,
    required this.categoryAmounts,
    required this.emotionAmounts,
  });

  /// 예산 초과 여부
  ///
  /// 예산이 설정되어 있고,
  /// 총지출이 예산보다 크면 true를 반환한다.
  bool get isOverBudget {
    return totalBudget > 0 &&
        totalSpent > totalBudget;
  }

  /// 예산 초과 금액
  ///
  /// 예산을 초과하지 않았으면 0을 반환한다.
  int get overBudgetAmount {
    if (!isOverBudget) {
      return 0;
    }

    return totalSpent - totalBudget;
  }

  /// 현재 소비 상태에 따른 브리핑 메시지
  String get briefingMessage {
    /// 등록된 지출이 없는 경우
    if (totalSpent == 0) {
      return '이번 달에는 아직 등록된 지출이 없습니다.';
    }

    /// 예산이 설정되지 않은 경우
    if (totalBudget <= 0) {
      return '이번 달 예산이 설정되지 않았습니다.';
    }

    /// 예산을 초과한 경우
    if (budgetUsageRate >= 100) {
      return '예산을 초과했습니다. 남은 기간에는 지출을 줄여보세요.';
    }

    /// 예산의 80% 이상 사용한 경우
    if (budgetUsageRate >= 80) {
      return '예산의 80% 이상을 사용했습니다. 지출 관리가 필요합니다.';
    }

    /// 예산의 50% 이상 사용한 경우
    if (budgetUsageRate >= 50) {
      return '예산의 절반 이상을 사용했습니다.';
    }

    /// 예산의 50% 미만을 사용한 경우
    return '현재까지 예산을 안정적으로 관리하고 있습니다.';
  }
}