import 'package:cloud_firestore/cloud_firestore.dart';

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

/// 저축/투자 — 만기·중도해지·이자율은 관리하지 않고
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
      isDeleted: isDeleted ?? this.isDeleted,
      deletedAt: deletedAt ?? this.deletedAt,
      createdAt: createdAt,
      userId: userId ?? this.userId.trim(),
    );
  }
}