import 'package:cloud_firestore/cloud_firestore.dart';

/// 수입 출처 (Firestore 저장값은 snake_case)
enum IncomeSource {
  salary('salary', '정기급여'),
  freelanceIncome('freelance_income', '프리랜서'),
  partTime('part_time', '단기알바'),
  allowance('allowance', '용돈'),
  etc('etc', '기타 수입');

  final String code;
  final String label;
  const IncomeSource(this.code, this.label);

  // 사라진 수입출처목록은 기타수입으로 묶어서 보내줌
  static IncomeSource fromCode(String? code) => IncomeSource.values.firstWhere(
        (e) => e.code == code,
    orElse: () => IncomeSource.etc,
  );
}

class IncomeModel {
  final String incomeId;
  final String userId;
  final int amount; // 실수령액(세후) 필수 입력, 원 단위 정수
  final IncomeSource incomeSource;
  final DateTime date;
  final String? memo;

  /// 반복등록(recurringIncomeTemplates 컬렉션)에서 자동 생성된 수입이면 참조, 수동 추가면 null
  final String? recurringIncomeTemplateId;

  final bool isDeleted;
  final DateTime? deletedAt;
  final DateTime? createdAt;

  IncomeModel({
    required this.incomeId,
    required this.userId,
    required this.amount,
    required this.incomeSource,
    required this.date,
    this.memo,
    this.recurringIncomeTemplateId,
    this.isDeleted = false,
    this.deletedAt,
    this.createdAt,
  });

  /// 프리랜서 소득 3.3% 원천징수 기준 세전 금액 역산 추정 (저장하지 않는 계산값)
  /// 화면에는 반드시 "약 000원 (세전 추정)" 형태로 표기할 것
  num estimateGrossAmount() => amount / 0.967;

  factory IncomeModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return IncomeModel(
      incomeId: doc.id,
      userId: d['userId'] ?? '',
      amount: (d['amount'] as num?)?.toInt() ?? 0,
      incomeSource: IncomeSource.fromCode(d['incomeSource']),
      date: (d['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      memo: d['memo'] as String?,
      recurringIncomeTemplateId: d['recurringIncomeTemplateId'] as String?,
      isDeleted: d['isDeleted'] ?? false,
      deletedAt: (d['deletedAt'] as Timestamp?)?.toDate(),
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'userId': userId.trim(),
    'amount': amount,
    'incomeSource': incomeSource.code,
    'date': Timestamp.fromDate(date),
    'memo': memo,
    'recurringIncomeTemplateId': recurringIncomeTemplateId,
    'isDeleted': isDeleted,
    'deletedAt': deletedAt != null ? Timestamp.fromDate(deletedAt!) : null,
    'createdAt': createdAt != null
        ? Timestamp.fromDate(createdAt!)
        : FieldValue.serverTimestamp(),
  };

  IncomeModel copyWith({
    String? incomeId, // 새로 발급된 ID를 넣을 수 있도록
    String? userId,   // 기존 userId 유지 또는 변경
    int? amount,
    IncomeSource? incomeSource,
    DateTime? date,
    String? memo,
    String? recurringIncomeTemplateId,
    bool? isDeleted,
    DateTime? deletedAt,
  }) {
    return IncomeModel(
      incomeId: incomeId ?? this.incomeId,
      userId: userId ?? this.userId,
      amount: amount ?? this.amount,
      incomeSource: incomeSource ?? this.incomeSource,
      date: date ?? this.date,
      memo: memo ?? this.memo,
      recurringIncomeTemplateId: recurringIncomeTemplateId ?? this.recurringIncomeTemplateId,
      isDeleted: isDeleted ?? this.isDeleted,
      deletedAt: deletedAt ?? this.deletedAt,
      createdAt: createdAt
    );
  }
}

/// 매달 자동으로 IncomeModel을 생성하는 반복등록 원거래 (주로 월급)
class RecurringIncomeTemplate {
  final String recurringIncomeTemplateId;
  final String userId;
  final IncomeSource incomeSource;
  final int amount; // 매달 기본 금액
  final int payDay; // 매달 며칠에 자동 생성할지 (1~31)
  final bool isActive;
  final DateTime startDate;
  final String? memo;

  final bool isDeleted;
  final DateTime? deletedAt;
  final DateTime? createdAt;

  RecurringIncomeTemplate({
    required this.recurringIncomeTemplateId,
    required this.userId,
    required this.incomeSource,
    required this.amount,
    required this.payDay,
    this.isActive = true,
    required this.startDate,
    this.memo,
    this.isDeleted = false,
    this.deletedAt,
    this.createdAt,
  });

  factory RecurringIncomeTemplate.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return RecurringIncomeTemplate(
      recurringIncomeTemplateId: doc.id,
      userId: d['userId'] ?? '',
      incomeSource: IncomeSource.fromCode(d['incomeSource']),
      amount: (d['amount'] as num?)?.toInt() ?? 0,
      payDay: (d['payDay'] as num?)?.toInt() ?? 1,
      isActive: d['isActive'] ?? true,
      startDate: (d['startDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      memo: d['memo'] as String?,
      isDeleted: d['isDeleted'] ?? false,
      deletedAt: (d['deletedAt'] as Timestamp?)?.toDate(),
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'userId': userId.trim(),
    'incomeSource': incomeSource.code,
    'amount': amount,
    'payDay': payDay,
    'isActive': isActive,
    'startDate': Timestamp.fromDate(startDate),
    'memo': memo,
    'isDeleted': isDeleted,
    'deletedAt': deletedAt != null ? Timestamp.fromDate(deletedAt!) : null,
    'createdAt': createdAt != null
        ? Timestamp.fromDate(createdAt!)
        : FieldValue.serverTimestamp(),
  };

  RecurringIncomeTemplate copyWith({
    String? userId,
    IncomeSource? incomeSource,
    int? amount,
    int? payDay,
    bool? isActive,
    DateTime? startDate,
    String? memo,
    bool? isDeleted,
    DateTime? deletedAt,
  }) {
    return RecurringIncomeTemplate(
      recurringIncomeTemplateId: recurringIncomeTemplateId,
      incomeSource: incomeSource ?? this.incomeSource,
      amount: amount ?? this.amount,
      payDay: payDay ?? this.payDay,
      isActive: isActive ?? this.isActive,
      startDate: startDate ?? this.startDate,
      memo: memo ?? this.memo,
      isDeleted: isDeleted ?? this.isDeleted,
      deletedAt: deletedAt ?? this.deletedAt,
      createdAt: createdAt,
      userId: userId ?? this.userId.trim(),
    );
  }
}