import 'package:cloud_firestore/cloud_firestore.dart';

// 저축은 수정할때 상태를 전환 시키도록 함
enum SavingStatus {
  active('active', '진행중'),      // 현재 유지 중 (기본값)
  matured('matured', '만기됨'),     // 적금/예금 만기
  cancelled('cancelled', '해지함'), // 중도 해지
  sold('sold', '매도완료');         // 주식/ETF 등 매도

  final String code;
  final String label;
  const SavingStatus(this.code, this.label);

  static SavingStatus fromCode(String? code) => SavingStatus.values.firstWhere(
        (e) => e.code == code,
    orElse: () => SavingStatus.active,
  );
}

/// 투자(주식/ETF 등) 카테고리를 선택했을 때만 채우는 선택 정보
class InvestmentDetail {
  final String brokerage; // 증권사명 (예: "토스증권", "미래에셋")
  final String assetName; // 종목명 (예: "S&P500 ETF")
  final num? quantity; // 매수 수량 (선택, 소수 매수 가능성 있어 num 유지)

  InvestmentDetail({
    required this.brokerage,
    required this.assetName,
    this.quantity,
  });

  factory InvestmentDetail.fromMap(Map<String, dynamic>? m) {
    if (m == null) {
      throw ArgumentError('InvestmentDetail map is null');
    }
    return InvestmentDetail(
      brokerage: m['brokerage'] ?? '',
      assetName: m['assetName'] ?? '',
      quantity: m['quantity'] as num?,
    );
  }

  Map<String, dynamic> toMap() => {
    'brokerage': brokerage,
    'assetName': assetName,
    'quantity': quantity,
  };

  InvestmentDetail copyWith({
    String? brokerage,
    String? assetName,
    num? quantity,
  }) {
    return InvestmentDetail(
      brokerage: brokerage ?? this.brokerage,
      assetName: assetName ?? this.assetName,
      quantity: quantity ?? this.quantity,
    );
  }
}

/// "언제, 어떤 항목에, 얼마 넣었는지"만 기록
class SavingModel {
  final String savingId;
  final String userId;
  final DateTime date;
  final String categoryId; // 청약/적금/예금/파킹통장/투자 등 소분류
  final String? accountName; // 계좌명 (예: "국민은행 청년희망적금")
  final int amount; // 원 단위 정수
  final String? memo;
  /// 카테고리가 투자 계열일 때만 값 있음
  final InvestmentDetail? investmentDetail;

  /// 매달 반복되는 적립/투자인지 여부 (예: 매달 자동이체 적금, 정기 매수)
  final bool isRecurring;

  // 상태 관리 필드 2개
  final SavingStatus status;
  final int? returnedAmount; // 만기/해지/매도 시 돌려받은 최종 금액 (이익/손실 포함)

  final bool isDeleted;
  final DateTime? deletedAt;
  final DateTime? createdAt;

  SavingModel({
    required this.savingId,
    required this.userId,
    required this.date,
    required this.categoryId,
    this.accountName,
    required this.amount,
    this.memo,
    this.investmentDetail,
    this.isRecurring = false,
    // 저축 상태 기본값은 '진행중(active)'으로 설정
    this.status = SavingStatus.active,
    this.returnedAmount,
    this.isDeleted = false,
    this.deletedAt,
    this.createdAt,
  });

  factory SavingModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return SavingModel(
      savingId: doc.id,
      userId: d['userId'] ?? '',
      date: (d['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      categoryId: d['categoryId'] ?? '',
      accountName: d['accountName'] as String?,
      amount: (d['amount'] as num?)?.toInt() ?? 0,
      memo: d['memo'] as String?,
      investmentDetail: d['investmentDetail'] != null
          ? InvestmentDetail.fromMap(
          Map<String, dynamic>.from(d['investmentDetail']))
          : null,
      isRecurring: d['isRecurring'] ?? false,
      // 저축 상태와 최종 금액 불러오기
      status: SavingStatus.fromCode(d['status']),
      returnedAmount: (d['returnedAmount'] as num?)?.toInt(),
      isDeleted: d['isDeleted'] ?? false,
      deletedAt: (d['deletedAt'] as Timestamp?)?.toDate(),
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'userId': userId.trim(),
    'date': Timestamp.fromDate(date),
    'categoryId': categoryId,
    'accountName': accountName,
    'amount': amount,
    'memo': memo,
    'investmentDetail': investmentDetail?.toMap(),
    'isRecurring': isRecurring,
    // 저축 상태와 최종 금액 저장하기
    'status': status.code,
    'returnedAmount': returnedAmount,
    'isDeleted': isDeleted,
    'deletedAt': deletedAt != null ? Timestamp.fromDate(deletedAt!) : null,
    'createdAt': createdAt != null
        ? Timestamp.fromDate(createdAt!)
        : FieldValue.serverTimestamp(),
  };

  SavingModel copyWith({
    String? userId,
    DateTime? date,
    String? categoryId,
    String? accountName,
    int? amount,
    String? memo,
    InvestmentDetail? investmentDetail,
    bool? isRecurring,
    SavingStatus? status,
    int? returnedAmount,
    bool? isDeleted,
    DateTime? deletedAt,
  }) {
    return SavingModel(
      savingId: savingId,
      date: date ?? this.date,
      categoryId: categoryId ?? this.categoryId,
      accountName: accountName ?? this.accountName,
      amount: amount ?? this.amount,
      memo: memo ?? this.memo,
      investmentDetail: investmentDetail ?? this.investmentDetail,
      isRecurring: isRecurring ?? this.isRecurring,
      status: status ?? this.status,
      returnedAmount: returnedAmount ?? this.returnedAmount,
      isDeleted: isDeleted ?? this.isDeleted,
      deletedAt: deletedAt ?? this.deletedAt,
      createdAt: createdAt,
      userId: userId ?? this.userId.trim(),
    );
  }
}