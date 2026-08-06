import 'package:cloud_firestore/cloud_firestore.dart';

class SharedExpenseModel {
  const SharedExpenseModel({
    required this.id,
    required this.groupId,
    required this.title,
    required this.amount,
    required this.paidByUserId,
    required this.paidByNickname,
    required this.category,
    required this.date,
    required this.createdAt,
    this.memo,
  });

  final String id;
  final String groupId;
  final String title;
  final int amount;
  final String paidByUserId;
  final String paidByNickname;
  final String category;
  final DateTime date;
  final DateTime createdAt;
  final String? memo;

  // Firestore 데이터를 공동지출 모델로 변환
  factory SharedExpenseModel.fromMap(
      String id,
      Map<String, dynamic> data,
      ) {
    return SharedExpenseModel(
      id: id,
      groupId: data['groupId'] as String? ?? '',
      title: data['title'] as String? ?? '',
      amount: (data['amount'] as num?)?.toInt() ?? 0,
      paidByUserId: data['paidByUserId'] as String? ?? '',
      paidByNickname:
      data['paidByNickname'] as String? ?? '',
      category: data['category'] as String? ?? '',
      date:
      (data['date'] as Timestamp?)?.toDate() ??
          DateTime.now(),
      createdAt:
      (data['createdAt'] as Timestamp?)?.toDate() ??
          DateTime.now(),
      memo: data['memo'] as String?,
    );
  }

// 공동지출 모델을 Firestore 저장 형식으로 변환
  Map<String, dynamic> toMap() {
    return {
      'groupId': groupId,
      'title': title,
      'amount': amount,
      'paidByUserId': paidByUserId,
      'paidByNickname': paidByNickname,
      'category': category,
      'date': Timestamp.fromDate(date),
      'createdAt': Timestamp.fromDate(createdAt),
      'memo': memo,
    };
  }
}