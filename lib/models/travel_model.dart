import 'package:cloud_firestore/cloud_firestore.dart';

/// 여행 기간을 설정하면 해당 기간의 지출에 travelId를 자동 태깅한다.
///
/// 고정비, 할부, 정기결제 지출은 여행 지출 자동 태깅 대상에서 제외한다.
/// 동시에 하나의 여행만 isActive == true가 되도록 서비스 계층에서 제어한다.
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

  const TravelModel({
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

  /// 해당 지출을 현재 여행의 지출로 자동 태깅할 수 있는지 판단한다.
  bool shouldAutoTag({
    required DateTime expenseDate,
    required bool isFixedNature,
    required bool hasInstallmentPlan,
    required bool hasRecurringPayment,
  }) {
    if (!isActive || isDeleted) {
      return false;
    }

    final expenseDay = DateTime(
      expenseDate.year,
      expenseDate.month,
      expenseDate.day,
    );

    final travelStartDay = DateTime(
      startDate.year,
      startDate.month,
      startDate.day,
    );

    final travelEndDay = DateTime(
      endDate.year,
      endDate.month,
      endDate.day,
    );

    final isOutsideTravelPeriod =
        expenseDay.isBefore(travelStartDay) ||
            expenseDay.isAfter(travelEndDay);

    if (isOutsideTravelPeriod) {
      return false;
    }

    if (isFixedNature ||
        hasInstallmentPlan ||
        hasRecurringPayment) {
      return false;
    }

    return true;
  }

  factory TravelModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data();

    if (data == null || data is! Map<String, dynamic>) {
      throw StateError('여행 문서 데이터가 존재하지 않습니다: ${doc.id}');
    }

    return TravelModel(
      travelId: doc.id,
      userId: data['userId'] as String? ?? '',
      title: data['title'] as String? ?? '',
      startDate:
      (data['startDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      endDate:
      (data['endDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      budgetAmount: (data['budgetAmount'] as num?)?.toInt(),
      isActive: data['isActive'] as bool? ?? true,
      isDeleted: data['isDeleted'] as bool? ?? false,
      deletedAt: (data['deletedAt'] as Timestamp?)?.toDate(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'title': title.trim(),
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'budgetAmount': budgetAmount,
      'isActive': isActive,
      'isDeleted': isDeleted,
      'deletedAt':
      deletedAt != null ? Timestamp.fromDate(deletedAt!) : null,
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
    };
  }

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
      userId: userId ?? this.userId,
      title: title ?? this.title,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      budgetAmount: budgetAmount ?? this.budgetAmount,
      isActive: isActive ?? this.isActive,
      isDeleted: isDeleted ?? this.isDeleted,
      deletedAt: deletedAt ?? this.deletedAt,
      createdAt: createdAt,
    );
  }
}