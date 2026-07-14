import 'package:cloud_firestore/cloud_firestore.dart';

/// 할부 원거래 — 매달 EXPENSE를 자동 생성하는 틀
/// 이자 계산은 하지 않고 무이자 기준 균등금액으로만 채운 뒤,
/// 실제 결제금액이 다르면 개별 ExpenseModel.isAmountAdjusted로 표시함
class InstallmentPlan {
  final String installmentPlanId;
  final String userId;
  final String productName;
  final int totalAmount;
  final int totalMonths;
  final int monthlyAmount; // totalAmount / totalMonths 반올림 (원 단위 정수, 무이자 기준 균등 금액)
  final DateTime startDate;
  final String categoryId;

  final bool isDeleted;
  final DateTime? deletedAt;
  final DateTime? createdAt;

  InstallmentPlan({
    required this.installmentPlanId,
    required this.userId,
    required this.productName,
    required this.totalAmount,
    required this.totalMonths,
    required this.monthlyAmount,
    required this.startDate,
    required this.categoryId,
    this.isDeleted = false,
    this.deletedAt,
    this.createdAt,
  });

  /// totalAmount, totalMonths만 있고 monthlyAmount를 안 넘겼을 때 균등 계산해서 생성
  /// (나누어 떨어지지 않으면 반올림 — 원 단위는 항상 정수여야 함)
  factory InstallmentPlan.create({
    required String installmentPlanId,
    required String userId,
    required String productName,
    required int totalAmount,
    required int totalMonths,
    required DateTime startDate,
    required String categoryId,
  }) {
    return InstallmentPlan(
      installmentPlanId: installmentPlanId,
      userId: userId,
      productName: productName,
      totalAmount: totalAmount,
      totalMonths: totalMonths,
      monthlyAmount: (totalAmount / totalMonths).round(),
      startDate: startDate,
      categoryId: categoryId,
    );
  }

  /// 오늘 날짜 기준 "지금 몇 회차여야 하는지" 계산 (1부터 시작, totalMonths 넘으면 종료)
  int currentInstallmentNo({DateTime? asOf}) {
    final now = asOf ?? DateTime.now();
    final monthsPassed =
        (now.year - startDate.year) * 12 + (now.month - startDate.month) + 1;
    if (monthsPassed < 1) return 1;
    if (monthsPassed > totalMonths) return totalMonths;
    return monthsPassed;
  }

  bool get isFinished => currentInstallmentNo() >= totalMonths;

  factory InstallmentPlan.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return InstallmentPlan(
      installmentPlanId: doc.id,
      userId: d['userId'] ?? '',
      productName: d['productName'] ?? '',
      totalAmount: (d['totalAmount'] as num?)?.toInt() ?? 0,
      totalMonths: (d['totalMonths'] as num?)?.toInt() ?? 1,
      monthlyAmount: (d['monthlyAmount'] as num?)?.toInt() ?? 0,
      startDate: (d['startDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      categoryId: d['categoryId'] ?? '',
      isDeleted: d['isDeleted'] ?? false,
      deletedAt: (d['deletedAt'] as Timestamp?)?.toDate(),
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'userId': userId,
    'productName': productName,
    'totalAmount': totalAmount,
    'totalMonths': totalMonths,
    'monthlyAmount': monthlyAmount,
    'startDate': Timestamp.fromDate(startDate),
    'categoryId': categoryId,
    'isDeleted': isDeleted,
    'deletedAt': deletedAt != null ? Timestamp.fromDate(deletedAt!) : null,
    'createdAt': createdAt != null
        ? Timestamp.fromDate(createdAt!)
        : FieldValue.serverTimestamp(),
  };

  InstallmentPlan copyWith({
    String? userId,
    String? productName,
    int? totalAmount,
    int? totalMonths,
    int? monthlyAmount,
    DateTime? startDate,
    String? categoryId,
    bool? isDeleted,
    DateTime? deletedAt,
  }) {
    return InstallmentPlan(
      installmentPlanId: installmentPlanId,
      productName: productName ?? this.productName,
      totalAmount: totalAmount ?? this.totalAmount,
      totalMonths: totalMonths ?? this.totalMonths,
      monthlyAmount: monthlyAmount ?? this.monthlyAmount,
      startDate: startDate ?? this.startDate,
      categoryId: categoryId ?? this.categoryId,
      isDeleted: isDeleted ?? this.isDeleted,
      deletedAt: deletedAt ?? this.deletedAt,
      createdAt: createdAt,
      userId: userId ?? this.userId
    );
  }
}