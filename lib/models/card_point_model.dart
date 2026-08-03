import 'package:cloud_firestore/cloud_firestore.dart';

class CardPointModel {
  /// Firestore card_points 문서 ID
  final String cardId;

  /// 카드를 소유한 Firebase 사용자 UID
  final String userId;

  /// 카드 이름 (예: 신한 딥드림 카드)
  final String cardName;

  /// 카드사 이름 (예: 신한카드)
  final String companyName;

  /// 보유 총 포인트
  final int totalPoint;

  /// 소멸 예정 포인트
  final int expiringPoint;

  /// 생성 시간
  final DateTime? createdAt;

  /// 수정 시간
  final DateTime? updatedAt;

  CardPointModel({
    required this.cardId,
    required this.userId,
    required this.cardName,
    required this.companyName,
    this.totalPoint = 0,
    this.expiringPoint = 0,
    this.createdAt,
    this.updatedAt,
  })  : assert(
  userId.trim().isNotEmpty,
  'CardPointModel.userId에는 실제 Firebase UID가 필요합니다.',
  ),
        assert(
        totalPoint >= 0 && expiringPoint >= 0,
        '포인트는 0 이상이어야 합니다.',
        );

  /// Firestore 문서를 CardPointModel로 변환
  factory CardPointModel.fromFirestore(DocumentSnapshot doc) {
    final rawData = doc.data();
    final data = rawData is Map<String, dynamic> ? rawData : <String, dynamic>{};

    return CardPointModel(
      cardId: doc.id,
      userId: data['userId']?.toString().trim() ?? '',
      cardName: data['cardName']?.toString() ?? '',
      companyName: data['companyName']?.toString() ?? '',
      totalPoint: (data['totalPoint'] as num?)?.toInt() ?? 0,
      expiringPoint: (data['expiringPoint'] as num?)?.toInt() ?? 0,
      createdAt: _timestampToDateTime(data['createdAt']),
      updatedAt: _timestampToDateTime(data['updatedAt']),
    );
  }

  /// CardPointModel을 Firestore 저장 형식으로 변환
  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId.trim(),
      'cardName': cardName,
      'companyName': companyName,
      'totalPoint': totalPoint,
      'expiringPoint': expiringPoint,
      'createdAt': createdAt == null
          ? FieldValue.serverTimestamp()
          : Timestamp.fromDate(createdAt!),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  /// 객체 복사 및 변경을 위한 copyWith
  CardPointModel copyWith({
    String? cardId,
    String? userId,
    String? cardName,
    String? companyName,
    int? totalPoint,
    int? expiringPoint,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CardPointModel(
      cardId: cardId ?? this.cardId,
      userId: userId ?? this.userId,
      cardName: cardName ?? this.cardName,
      companyName: companyName ?? this.companyName,
      totalPoint: totalPoint ?? this.totalPoint,
      expiringPoint: expiringPoint ?? this.expiringPoint,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Firestore Timestamp를 DateTime으로 안전하게 변환
  static DateTime? _timestampToDateTime(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is DateTime) {
      return value;
    }
    if (value is String) {
      return DateTime.tryParse(value);
    }
    return null;
  }
}