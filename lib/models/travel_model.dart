import 'package:cloud_firestore/cloud_firestore.dart';

/// 여행 기간을 설정하면 그 기간의 지출이 자동으로 travelId 태깅됨.
/// 단, EXPENSE.nature == fixed 이거나 installmentPlanId/recurringPaymentId가 있는 지출은
/// 여행 지출이 아니라 원래 성격의 지출이므로 자동 태깅 대상에서 제외해야 함.
/// 한 번에 하나의 여행만 isActive == true 가 되도록 서비스 레이어에서 제어.
class TravelModel {
  final String travelId;
  final String userId;
  final String title;
  final DateTime startDate;
  final DateTime endDate;
  final int? budgetAmount;
  final bool isActive;

  final bool isDeleted;
  final DateTime? deletedAt;
  final DateTime? createdAt;

  TravelModel({
    required this.travelId,
    required this.userId,
    required this.title,
    required this.startDate,
    required this.endDate,
    this.budgetAmount,
    this.isActive = true,
    this.isDeleted = false,
    this.deletedAt,
    this.createdAt,
  });

  /// 이 지출을 여행 지출로 자동 태깅해도 되는지 판단
  /// (호출 쪽에서 ExpenseNature, installmentPlanId, recurringPaymentId를 넘겨줌)
  bool shouldAutoTag({
    required DateTime expenseDate,
    required bool isFixedNature,
    required bool hasInstallmentPlan,
    required bool hasRecurringPayment,
  }) {
    if (!isActive) return false;
    if (expenseDate.isBefore(startDate) || expenseDate.isAfter(endDate)) {
      return false;
    }
    if (isFixedNature || hasInstallmentPlan || hasRecurringPayment) return false;
    return true;
  }

  factory TravelModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return TravelModel(
      travelId: doc.id,
      userId: d['userId'] ?? '',
      title: d['title'] ?? '',
      startDate: (d['startDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      endDate: (d['endDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      budgetAmount: (d['budgetAmount'] as num?)?.toInt(),
      isActive: d['isActive'] ?? true,
      isDeleted: d['isDeleted'] ?? false,
      deletedAt: (d['deletedAt'] as Timestamp?)?.toDate(),
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'userId': userId,
    'title': title,
    'startDate': Timestamp.fromDate(startDate),
    'endDate': Timestamp.fromDate(endDate),
    'budgetAmount': budgetAmount,
    'isActive': isActive,
    'isDeleted': isDeleted,
    'deletedAt': deletedAt != null ? Timestamp.fromDate(deletedAt!) : null,
    'createdAt': createdAt != null
        ? Timestamp.fromDate(createdAt!)
        : FieldValue.serverTimestamp(),
  };

  TravelModel copyWith({
    String? userId,
    String? title,
    DateTime? startDate,
    DateTime? endDate,
    int? budgetAmount,
    bool? isActive,
    bool? isDeleted,
    DateTime? deletedAt,
  }) {
    return TravelModel(
      travelId: travelId,
      title: title ?? this.title,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      budgetAmount: budgetAmount ?? this.budgetAmount,
      isActive: isActive ?? this.isActive,
      isDeleted: isDeleted ?? this.isDeleted,
      deletedAt: deletedAt ?? this.deletedAt,
      createdAt: createdAt,
      userId: userId ?? this.userId
    );
  }
}