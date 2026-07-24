import 'package:cloud_firestore/cloud_firestore.dart';

class CommunityStat {
  final String userId; // doc.id
  final String nicknameMasked;
  final num savingRate;
  final num savingAmount;
  final num expenseAmount;
  final num incomeAmount;
  final String ageGroup;
  final String job;
  final DateTime updatedAt;

  CommunityStat({
    required this.userId,
    required this.nicknameMasked,
    required this.savingRate,
    required this.savingAmount,
    this.expenseAmount = 0,
    this.incomeAmount = 0,
    required this.ageGroup,
    required this.job,
    required this.updatedAt,
  });

  factory CommunityStat.fromMap(String userId, Map<String, dynamic> map) {
    return CommunityStat(
      userId: userId,
      nicknameMasked: map['nicknameMasked'] ?? '',
      savingRate: map['savingRate'] ?? 0,
      savingAmount: map['savingAmount'] ?? 0,
      expenseAmount: map['expenseAmount'] ?? 0,
      incomeAmount: map['incomeAmount'] ?? 0,
      ageGroup: map['ageGroup'] ?? '',
      job: map['job'] ?? '',
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  factory CommunityStat.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CommunityStat.fromMap(doc.id, data);
  }

  Map<String, dynamic> toMap() {
    return {
      'nicknameMasked': nicknameMasked,
      'savingRate': savingRate,
      'savingAmount': savingAmount,
      'expenseAmount': expenseAmount,
      'incomeAmount': incomeAmount,
      'ageGroup': ageGroup,
      'job': job,
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}