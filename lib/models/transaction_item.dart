// 지출내역 확인용 입니다
/// 저축(투자) 항목의 증권사/종목/수량 — SavingModel.InvestmentDetail을 화면단에서
/// 그대로 쓰기보다, TransactionItem은 Firestore 의존성 없이 가볍게 유지하기 위해
/// 별도의 경량 클래스로 둡니다.
class TransactionInvestmentDetail {
  final String brokerage; // 증권사명 (예: "토스증권")
  final String assetName; // 종목명 (예: "S&P500 ETF")
  final num? quantity;    // 매수 수량 (선택)

  const TransactionInvestmentDetail({
    required this.brokerage,
    required this.assetName,
    this.quantity,
  });
}

class TransactionItem {
  final String id;
  final String type; // 'income', 'expense', 'saving'
  final DateTime date;
  final int amount;
  final String title;       // 지출: 카테고리 한글명, 수입: 출처 한글 라벨, 저축: 소분류명
  final String? subtitle;   // 메모
  final String? emotionTag; // 지출인 경우만 존재 ('stress', 'impulsive' 등)
  final String? accountName; // 저축인 경우만 존재 (예: '국민은행 청년희망적금')
  final String? savingStatus; // 저축 상태 확인용 변수 (active, matured, cancelled, sold)

  // ── 입력 화면에서 받는데 기존에는 화면에 표시되지 않던 정보들 ──
  final String? parentCategory; // 대분류명 (예: "식비" > 소분류 "카페/디저트")
  final String? nature;         // 지출 성격 코드: fixed(고정비) / variable(변동비) / other(기타) — 지출만 해당
  final bool isInstallment;     // 할부 결제 진행 중인지 — 지출만 해당
  final int? installmentTotalMonths; // 할부 총 개월수 — 지출만 해당 (isInstallment일 때만 의미 있음)
  final bool isRecurring;       // 정기결제(지출) / 정기수입(수입) / 반복저축(저축) 여부
  final int? recurringPayDay;   // 정기수입일 때 매달 입금일 — 수입만 해당
  final String? recurringPaymentId; // 연결된 구독(subscriptions 컬렉션) 문서 ID — 지출만 해당.
  // isRecurring만으로는 "연결되어 있었다"는 것만 알 수 있고 지금 그 구독이
  // 활성 상태인지는 알 수 없어서, 상세 화면에서 실시간으로 조회하는 데 씀.
  final TransactionInvestmentDetail? investmentDetail; // 투자 상세 — 저축만 해당
  final int? returnedAmount;    // 만기/해지/매도 시 최종 환급 금액 — 저축만 해당
  final String? categoryId;
  final bool categoryDeleted; // 카테고리 문서가 삭제되어 매칭 실패했는지 여부

  TransactionItem({
    required this.id,
    required this.type,
    required this.date,
    required this.amount,
    required this.title,
    this.subtitle,
    this.emotionTag,
    this.accountName,
    this.savingStatus,
    this.parentCategory,
    this.nature,
    this.isInstallment = false,
    this.installmentTotalMonths,
    this.isRecurring = false,
    this.recurringPayDay,
    this.recurringPaymentId,
    this.investmentDetail,
    this.returnedAmount,
    this.categoryId,
    this.categoryDeleted = false,
  });
}