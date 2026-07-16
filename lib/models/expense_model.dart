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
  ///
  /// FirebaseAuth.instance.currentUser!.uid가 들어가야 한다.
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

  /// 할부 문서 ID
  final String? installmentId;

  /// 정기결제 문서 ID
  final String? recurringId;

  /// 지출 메모
  final String? memo;

  /// 퉁치기 간편 입력 여부
  final bool isQuickInput;

  /// 할부에서 자동 생성된 경우 원본 할부 계획 ID
  final String? installmentPlanId;

  /// 할부 회차
  final int? installmentInstallmentNo;

  /// 정기결제에서 자동 생성된 경우 원본 정기결제 ID
  final String? recurringPaymentId;

  /// 자동 생성 금액을 사용자가 수정했는지 여부
  final bool isAmountAdjusted;

  /// 여행 지출인 경우 여행 문서 ID
  final String? travelId;

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

    // ==================================================
    // ✅ 수정: 사용자 UID를 필수값으로 유지
    // ==================================================
    required this.userId,

    required this.amount,
    required this.date,
    required this.categoryId,
    required this.nature,
    this.emotionTag,
    this.installmentId,
    this.recurringId,
    this.memo,
    this.isQuickInput = false,
    this.installmentPlanId,
    this.installmentInstallmentNo,
    this.recurringPaymentId,
    this.isAmountAdjusted = false,
    this.travelId,
    this.isDeleted = false,
    this.deletedAt,
    this.createdAt,
    this.updatedAt,
  })  :

  // ==================================================
  // ✅ 수정: 빈 UID가 들어오는 경우 개발 중 즉시 확인
  // ==================================================
        assert(
        userId.trim().isNotEmpty,
        'ExpenseModel.userId에는 실제 Firebase UID가 필요합니다.',
        ),

  // ==================================================
  // ✅ 수정: 금액이 음수로 저장되지 않도록 확인
  // ==================================================
        assert(
        amount >= 0,
        '지출 금액은 0 이상이어야 합니다.',
        );

  /// Firestore 문서를 ExpenseModel로 변환
  factory ExpenseModel.fromFirestore(
      DocumentSnapshot doc,
      ) {
    final rawData = doc.data();

    final data = rawData is Map<String, dynamic>
        ? rawData
        : <String, dynamic>{};

    return ExpenseModel(
      expenseId: doc.id,

      // ==================================================
      // ✅ 수정: Firestore userId를 문자열로 안전하게 변환
      // ==================================================
      userId: data['userId']?.toString().trim() ?? '',

      amount: (data['amount'] as num?)?.toInt() ?? 0,

      date: data['date'] is Timestamp
          ? (data['date'] as Timestamp).toDate()
          : DateTime.now(),

      categoryId:
      data['categoryId']?.toString() ?? '',

      nature: ExpenseNature.fromCode(
        data['nature']?.toString(),
      ),

      emotionTag:
      data['emotionTag'] as String?,

      // ==================================================
      // ✅ 수정: 기존 선언만 되고 읽히지 않던 필드 추가
      // ==================================================
      installmentId:
      data['installmentId'] as String?,

      recurringId:
      data['recurringId'] as String?,

      memo: data['memo'] as String?,

      isQuickInput:
      data['isQuickInput'] == true,

      installmentPlanId:
      data['installmentPlanId'] as String?,

      installmentInstallmentNo:
      (data['installmentInstallmentNo'] as num?)
          ?.toInt(),

      recurringPaymentId:
      data['recurringPaymentId'] as String?,

      isAmountAdjusted:
      data['isAmountAdjusted'] == true,

      travelId:
      data['travelId'] as String?,

      isDeleted:
      data['isDeleted'] == true,

      deletedAt:
      _timestampToDateTime(data['deletedAt']),

      createdAt:
      _timestampToDateTime(data['createdAt']),

      updatedAt:
      _timestampToDateTime(data['updatedAt']),
    );
  }

  /// ExpenseModel을 Firestore 저장 형식으로 변환
  Map<String, dynamic> toFirestore() {
    return {
      // ==================================================
      // ✅ 수정 핵심:
      // 실제 로그인 UID를 expenses.userId 필드에 저장
      // 공백이 포함되지 않도록 trim 처리
      // ==================================================
      'userId': userId.trim(),

      'amount': amount,
      'date': Timestamp.fromDate(date),
      'categoryId': categoryId,
      'nature': nature.code,

      /// 변동비가 아닐 경우 감정 태그를 null로 저장
      'emotionTag':
      nature == ExpenseNature.variable
          ? emotionTag
          : null,

      'memo': memo,
      'isQuickInput': isQuickInput,

      // ==================================================
      // ✅ 수정: 기존 선언만 되고 저장되지 않던 필드 추가
      // ==================================================
      'installmentId': installmentId,
      'recurringId': recurringId,

      'installmentPlanId': installmentPlanId,
      'installmentInstallmentNo':
      installmentInstallmentNo,
      'recurringPaymentId': recurringPaymentId,
      'isAmountAdjusted': isAmountAdjusted,
      'travelId': travelId,
      'isDeleted': isDeleted,

      'deletedAt': deletedAt == null
          ? null
          : Timestamp.fromDate(deletedAt!),

      'createdAt': createdAt == null
          ? FieldValue.serverTimestamp()
          : Timestamp.fromDate(createdAt!),

      'updatedAt':
      FieldValue.serverTimestamp(),
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

    // ==================================================
    // ✅ 수정: 누락됐던 필드 copyWith에 추가
    // ==================================================
    String? installmentId,
    String? recurringId,

    String? memo,
    bool? isQuickInput,
    String? installmentPlanId,
    int? installmentInstallmentNo,
    String? recurringPaymentId,
    bool? isAmountAdjusted,
    String? travelId,
    bool? isDeleted,
    DateTime? deletedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ExpenseModel(
      expenseId:
      expenseId ?? this.expenseId,

      // ==================================================
      // ✅ 수정 핵심:
      // 사용자 UID를 복사하거나 새로운 UID로 변경 가능
      // ==================================================
      userId:
      userId ?? this.userId,

      amount:
      amount ?? this.amount,

      date:
      date ?? this.date,

      categoryId:
      categoryId ?? this.categoryId,

      nature:
      nature ?? this.nature,

      emotionTag:
      emotionTag ?? this.emotionTag,

      installmentId:
      installmentId ?? this.installmentId,

      recurringId:
      recurringId ?? this.recurringId,

      memo:
      memo ?? this.memo,

      isQuickInput:
      isQuickInput ?? this.isQuickInput,

      installmentPlanId:
      installmentPlanId ??
          this.installmentPlanId,

      installmentInstallmentNo:
      installmentInstallmentNo ??
          this.installmentInstallmentNo,

      recurringPaymentId:
      recurringPaymentId ??
          this.recurringPaymentId,

      isAmountAdjusted:
      isAmountAdjusted ??
          this.isAmountAdjusted,

      travelId:
      travelId ?? this.travelId,

      isDeleted:
      isDeleted ?? this.isDeleted,

      deletedAt:
      deletedAt ?? this.deletedAt,

      createdAt:
      createdAt ?? this.createdAt,

      updatedAt:
      updatedAt ?? this.updatedAt,
    );
  }

  /// Firestore Timestamp를 DateTime으로 안전하게 변환
  static DateTime? _timestampToDateTime(
      dynamic value,
      ) {
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