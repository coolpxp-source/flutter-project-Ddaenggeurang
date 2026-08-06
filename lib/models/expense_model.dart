import 'package:cloud_firestore/cloud_firestore.dart';

/// 지출의 성격 — 카테고리 선택 시 자동으로 결정됨
/// variable(변동비)일 때만 감정태그가 활성화됨
enum ExpenseNature {
  fixed('fixed', '고정비'),
  variable('variable', '변동비'),
  other('other', '기타');

  final String code;
  final String label;

  const ExpenseNature(
      this.code,
      this.label,
      );

  static ExpenseNature fromCode(String? code) {
    return ExpenseNature.values.firstWhere(
          (nature) => nature.code == code,
      orElse: () => ExpenseNature.other,
    );
  }
}

class ExpenseModel {
  /// Firestore expenses 문서 ID
  final String expenseId;

  /// 지출을 등록한 Firebase 사용자 UID
  final String userId;

  /// 지출 금액
  final int amount;

  /// 지출 날짜
  final DateTime date;

  /// 카테고리 문서 ID
  final String categoryId;

  /// 고정비·변동비·기타
  final ExpenseNature nature;

  /// 변동비일 때만 사용할 수 있는 감정 태그
  final String? emotionTag;

  /// 지출 메모
  final String? memo;

  /// 퉁치기 간편 입력 여부
  final bool isQuickInput;

  /// 할부에서 자동 생성된 경우 원본 할부 계획 ID
  final String? installmentPlanId;

  /// 할부 회차
  final int? installmentInstallmentNo;

  /// 할부 총 개월수 (예: 3개월 할부 → 3)
  final int? installmentTotalMonths;

  /// 정기결제에서 자동 생성된 경우 원본 정기결제 ID
  final String? recurringPaymentId;

  /// 한 번이라도 정기결제로 연결된 적 있다면 계속 보존되는 ID.
  /// (recurringPaymentId는 껐다 켰다에 따라 null이 되지만, 이건 남아서
  /// "되살리기"를 할 때 어떤 문서를 되살릴지 찾는 용도로 쓴다)
  final String? lastRecurringPaymentId;

  /// 자동 생성 금액을 사용자가 수정했는지 여부
  final bool isAmountAdjusted;

  /// 소프트 삭제 여부
  final bool isDeleted;

  /// 삭제 시간
  final DateTime? deletedAt;

  /// 생성 시간
  final DateTime? createdAt;

  /// 수정 시간
  final DateTime? updatedAt;

  ExpenseModel({
    required this.expenseId,
    required this.userId,
    required this.amount,
    required this.date,
    required this.categoryId,
    required this.nature,
    this.emotionTag,
    this.memo,
    this.isQuickInput = false,
    this.installmentPlanId,
    this.installmentInstallmentNo,
    this.installmentTotalMonths,
    this.recurringPaymentId,
    this.lastRecurringPaymentId,
    this.isAmountAdjusted = false,
    this.isDeleted = false,
    this.deletedAt,
    this.createdAt,
    this.updatedAt,
  })  : assert(
  userId.trim().isNotEmpty,
  'ExpenseModel.userId에는 실제 Firebase UID가 필요합니다.',
  ),
        assert(
        amount >= 0,
        '지출 금액은 0 이상이어야 합니다.',
        );

  /// Firestore 문서를 ExpenseModel로 변환
  factory ExpenseModel.fromFirestore(DocumentSnapshot doc) {
    final rawData = doc.data();
    final data = rawData is Map<String, dynamic> ? rawData : <String, dynamic>{};

    return ExpenseModel(
      expenseId: doc.id,
      userId: data['userId']?.toString().trim() ?? '',
      amount: (data['amount'] as num?)?.toInt() ?? 0,
      date: data['date'] is Timestamp
          ? (data['date'] as Timestamp).toDate()
          : DateTime.now(),
      categoryId: data['categoryId']?.toString() ?? '',
      nature: ExpenseNature.fromCode(data['nature']?.toString()),
      emotionTag: data['emotionTag'] as String?,
      memo: data['memo'] as String?,
      isQuickInput: data['isQuickInput'] == true,
      installmentPlanId: data['installmentPlanId'] as String?,
      installmentInstallmentNo: (data['installmentInstallmentNo'] as num?)?.toInt(),
      installmentTotalMonths: (data['installmentTotalMonths'] as num?)?.toInt(),
      recurringPaymentId: data['recurringPaymentId'] as String?,
      lastRecurringPaymentId: data['lastRecurringPaymentId'] as String?,
      isAmountAdjusted: data['isAmountAdjusted'] == true,
      isDeleted: data['isDeleted'] == true,
      deletedAt: _timestampToDateTime(data['deletedAt']),
      createdAt: _timestampToDateTime(data['createdAt']),
      updatedAt: _timestampToDateTime(data['updatedAt']),
    );
  }

  /// ExpenseModel을 Firestore 저장 형식으로 변환
  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId.trim(),
      'amount': amount,
      'date': Timestamp.fromDate(date),
      'categoryId': categoryId,
      'nature': nature.code,
      'emotionTag': nature == ExpenseNature.variable ? emotionTag : null,
      'memo': memo,
      'isQuickInput': isQuickInput,
      'installmentPlanId': installmentPlanId,
      'installmentInstallmentNo': installmentInstallmentNo,
      'installmentTotalMonths': installmentTotalMonths,
      'recurringPaymentId': recurringPaymentId,
      'lastRecurringPaymentId': lastRecurringPaymentId,
      'isAmountAdjusted': isAmountAdjusted,
      'isDeleted': isDeleted,
      'deletedAt': deletedAt == null ? null : Timestamp.fromDate(deletedAt!),
      'createdAt': createdAt == null
          ? FieldValue.serverTimestamp()
          : Timestamp.fromDate(createdAt!),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  ExpenseModel copyWith({
    String? expenseId,
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
    int? installmentTotalMonths,
    String? recurringPaymentId,
    String? lastRecurringPaymentId,
    bool? isAmountAdjusted,
    bool? isDeleted,
    DateTime? deletedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ExpenseModel(
      expenseId: expenseId ?? this.expenseId,
      userId: userId ?? this.userId,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      categoryId: categoryId ?? this.categoryId,
      nature: nature ?? this.nature,
      emotionTag: emotionTag ?? this.emotionTag,
      memo: memo ?? this.memo,
      isQuickInput: isQuickInput ?? this.isQuickInput,
      installmentPlanId: installmentPlanId ?? this.installmentPlanId,
      installmentInstallmentNo: installmentInstallmentNo ?? this.installmentInstallmentNo,
      installmentTotalMonths: installmentTotalMonths ?? this.installmentTotalMonths,
      recurringPaymentId: recurringPaymentId ?? this.recurringPaymentId,
      lastRecurringPaymentId: lastRecurringPaymentId ?? this.lastRecurringPaymentId,
      isAmountAdjusted: isAmountAdjusted ?? this.isAmountAdjusted,
      isDeleted: isDeleted ?? this.isDeleted,
      deletedAt: deletedAt ?? this.deletedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Firestore Timestamp를 DateTime으로 안전하게 변환
  static DateTime? _timestampToDateTime(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is DateTime) {
      return value;
    }
    if (value is String) {
      return DateTime.tryParse(value);
    }
    return null;
  }
}