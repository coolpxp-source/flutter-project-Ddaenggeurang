import 'package:cloud_firestore/cloud_firestore.dart';

class YearEndSimulationModel {
  final String simId;
  final int income;
  final Map<String, dynamic> deductions;
  final int estimatedRefund;
  final DateTime? createdAt;

  YearEndSimulationModel({
    required this.simId,
    required this.income,
    required this.deductions,
    required this.estimatedRefund,
    this.createdAt,
  });

  factory YearEndSimulationModel.fromFirestore(DocumentSnapshot doc) {
    final rawData = doc.data();
    final data = rawData is Map<String, dynamic> ? rawData : <String, dynamic>{};

    return YearEndSimulationModel(
      simId: doc.id,
      income: (data['income'] as num?)?.toInt() ?? 0,
      deductions: Map<String, dynamic>.from(data['deductions'] ?? {}),
      estimatedRefund: (data['estimatedRefund'] as num?)?.toInt() ?? 0,
      createdAt: data['createdAt'] is Timestamp
          ? (data['createdAt'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'income': income,
      'deductions': deductions,
      'estimatedRefund': estimatedRefund,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}