import 'package:cloud_firestore/cloud_firestore.dart';

class CardPointHistoryModel {
  final String historyId;
  final DateTime date;
  final String merchant;
  final int point; // 적립은 양수, 사용은 음수
  final String type; // 'earn' | 'use'

  CardPointHistoryModel({
    required this.historyId,
    required this.date,
    required this.merchant,
    required this.point,
    required this.type,
  });

  factory CardPointHistoryModel.fromFirestore(DocumentSnapshot doc) {
    final rawData = doc.data();
    final data = rawData is Map<String, dynamic> ? rawData : <String, dynamic>{};

    return CardPointHistoryModel(
      historyId: doc.id,
      date: data['date'] is Timestamp ? (data['date'] as Timestamp).toDate() : DateTime.now(),
      merchant: data['merchant']?.toString() ?? '',
      point: (data['point'] as num?)?.toInt() ?? 0,
      type: data['type']?.toString() ?? 'earn',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'date': Timestamp.fromDate(date),
      'merchant': merchant,
      'point': point,
      'type': type,
    };
  }
}