import 'package:cloud_firestore/cloud_firestore.dart';

class TravelMemberModel {
  /// 화면 및 목록에서 사용할 참여자 식별값
  final String memberId;

  /// 참여자가 속한 여행 ID
  final String travelId;

  /// Firebase Authentication 회원 UID
  final String userId;

  /// 참여자 이름 또는 닉네임
  final String name;

  /// 회원 이메일
  final String email;

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
    required this.userId,
    required this.name,
    this.email = '',
    this.isOwner = false,
    required this.createdAt,
    this.isDeleted = false,
    this.deletedAt,
  });

  /// 정상적인 앱 회원 참여자인지 확인
  bool get isRegisteredMember {
    return userId.trim().isNotEmpty;
  }

  /// 여행 생성자가 아닌 일반 참여자인지 확인
  bool get canLeave {
    return !isOwner && !isDeleted;
  }

  /// 화면에 표시할 참여자 이름
  String get displayName {
    final String trimmedName = name.trim();

    if (trimmedName.isNotEmpty) {
      return trimmedName;
    }

    final String trimmedEmail = email.trim();

    if (trimmedEmail.isNotEmpty) {
      return trimmedEmail;
    }

    return '회원';
  }

  /// 참여자 데이터 검증
  bool get isValid {
    return memberId.trim().isNotEmpty &&
        travelId.trim().isNotEmpty &&
        userId.trim().isNotEmpty &&
        displayName.isNotEmpty;
  }

  factory TravelMemberModel.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> document,
      ) {
    final Map<String, dynamic>? data = document.data();

    if (data == null) {
      throw StateError(
        '여행 참여자 문서 데이터가 존재하지 않습니다: '
            '${document.id}',
      );
    }

    return TravelMemberModel(
      memberId: document.id,
      travelId: _toString(data['travelId']),
      userId: _toString(data['userId']),
      name: _readName(data),
      email: _toString(data['email']),
      isOwner: _toBool(data['isOwner']),
      createdAt: _toDateTime(data['createdAt']),
      isDeleted: _toBool(data['isDeleted']),
      deletedAt:
      _toNullableDateTime(data['deletedAt']),
    );
  }

  /// users 문서와 travels 문서를 이용해 참여자 모델 생성
  factory TravelMemberModel.fromUserDocument({
    required String travelId,
    required String ownerId,
    required DocumentSnapshot<Map<String, dynamic>>
    userDocument,
    DateTime? joinedAt,
  }) {
    final Map<String, dynamic> data =
        userDocument.data() ?? <String, dynamic>{};

    final String userId = userDocument.id;

    return TravelMemberModel(
      memberId: '${travelId}_$userId',
      travelId: travelId,
      userId: userId,
      name: _readName(data),
      email: _toString(data['email']),
      isOwner: userId == ownerId,
      createdAt: joinedAt ?? DateTime.now(),
      isDeleted: false,
      deletedAt: null,
    );
  }

  Map<String, dynamic> toFirestore() {
    if (userId.trim().isEmpty) {
      throw StateError(
        '비회원은 여행 참여자로 저장할 수 없습니다.',
      );
    }

    return <String, dynamic>{
      'memberId': memberId.trim(),
      'travelId': travelId.trim(),
      'userId': userId.trim(),
      'name': name.trim(),
      'email': email.trim().toLowerCase(),
      'isOwner': isOwner,
      'createdAt': Timestamp.fromDate(createdAt),
      'isDeleted': isDeleted,
      'deletedAt': deletedAt == null
          ? null
          : Timestamp.fromDate(deletedAt!),
    };
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'memberId': memberId,
      'travelId': travelId,
      'userId': userId,
      'name': name,
      'email': email,
      'isOwner': isOwner,
      'createdAt': createdAt,
      'isDeleted': isDeleted,
      'deletedAt': deletedAt,
    };
  }

  TravelMemberModel copyWith({
    String? memberId,
    String? travelId,
    String? userId,
    String? name,
    String? email,
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
      email: email ?? this.email,
      isOwner: isOwner ?? this.isOwner,
      createdAt: createdAt ?? this.createdAt,
      isDeleted: isDeleted ?? this.isDeleted,
      deletedAt: clearDeletedAt
          ? null
          : deletedAt ?? this.deletedAt,
    );
  }

  static String _readName(
      Map<String, dynamic> data,
      ) {
    final List<dynamic> candidates = <dynamic>[
      data['name'],
      data['nickname'],
      data['displayName'],
      data['userName'],
    ];

    for (final dynamic candidate in candidates) {
      final String value = _toString(candidate);

      if (value.isNotEmpty) {
        return value;
      }
    }

    return '';
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
      return DateTime.tryParse(value) ??
          DateTime.now();
    }

    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(
        value,
      );
    }

    return DateTime.now();
  }

  static DateTime? _toNullableDateTime(
      dynamic value,
      ) {
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
      return DateTime.fromMillisecondsSinceEpoch(
        value,
      );
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
        'email: $email, '
        'isOwner: $isOwner, '
        'createdAt: $createdAt, '
        'isDeleted: $isDeleted'
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
        other.email == email &&
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
      email,
      isOwner,
      createdAt,
      isDeleted,
      deletedAt,
    );
  }
}