/// 영수증/문자 텍스트에서 적립 또는 사용된 포인트를 감지하는 유틸리티 모델 및 함수

class DetectedPoint {
  final int amount;
  final String type; // 'earn' (적립) 또는 'spend' (사용)

  DetectedPoint({
    required this.amount,
    required this.type,
  });

  @override
  String toString() {
    return 'DetectedPoint(amount: $amount, type: $type)';
  }
}

/// 원본 텍스트(영수증 OCR 결과, 문자 내용 등)를 분석하여 포인트 내역을 추출합니다.
List<DetectedPoint> detectPoints(String text) {
  final List<DetectedPoint> points = [];

  // 텍스트를 다루기 쉽게 줄바꿈으로 나누어 분석 (한 줄에 하나씩 처리)
  final lines = text.split('\n');

  // 1. 적립 포인트 정규식
  // 매칭 예: 우수고객포인트: 40, 멤버십 적립 100, 적립포인트 50
  final earnRegex = RegExp(r'(우수고객포인트|적립\s*포인트|멤버십\s*적립|발생\s*포인트|금번\s*포인트|포인트\s*적립)[\s:]*([0-9,]+)', caseSensitive: false);
  // 매칭 예: 40 포인트 적립, 100p 적립
  final earnRegexSuffix = RegExp(r'([0-9,]+)\s*(?:점|P|p|포인트)?\s*적립', caseSensitive: false);

  // 2. 사용 포인트 정규식
  // 매칭 예: 포인트 사용: 500, 차감포인트 1000, 포인트결제 1500
  final spendRegex = RegExp(r'(사용\s*포인트|포인트\s*사용|포인트\s*결제|포인트\s*차감|차감\s*포인트)[\s:]*([0-9,]+)', caseSensitive: false);
  // 매칭 예: 500 포인트 차감, 1000p 결제
  final spendRegexSuffix = RegExp(r'([0-9,]+)\s*(?:점|P|p|포인트)?\s*(사용|차감|결제)', caseSensitive: false);

  for (final line in lines) {
    // 잔여포인트, 누적포인트, 사용가능포인트 등은 이번 거래액이 아니므로 완전히 무시
    if (line.contains('잔여') || line.contains('누적') || line.contains('사용가능') || line.contains('총포인트')) {
      continue;
    }

    // --- 적립 매칭 ---
    for (final match in earnRegex.allMatches(line)) {
      final amountStr = match.group(2)?.replaceAll(',', '') ?? '';
      final amount = int.tryParse(amountStr);
      if (amount != null && amount > 0) points.add(DetectedPoint(amount: amount, type: 'earn'));
    }
    for (final match in earnRegexSuffix.allMatches(line)) {
      final amountStr = match.group(1)?.replaceAll(',', '') ?? '';
      final amount = int.tryParse(amountStr);
      if (amount != null && amount > 0) points.add(DetectedPoint(amount: amount, type: 'earn'));
    }

    // --- 사용 매칭 ---
    for (final match in spendRegex.allMatches(line)) {
      final amountStr = match.group(2)?.replaceAll(',', '') ?? '';
      final amount = int.tryParse(amountStr);
      if (amount != null && amount > 0) points.add(DetectedPoint(amount: amount, type: 'spend'));
    }
    for (final match in spendRegexSuffix.allMatches(line)) {
      final amountStr = match.group(1)?.replaceAll(',', '') ?? '';
      final amount = int.tryParse(amountStr);
      if (amount != null && amount > 0) points.add(DetectedPoint(amount: amount, type: 'spend'));
    }
  }

  // 중복 감지 방지를 위해 Set으로 걸러서 반환 (같은 금액/타입이 여러 번 잡히는 것 방지)
  final uniquePoints = <String, DetectedPoint>{};
  for (final p in points) {
    uniquePoints['${p.type}_${p.amount}'] = p;
  }

  return uniquePoints.values.toList();
}