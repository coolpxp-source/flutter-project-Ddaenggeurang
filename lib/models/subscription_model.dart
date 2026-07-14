import 'package:cloud_firestore/cloud_firestore.dart';

class SubscriptionModel {
  final String id;
  final String name;
  final int amount;
  final int paymentDay;
  final bool isActive;
  final DateTime? createdAt;

  const SubscriptionModel({
    required this.id,
    required this.name,
    required this.amount,
    required this.paymentDay,
    required this.isActive,
    this.createdAt,
  });

  factory SubscriptionModel.fromDocument(
      DocumentSnapshot<Map<String, dynamic>> doc,
      ) {
    final data = doc.data() ?? {};

    return SubscriptionModel(
      id: doc.id,
      name: data['name'] as String? ?? '',
      amount: (data['amount'] as num?)?.toInt() ?? 0,
      paymentDay: (data['paymentDay'] as num?)?.toInt() ?? 1,
      isActive: data['isActive'] as bool? ?? true,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'amount': amount,
      'paymentDay': paymentDay,
      'isActive': isActive,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  SubscriptionModel copyWith({
    String? id,
    String? name,
    int? amount,
    int? paymentDay,
    bool? isActive,
    DateTime? createdAt,
  }) {
    return SubscriptionModel(
      id: id ?? this.id,
      name: name ?? this.name,
      amount: amount ?? this.amount,
      paymentDay: paymentDay ?? this.paymentDay,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}