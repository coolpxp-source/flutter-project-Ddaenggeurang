import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/chat_model.dart';
import '../models/message_model.dart';

class ChatService {
  final _db = FirebaseFirestore.instance;

  // 채팅방 목록 (실시간)
  Stream<List<Chat>> getChatsFor(String userId) {
    return _db
        .collection('chats')
        .where('participantIds', arrayContains: userId)
        .orderBy('lastMessageAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => Chat.fromFirestore(d)).toList());
  }

  // 메시지 목록 (실시간)
  Stream<List<Message>> getMessages(String chatId) {
    return _db
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('sentAt', descending: false)
        .snapshots()
        .map((snap) => snap.docs.map((d) => Message.fromFirestore(d)).toList());
  }

  // 채팅방 생성 (상품 문의 시 없으면 새로 만듦)
  Future<String> createOrGetChat({
    required String myId,
    required String otherId,
    required ChatParticipant me,
    required ChatParticipant other,
    String? productId,
  }) async {
    final existing = await _db
        .collection('chats')
        .where('participantIds', arrayContains: myId)
        .get();

    for (final doc in existing.docs) {
      final ids = List<String>.from(doc['participantIds']);
      if (ids.contains(otherId) && doc['productId'] == productId) {
        return doc.id;
      }
    }

    final newChat = await _db.collection('chats').add({
      'participantIds': [myId, otherId],
      'participants': {myId: me.toMap(), otherId: other.toMap()},
      'productId': productId,
      'lastMessage': '',
      'lastMessageAt': Timestamp.now(),
      'unreadCount': {myId: 0, otherId: 0},
      'createdAt': Timestamp.now(),
    });
    return newChat.id;
  }

  // 메시지 전송 + 채팅방 lastMessage 갱신
  Future<void> sendMessage({
    required String chatId,
    required Message message,
    required String otherUserId,
  }) async {
    final chatRef = _db.collection('chats').doc(chatId);

    await chatRef.collection('messages').add(message.toMap());

    await chatRef.update({
      'lastMessage': message.previewText,
      'lastMessageAt': Timestamp.fromDate(message.sentAt),
      'unreadCount.$otherUserId': FieldValue.increment(1),
    });
  }

  // 채팅방 읽음 처리
  Future<void> markAsRead(String chatId, String myId) async {
    await _db.collection('chats').doc(chatId).update({
      'unreadCount.$myId': 0,
    });
  }

  // 채팅방 단건 조회
  Future<Chat?> getChat(String chatId) async {
    final doc = await _db.collection('chats').doc(chatId).get();
    if (!doc.exists) return null;
    return Chat.fromFirestore(doc);
  }

  // 전체 채팅방의 안읽음 총합 (뱃지 표시용)
  Stream<int> getTotalUnreadCount(String userId) {
    return _db
        .collection('chats')
        .where('participantIds', arrayContains: userId)
        .snapshots()
        .map((snap) {
      int total = 0;
      for (final doc in snap.docs) {
        final unreadMap = Map<String, dynamic>.from(doc['unreadCount'] ?? {});
        total += (unreadMap[userId] ?? 0) as int;
      }
      return total;
    });
  }
}