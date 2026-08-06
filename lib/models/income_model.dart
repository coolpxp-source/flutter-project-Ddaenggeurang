import 'package:cloud_firestore/cloud_firestore.dart';

class IncomeModel {
  final String incomeId;
  final String userId;
  final int amount;

  // 2. enum 대신 파이어베이스의 카테고리 문서 ID를 저장하도록 변경
  final String categoryId;

  final DateTime date;
  final String? memo;
  final String? recurringIncomeTemplateId;
  final String? lastRecurringIncomeTemplateId;

  /// 정기수입일 때 매달 입금되는 날짜 (예: 25일 → 25). recurringIncomeTemplateId가 있을 때만 의미 있음
  final int? recurringPayDay;
  final bool isDeleted;
  final DateTime? deletedAt;
  final DateTime? createdAt;

  IncomeModel({
    required this.incomeId,
    required this.userId,
    required this.amount,
    required this.categoryId, // 필수값으로 변경
    required this.date,
    this.memo,
    this.recurringIncomeTemplateId,
    this.lastRecurringIncomeTemplateId,
    this.recurringPayDay,
    this.isDeleted = false,
    this.deletedAt,
    this.createdAt,
  });

  num estimateGrossAmount() => amount / 0.967;

  factory IncomeModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return IncomeModel(
      incomeId: doc.id,
      userId: d['userId'] ?? '',
      amount: (d['amount'] as num?)?.toInt() ?? 0,

      // 3. 파이어베이스에서 카테고리 ID를 직접 읽어옵니다.
      categoryId: d['categoryId'] ?? '',

      date: (d['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      memo: d['memo'] as String?,
      recurringIncomeTemplateId: d['recurringIncomeTemplateId'] as String?,
      lastRecurringIncomeTemplateId: d['lastRecurringIncomeTemplateId'] as String?,
      recurringPayDay: (d['recurringPayDay'] as num?)?.toInt(),
      isDeleted: d['isDeleted'] ?? false,
      deletedAt: (d['deletedAt'] as Timestamp?)?.toDate(),
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'userId': userId.trim(),
    'amount': amount,
    'categoryId': categoryId,
    'date': Timestamp.fromDate(date),
    'memo': memo,
    'recurringIncomeTemplateId': recurringIncomeTemplateId,
    'recurringPayDay': recurringPayDay,
    'lastRecurringIncomeTemplateId': lastRecurringIncomeTemplateId,
    'isDeleted': isDeleted,
    'deletedAt': deletedAt != null ? Timestamp.fromDate(deletedAt!) : null,
    'createdAt': createdAt != null
        ? Timestamp.fromDate(createdAt!)
        : FieldValue.serverTimestamp(),
  };

  IncomeModel copyWith({
    String? incomeId,
    String? userId,
    int? amount,
    String? categoryId,
    DateTime? date,
    String? memo,
    String? recurringIncomeTemplateId,
    String? lastRecurringIncomeTemplateId,
    int? recurringPayDay,
    bool? isDeleted,
    DateTime? deletedAt,
    DateTime? createdAt,
  }) {
    return IncomeModel(
        incomeId: incomeId ?? this.incomeId,
        userId: userId ?? this.userId,
        amount: amount ?? this.amount,
        categoryId: categoryId ?? this.categoryId,
        date: date ?? this.date,
        memo: memo ?? this.memo,
        recurringIncomeTemplateId: recurringIncomeTemplateId ?? this.recurringIncomeTemplateId,
        lastRecurringIncomeTemplateId: lastRecurringIncomeTemplateId ?? this.lastRecurringIncomeTemplateId,
        recurringPayDay: recurringPayDay ?? this.recurringPayDay,
        isDeleted: isDeleted ?? this.isDeleted,
        deletedAt: deletedAt ?? this.deletedAt,
        createdAt: createdAt ?? this.createdAt,
    );
  }
}

/// 매달 자동으로 생성되는 반복등록 템플릿
class RecurringIncomeTemplate {
  final String recurringIncomeTemplateId;
  final String userId;
  final String categoryId;
  final int amount;
  final int payDay;
  final bool isActive;
  final DateTime startDate;
  final String? memo;
  final bool isDeleted;
  final DateTime? deletedAt;
  final DateTime? createdAt;

  RecurringIncomeTemplate({
    required this.recurringIncomeTemplateId,
    required this.userId,
    required this.categoryId,
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
      categoryId: d['categoryId'] ?? '',
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
    'categoryId': categoryId,
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
    String? categoryId,
    int? amount,
    int? payDay,
    bool? isActive,
    DateTime? startDate,
    String? memo,
    bool? isDeleted,
    DateTime? deletedAt,
    DateTime? createdAt,
  }) {
    return RecurringIncomeTemplate(
      recurringIncomeTemplateId: recurringIncomeTemplateId,
      categoryId: categoryId ?? this.categoryId,
      amount: amount ?? this.amount,
      payDay: payDay ?? this.payDay,
      isActive: isActive ?? this.isActive,
      startDate: startDate ?? this.startDate,
      memo: memo ?? this.memo,
      isDeleted: isDeleted ?? this.isDeleted,
      deletedAt: deletedAt ?? this.deletedAt,
      createdAt: createdAt ?? this.createdAt,
      userId: userId ?? this.userId.trim(),
    );
  }
}