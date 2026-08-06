import 'package:cloud_firestore/cloud_firestore.dart';

class GroupModel {
  const GroupModel({
    required this.id,
    required this.name,
    required this.inviteCode,
    required this.ownerId,
    required this.memberCount,
    required this.createdAt,
    this.description,
  });

  final String id;
  final String name;
  final String inviteCode;
  final String ownerId;
  final int memberCount;
  final DateTime createdAt;
  final String? description;

  GroupModel copyWith({
    String? id,
    String? name,
    String? inviteCode,
    String? ownerId,
    int? memberCount,
    DateTime? createdAt,
    String? description,
  }) {
    return GroupModel(
      id: id ?? this.id,
      name: name ?? this.name,
      inviteCode: inviteCode ?? this.inviteCode,
      ownerId: ownerId ?? this.ownerId,
      memberCount: memberCount ?? this.memberCount,
      createdAt: createdAt ?? this.createdAt,
      description: description ?? this.description,
    );
  }

  // Firestore 데이터를 그룹 모델로 변환
  factory GroupModel.fromMap(
      String id,
      Map<String, dynamic> data,
      ) {
    return GroupModel(
      id: id,
      name: data['name'] as String? ?? '',
      inviteCode: data['inviteCode'] as String? ?? '',
      ownerId: data['ownerId'] as String? ?? '',
      memberCount: (data['memberCount'] as num?)?.toInt() ?? 0,
      createdAt:
      (data['createdAt'] as Timestamp?)?.toDate() ??
          DateTime.now(),
      description: data['description'] as String?,
    );
  }

  // 그룹 모델을 Firestore 저장 형식으로 변환
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'inviteCode': inviteCode,
      'ownerId': ownerId,
      'memberCount': memberCount,
      'createdAt': Timestamp.fromDate(createdAt),
      'description': description,
    };
  }
}