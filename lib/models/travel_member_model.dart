import 'package:cloud_firestore/cloud_firestore.dart';

class TravelMemberModel {
  /// Firestore 참여자 문서 ID
  final String memberId;

  /// 참여자가 속한 여행 ID
  final String travelId;

  /// 앱 회원 UID
  ///
  /// 앱 회원이 아닌 참여자는 빈 문자열로 저장한다.
  final String userId;

  /// 참여자 이름
  final String name;

  /// 여행 생성자 여부
  final bool isOwner;

  /// 참여자 등록 날짜
  final DateTime createdAt;

  /// 소프트 삭제 여부
  final bool isDeleted;

  /// 삭제 날짜
  final DateTime? deletedAt;

  const TravelMemberModel({
    required this.memberId,
    required this.travelId,
    this.userId = '',
    required this.name,
    this.isOwner = false,
    required this.createdAt,
    this.isDeleted = false,
    this.deletedAt,
  });

  /// Firestore 문서를 TravelMemberModel로 변환
  factory TravelMemberModel.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> document,
      ) {
    final Map<String, dynamic>? data = document.data();

    if (data == null) {
      throw StateError(
        '여행 참여자 문서 데이터가 존재하지 않습니다: ${document.id}',
      );
    }

    return TravelMemberModel(
      memberId: document.id,
      travelId: _toString(data['travelId']),
      userId: _toString(data['userId']),
      name: _toString(data['name']),
      isOwner: _toBool(data['isOwner']),
      createdAt: _toDateTime(data['createdAt']),
      isDeleted: _toBool(data['isDeleted']),
      deletedAt: _toNullableDateTime(data['deletedAt']),
    );
  }

  /// TravelMemberModel을 Firestore 데이터로 변환
  Map<String, dynamic> toFirestore() {
    return <String, dynamic>{
      'memberId': memberId,
      'travelId': travelId.trim(),
      'userId': userId.trim(),
      'name': name.trim(),
      'isOwner': isOwner,
      'createdAt': Timestamp.fromDate(createdAt),
      'isDeleted': isDeleted,
      'deletedAt': deletedAt == null
          ? null
          : Timestamp.fromDate(deletedAt!),
    };
  }

  /// 모델 일부 값 변경
  TravelMemberModel copyWith({
    String? memberId,
    String? travelId,
    String? userId,
    String? name,
    bool? isOwner,
    DateTime? createdAt,
    bool? isDeleted,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
  }) {
    return TravelMemberModel(
      memberId: memberId ?? this.memberId,
      travelId: travelId ?? this.travelId,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      isOwner: isOwner ?? this.isOwner,
      createdAt: createdAt ?? this.createdAt,
      isDeleted: isDeleted ?? this.isDeleted,
      deletedAt: clearDeletedAt
          ? null
          : deletedAt ?? this.deletedAt,
    );
  }

  /// Map 데이터로 변환
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'memberId': memberId,
      'travelId': travelId,
      'userId': userId,
      'name': name,
      'isOwner': isOwner,
      'createdAt': createdAt,
      'isDeleted': isDeleted,
      'deletedAt': deletedAt,
    };
  }

  /// 참여자 데이터 검증
  bool get isValid {
    return travelId.trim().isNotEmpty &&
        name.trim().isNotEmpty;
  }

  /// 화면에 표시할 참여자 이름
  String get displayName {
    if (name.trim().isEmpty) {
      return '이름 없음';
    }

    return name.trim();
  }

  static String _toString(dynamic value) {
    if (value == null) {
      return '';
    }

    return value.toString().trim();
  }

  static bool _toBool(dynamic value) {
    if (value is bool) {
      return value;
    }

    if (value is num) {
      return value != 0;
    }

    final String stringValue =
        value?.toString().trim().toLowerCase() ?? '';

    return stringValue == 'true' ||
        stringValue == '1' ||
        stringValue == 'y';
  }

  static DateTime _toDateTime(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    if (value is String) {
      return DateTime.tryParse(value) ?? DateTime.now();
    }

    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    }

    return DateTime.now();
  }

  static DateTime? _toNullableDateTime(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    if (value is String) {
      if (value.trim().isEmpty) {
        return null;
      }

      return DateTime.tryParse(value);
    }

    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    }

    return null;
  }

  @override
  String toString() {
    return 'TravelMemberModel('
        'memberId: $memberId, '
        'travelId: $travelId, '
        'userId: $userId, '
        'name: $name, '
        'isOwner: $isOwner, '
        'createdAt: $createdAt, '
        'isDeleted: $isDeleted, '
        'deletedAt: $deletedAt'
        ')';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is TravelMemberModel &&
        other.memberId == memberId &&
        other.travelId == travelId &&
        other.userId == userId &&
        other.name == name &&
        other.isOwner == isOwner &&
        other.createdAt == createdAt &&
        other.isDeleted == isDeleted &&
        other.deletedAt == deletedAt;
  }

  @override
  int get hashCode {
    return Object.hash(
      memberId,
      travelId,
      userId,
      name,
      isOwner,
      createdAt,
      isDeleted,
      deletedAt,
    );
  }
}