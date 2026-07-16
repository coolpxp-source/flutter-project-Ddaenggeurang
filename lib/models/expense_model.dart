import 'package:cloud_firestore/cloud_firestore.dart';

/// 지출의 성격 — 카테고리 선택 시 자동으로 결정됨
/// variable(변동비)일 때만 감정태그가 활성화됨
enum ExpenseNature {
  fixed('fixed', '고정비'),
  variable('variable', '변동비'),
  other('other', '기타');

  final String code;
  final String label;
  const ExpenseNature(this.code, this.label);

  static ExpenseNature fromCode(String? code) => ExpenseNature.values.firstWhere(
        (e) => e.code == code,
    orElse: () => ExpenseNature.other,
  );
}

class ExpenseModel {
  final String expenseId;
  final String userId;
  final int amount; // 원 단위 정수
  final DateTime date;
  final String categoryId;
  final ExpenseNature nature;

  /// nature == variable 일 때만 값이 있을 수 있음 (fixed/other면 항상 null)
  /// EmotionTag는 컬렉션이 아니라 enum이라 Id 접미사를 붙이지 않음
  final String? emotionTag;

  final String? installmentId; // 할부 문서 ID
  final String? recurringId;   // 정기결제(구독) 문서 ID

  final String? memo;

  /// '퉁치기' 간편 입력 모드로 등록됐는지 여부
  final bool isQuickInput;

  /// 할부에서 자동 생성된 지출이면 원거래(installmentPlans 컬렉션) 참조
  final String? installmentPlanId;

  /// 할부 몇 회차인지 (installmentPlanId가 있을 때만 값 있음)
  final int? installmentInstallmentNo;

  /// 구독/보험료/정기후원(recurringPayments 컬렉션)에서 자동 생성된 지출이면 참조
  final String? recurringPaymentId;

  /// 할부·구독 자동생성 금액과 실제 결제금액이 달라서 사용자가 수정했는지 여부
  final bool isAmountAdjusted;

  /// 여행 기간에 속해 자동 태깅된 경우 참조 (고정비·구독·할부 지출은 태깅 대상에서 제외)
  final String? travelId;

  final bool isDeleted;
  final DateTime? deletedAt;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  ExpenseModel({
    required this.expenseId,
    required this.userId,
    required this.amount,
    required this.date,
    required this.categoryId,
    required this.nature,
    this.emotionTag,
    this.installmentId,
    this.recurringId,
    this.travelId,
    this.memo,
    this.isQuickInput = false,
    this.installmentPlanId,
    this.installmentInstallmentNo,
    this.recurringPaymentId,
    this.isAmountAdjusted = false,
    this.isDeleted = false,
    this.deletedAt,
    this.createdAt,
    this.updatedAt,
  });

  factory ExpenseModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return ExpenseModel(
      expenseId: doc.id,
      userId: d['userId'] ?? '',
      amount: (d['amount'] as num?)?.toInt() ?? 0,
      date: (d['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      categoryId: d['categoryId'] ?? '',
      nature: ExpenseNature.fromCode(d['nature']),
      emotionTag: d['emotionTag'] as String?,
      memo: d['memo'] as String?,
      isQuickInput: d['isQuickInput'] ?? false,
      installmentPlanId: d['installmentPlanId'] as String?,
      installmentInstallmentNo: (d['installmentInstallmentNo'] as num?)?.toInt(),
      recurringPaymentId: d['recurringPaymentId'] as String?,
      isAmountAdjusted: d['isAmountAdjusted'] ?? false,
      travelId: d['travelId'] as String?,
      isDeleted: d['isDeleted'] ?? false,
      deletedAt: (d['deletedAt'] as Timestamp?)?.toDate(),
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (d['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'userId': userId,
    'amount': amount,
    'date': Timestamp.fromDate(date),
    'categoryId': categoryId,
    'nature': nature.code,
    'emotionTag': emotionTag,
    'memo': memo,
    'isQuickInput': isQuickInput,
    'installmentPlanId': installmentPlanId,
    'installmentInstallmentNo': installmentInstallmentNo,
    'recurringPaymentId': recurringPaymentId,
    'isAmountAdjusted': isAmountAdjusted,
    'travelId': travelId,
    'isDeleted': isDeleted,
    'deletedAt': deletedAt != null ? Timestamp.fromDate(deletedAt!) : null,
    'createdAt': createdAt != null
        ? Timestamp.fromDate(createdAt!)
        : FieldValue.serverTimestamp(),
    'updatedAt': FieldValue.serverTimestamp(),
  };

  ExpenseModel copyWith({
    String? userId,
    int? amount,
    DateTime? date,
    String? categoryId,
    ExpenseNature? nature,
    String? emotionTag,
    String? memo,
    bool? isQuickInput,
    String? installmentPlanId,
    int? installmentInstallmentNo,
    String? recurringPaymentId,
    bool? isAmountAdjusted,
    String? travelId,
    bool? isDeleted,
    DateTime? deletedAt,
  }) {
    return ExpenseModel(
      expenseId: expenseId,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      categoryId: categoryId ?? this.categoryId,
      nature: nature ?? this.nature,
      emotionTag: emotionTag ?? this.emotionTag,
      memo: memo ?? this.memo,
      isQuickInput: isQuickInput ?? this.isQuickInput,
      installmentPlanId: installmentPlanId ?? this.installmentPlanId,
      installmentInstallmentNo: installmentInstallmentNo ?? this.installmentInstallmentNo,
      recurringPaymentId: recurringPaymentId ?? this.recurringPaymentId,
      isAmountAdjusted: isAmountAdjusted ?? this.isAmountAdjusted,
      travelId: travelId ?? this.travelId,
      isDeleted: isDeleted ?? this.isDeleted,
      deletedAt: deletedAt ?? this.deletedAt,
      createdAt: createdAt,
      updatedAt: updatedAt,
      userId: userId ?? this.userId
    );
  }
}