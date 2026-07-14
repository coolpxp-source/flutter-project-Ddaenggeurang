import 'package:cloud_firestore/cloud_firestore.dart';

enum BillingCycle {
  monthly('monthly', '매달'),
  yearly('yearly', '매년');

  final String code;
  final String label;
  const BillingCycle(this.code, this.label);

  static BillingCycle fromCode(String? code) => BillingCycle.values.firstWhere(
        (e) => e.code == code,
    orElse: () => BillingCycle.monthly,
  );
}

/// 구독(OTT·음원 등), 보험료, 정기후원을 공통으로 다루는 모델
/// 매달(또는 매년) EXPENSE를 자동 생성하고, 실제 결제금액이 amount와 다르면
/// "금액이 변경됐나요?" 확인 후 사용자가 amount를 갱신하는 흐름으로 처리
class RecurringPaymentModel {
  final String recurringPaymentId;
  final String userId;
  final String name; // 예: "넷플릭스", "OO생명 보험료", "OO단체 후원금"
  final int amount;
  final BillingCycle billingCycle;
  final DateTime nextBillingDate;
  final String categoryId;

  final bool isDeleted;
  final DateTime? deletedAt;
  final DateTime? createdAt;

  RecurringPaymentModel({
    required this.recurringPaymentId,
    required this.userId,
    required this.name,
    required this.amount,
    required this.billingCycle,
    required this.nextBillingDate,
    required this.categoryId,
    this.isDeleted = false,
    this.deletedAt,
    this.createdAt,
  });

  factory RecurringPaymentModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return RecurringPaymentModel(
      recurringPaymentId: doc.id,
      userId: d['userId'] ?? '',
      name: d['name'] ?? '',
      amount: (d['amount'] as num?)?.toInt() ?? 0,
      billingCycle: BillingCycle.fromCode(d['billingCycle']),
      nextBillingDate:
      (d['nextBillingDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      categoryId: d['categoryId'] ?? '',
      isDeleted: d['isDeleted'] ?? false,
      deletedAt: (d['deletedAt'] as Timestamp?)?.toDate(),
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'userId': userId,
    'name': name,
    'amount': amount,
    'billingCycle': billingCycle.code,
    'nextBillingDate': Timestamp.fromDate(nextBillingDate),
    'categoryId': categoryId,
    'isDeleted': isDeleted,
    'deletedAt': deletedAt != null ? Timestamp.fromDate(deletedAt!) : null,
    'createdAt': createdAt != null
        ? Timestamp.fromDate(createdAt!)
        : FieldValue.serverTimestamp(),
  };

  RecurringPaymentModel copyWith({
    String? userId,
    String? name,
    int? amount,
    BillingCycle? billingCycle,
    DateTime? nextBillingDate,
    String? categoryId,
    bool? isDeleted,
    DateTime? deletedAt,
  }) {
    return RecurringPaymentModel(
      recurringPaymentId: recurringPaymentId,
      name: name ?? this.name,
      amount: amount ?? this.amount,
      billingCycle: billingCycle ?? this.billingCycle,
      nextBillingDate: nextBillingDate ?? this.nextBillingDate,
      categoryId: categoryId ?? this.categoryId,
      isDeleted: isDeleted ?? this.isDeleted,
      deletedAt: deletedAt ?? this.deletedAt,
      createdAt: createdAt,
      userId: userId ?? this.userId
    );
  }
}