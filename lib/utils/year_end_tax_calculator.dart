/// 연말정산 신용/체크카드 소득공제 간이 계산기.
/// YearEndSimulationScreen(계산) / YearEndSimulationListScreen(리포트)
/// 양쪽에서 공유해서 공식이 어긋나지 않도록 한다.
class YearEndTaxResult {
  final int threshold;        // 공제 문턱 (총급여 25%)
  final int totalUsage;       // 신용+체크 총 사용액
  final int overThreshold;    // 문턱 초과분
  final int creditDeduction;  // 신용카드 공제액 (한도 반영 후)
  final int debitDeduction;   // 체크카드 공제액 (한도 반영 후)
  final int estimatedDeduction; // 최종 예상 공제액 (한도 반영 후 합계)
  final int limit;            // 적용된 한도
  final bool isCapped;        // 한도에 걸려 축소됐는지 여부

  const YearEndTaxResult({
    required this.threshold,
    required this.totalUsage,
    required this.overThreshold,
    required this.creditDeduction,
    required this.debitDeduction,
    required this.estimatedDeduction,
    required this.limit,
    required this.isCapped,
  });

  bool get isEligible => overThreshold > 0;
}

class YearEndTaxCalculator {
  const YearEndTaxCalculator._();

  static int deductionLimitFor(int salary) {
    if (salary <= 70000000) return 3000000;
    if (salary <= 120000000) return 2500000;
    return 2000000;
  }

  static YearEndTaxResult calculate({
    required int salary,
    required int credit,
    required int debit,
  }) {
    final totalUsage = credit + debit;
    final threshold = (salary * 0.25).round();
    final limit = deductionLimitFor(salary);

    if (salary <= 0 || totalUsage <= 0) {
      return YearEndTaxResult(
        threshold: threshold,
        totalUsage: totalUsage,
        overThreshold: 0,
        creditDeduction: 0,
        debitDeduction: 0,
        estimatedDeduction: 0,
        limit: limit,
        isCapped: false,
      );
    }

    final overThreshold = totalUsage > threshold ? totalUsage - threshold : 0;

    if (overThreshold <= 0) {
      return YearEndTaxResult(
        threshold: threshold,
        totalUsage: totalUsage,
        overThreshold: 0,
        creditDeduction: 0,
        debitDeduction: 0,
        estimatedDeduction: 0,
        limit: limit,
        isCapped: false,
      );
    }

    final creditRatio = credit / totalUsage;
    final debitRatio = debit / totalUsage;

    var creditDeduction = (overThreshold * creditRatio * 0.15).round();
    var debitDeduction = (overThreshold * debitRatio * 0.30).round();
    final rawTotal = creditDeduction + debitDeduction;

    var isCapped = false;
    var estimatedDeduction = rawTotal;

    if (rawTotal > limit) {
      isCapped = true;
      estimatedDeduction = limit;
      if (rawTotal > 0) {
        final scale = limit / rawTotal;
        creditDeduction = (creditDeduction * scale).round();
        debitDeduction = (debitDeduction * scale).round();
      }
    }

    return YearEndTaxResult(
      threshold: threshold,
      totalUsage: totalUsage,
      overThreshold: overThreshold,
      creditDeduction: creditDeduction,
      debitDeduction: debitDeduction,
      estimatedDeduction: estimatedDeduction,
      limit: limit,
      isCapped: isCapped,
    );
  }
}