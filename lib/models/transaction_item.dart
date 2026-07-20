// 지출내역 확인용 입니다

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

  TransactionItem({
    required this.id,
    required this.type,
    required this.date,
    required this.amount,
    required this.title,
    this.subtitle,
    this.emotionTag,
    this.accountName,
    this.savingStatus
  });
}