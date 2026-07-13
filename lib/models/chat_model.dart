import 'package:cloud_firestore/cloud_firestore.dart';

class ChatParticipant {
  final String name;
  final String avatarUrl;

  ChatParticipant({
    required this.name,
    required this.avatarUrl,
  });

  factory ChatParticipant.fromMap(Map<String, dynamic> map) {
    return ChatParticipant(
      name: map['name'] ?? '',
      avatarUrl: map['avatarUrl'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'avatarUrl': avatarUrl,
    };
  }
}

class Chat {
  final String chatId;
  final List<String> participantIds;
  final Map<String, ChatParticipant> participants;
  final String? productId;
  final String lastMessage;
  final DateTime lastMessageAt;
  final Map<String, int> unreadCount;
  final DateTime createdAt;

  Chat({
    required this.chatId,
    required this.participantIds,
    required this.participants,
    this.productId,
    required this.lastMessage,
    required this.lastMessageAt,
    required this.unreadCount,
    required this.createdAt,
  });

  factory Chat.fromMap(String chatId, Map<String, dynamic> map) {
    return Chat(
      chatId: chatId,
      participantIds: List<String>.from(map['participantIds'] ?? []),
      participants: (map['participants'] as Map<String, dynamic>? ?? {}).map(
            (key, value) =>
            MapEntry(key, ChatParticipant.fromMap(value as Map<String, dynamic>)),
      ),
      productId: map['productId'] as String?,
      lastMessage: map['lastMessage'] ?? '',
      lastMessageAt:
      (map['lastMessageAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      unreadCount: Map<String, int>.from(map['unreadCount'] ?? {}),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  factory Chat.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Chat.fromMap(doc.id, data);
  }

  Map<String, dynamic> toMap() {
    return {
      'participantIds': participantIds,
      'participants': participants.map((key, value) => MapEntry(key, value.toMap())),
      'productId': productId,
      'lastMessage': lastMessage,
      'lastMessageAt': Timestamp.fromDate(lastMessageAt),
      'unreadCount': unreadCount,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  ChatParticipant? getOtherParticipant(String myUserId) {
    final otherId = participantIds.firstWhere(
          (id) => id != myUserId,
      orElse: () => '',
    );
    return participants[otherId];
  }

  int getUnreadCountFor(String userId) {
    return unreadCount[userId] ?? 0;
  }
}