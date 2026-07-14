import 'package:cloud_firestore/cloud_firestore.dart';

enum MessageType { text, image, product }

extension MessageTypeX on MessageType {
  String get value => name; // "text" | "image" | "product"

  static MessageType fromString(String value) {
    return MessageType.values.firstWhere(
          (e) => e.name == value,
      orElse: () => MessageType.text,
    );
  }
}

class Message {
  final String messageId;
  final String senderId;
  final MessageType type;
  final String? text;
  final String? imageUrl;
  final String? productId; // type이 product일 때만 사용
  final DateTime sentAt;

  Message({
    required this.messageId,
    required this.senderId,
    required this.type,
    this.text,
    this.imageUrl,
    this.productId,
    required this.sentAt,
  });

  factory Message.fromMap(String messageId, Map<String, dynamic> map) {
    return Message(
      messageId: messageId,
      senderId: map['senderId'] ?? '',
      type: MessageTypeX.fromString(map['type'] ?? 'text'),
      text: map['text'] as String?,
      imageUrl: map['imageUrl'] as String?,
      productId: map['productId'] as String?,
      sentAt: (map['sentAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  factory Message.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Message.fromMap(doc.id, data);
  }

  Map<String, dynamic> toMap() {
    return {
      'senderId': senderId,
      'type': type.value,
      'text': text,
      'imageUrl': imageUrl,
      'productId': productId,
      'sentAt': Timestamp.fromDate(sentAt),
    };
  }

  // 채팅목록(74)에서 마지막 메시지 미리보기용 텍스트
  String get previewText {
    switch (type) {
      case MessageType.text:
        return text ?? '';
      case MessageType.image:
        return '사진을 보냈습니다';
      case MessageType.product:
        return '상품을 공유했습니다';
    }
  }
}