import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../services/chat_service.dart';
import '../../models/message_model.dart';
import '../../models/chat_model.dart';
import '../../utils/stickers.dart';
import 'package:intl/intl.dart';
import '../../services/image_service.dart';

class ChatRoomScreen extends StatefulWidget {
  final String chatId;
  const ChatRoomScreen({super.key, required this.chatId});

  @override
  State<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends State<ChatRoomScreen> {
  final _chatService = ChatService();
  final _imageService = ImageService();
  final _messageController = TextEditingController();
  static const _green = Color(0xFFFF9166);
  final String _myId = FirebaseAuth.instance.currentUser!.uid;

  ChatParticipant? _otherParticipant;
  String _otherUserId = '';
  bool _showStickers = false;

  @override
  void initState() {
    super.initState();
    _chatService.markAsRead(widget.chatId, _myId);
    _loadOtherParticipant();
  }

  Future<void> _loadOtherParticipant() async {
    final chat = await _chatService.getChat(widget.chatId);
    if (chat != null && mounted) {
      setState(() {
        _otherParticipant = chat.getOtherParticipant(_myId);
        _otherUserId = chat.participantIds.firstWhere(
              (id) => id != _myId,
          orElse: () => '',
        );
      });
    }
  }


  void _send() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final message = Message(
      messageId: '',
      senderId: _myId,
      type: MessageType.text,
      text: text,
      sentAt: DateTime.now(),
    );

    _chatService.sendMessage(
      chatId: widget.chatId,
      message: message,
      otherUserId: _otherUserId,
    );

    _messageController.clear();
  }

  void _sendSticker(String stickerId) {
    final message = Message(
      messageId: '',
      senderId: _myId,
      type: MessageType.sticker,
      stickerId: stickerId,
      sentAt: DateTime.now(),
    );

    _chatService.sendMessage(
      chatId: widget.chatId,
      message: message,
      otherUserId: _otherUserId,
    );

    setState(() => _showStickers = false);
  }

  Future<void> _sendImage() async {
    final file = await _imageService.pickImage();
    if (file == null) return;

    try {
      final url = await _imageService.uploadImage(file, 'chatImages/${widget.chatId}');

      final message = Message(
        messageId: '',
        senderId: _myId,
        type: MessageType.image,
        imageUrl: url,
        sentAt: DateTime.now(),
      );

      _chatService.sendMessage(
        chatId: widget.chatId,
        message: message,
        otherUserId: _otherUserId,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('이미지 전송 실패: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: _green,
              backgroundImage: (_otherParticipant?.avatarUrl.isNotEmpty ?? false)
                  ? NetworkImage(_otherParticipant!.avatarUrl)
                  : null,
              child: (_otherParticipant?.avatarUrl.isEmpty ?? true)
                  ? Text(
                _otherParticipant?.name.isNotEmpty == true
                    ? _otherParticipant!.name.substring(0, 1)
                    : '?',
                style: const TextStyle(color: Colors.white, fontSize: 13),
              )
                  : null,
            ),
            const SizedBox(width: 8),
            Text(_otherParticipant?.name ?? '채팅',
                style: const TextStyle(color: Colors.black, fontSize: 16)),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<Chat>(
              stream: _chatService.getChatStream(widget.chatId),
              builder: (context, chatSnapshot) {
                final otherUnread = chatSnapshot.data?.getUnreadCountFor(_otherUserId) ?? 0;

                return StreamBuilder<List<Message>>(
                  stream: _chatService.getMessages(widget.chatId),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final messages = snapshot.data!;
                    if (messages.isEmpty) {
                      return const Center(child: Text('첫 메시지를 보내보세요'));
                    }

                    // 내가 보낸 메시지 중 가장 마지막 것의 인덱스 (읽음 표시는 여기에만)
                    int lastMineIndex = -1;
                    for (int i = 0; i < messages.length; i++) {
                      if (messages[i].senderId == _myId) lastMineIndex = i;
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final msg = messages[index];
                        final isMine = msg.senderId == _myId;
                        final timeText = DateFormat('HH:mm').format(msg.sentAt.toUtc().add(const Duration(hours: 9)));
                        final showRead = isMine && index == lastMineIndex && otherUnread == 0;

                        // 이미지 메시지
                        if (msg.type == MessageType.image) {
                          return Align(
                            alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
                            child: Padding(
                              padding: EdgeInsets.only(right: isMine ? 4 : 0),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  if (isMine && index == lastMineIndex) ...[
                                    _buildReadIcon(showRead),
                                    const SizedBox(width: 6),
                                  ],
                                  Column(
                                    crossAxisAlignment:
                                    isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: Image.network(
                                          msg.imageUrl ?? '',
                                          width: 160,
                                          fit: BoxFit.cover,
                                          loadingBuilder: (context, child, progress) {
                                            if (progress == null) return child;
                                            return Container(
                                              width: 160,
                                              height: 160,
                                              color: Colors.grey[200],
                                              child: const Center(child: CircularProgressIndicator()),
                                            );
                                          },
                                          errorBuilder: (context, error, stackTrace) => Container(
                                            width: 160,
                                            height: 160,
                                            color: Colors.grey[200],
                                            child: const Icon(Icons.broken_image, color: Colors.grey),
                                          ),
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.only(top: 2, bottom: 4),
                                        child: Text(timeText, style: TextStyle(fontSize: 10, color: Colors.grey[400])),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        }
                        // 스티커 메시지
                        if (msg.type == MessageType.sticker) {
                          final path = stickerAssets[msg.stickerId] ?? '';
                          return Align(
                            alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
                            child: Padding(
                              padding: EdgeInsets.only(right: isMine ? 4 : 0),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  if (isMine && index == lastMineIndex) ...[
                                    _buildReadIcon(showRead),
                                    const SizedBox(width: 6),
                                  ],
                                  Column(
                                    crossAxisAlignment:
                                    isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                    children: [
                                      if (path.isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 4),
                                          child: Image.asset(path, width: 80, height: 80),
                                        ),
                                      Padding(
                                        padding: const EdgeInsets.only(top: 2, bottom: 4),
                                        child: Text(timeText, style: TextStyle(fontSize: 10, color: Colors.grey[400])),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        }

                        // 일반 텍스트 메시지
                        return Align(
                          alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
                          child: Padding(
                            padding: EdgeInsets.only(right: isMine ? 4 : 0),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                if (isMine && index == lastMineIndex) ...[
                                  _buildReadIcon(showRead),
                                  const SizedBox(width: 6),
                                ],
                                Flexible(
                                  child: Column(
                                    crossAxisAlignment:
                                    isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        margin: const EdgeInsets.only(top: 4),
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                        constraints: BoxConstraints(
                                          maxWidth: MediaQuery.of(context).size.width * 0.7,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isMine ? _green : Colors.grey[200],
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                        child: Text(
                                          msg.previewText,
                                          style: TextStyle(color: isMine ? Colors.white : Colors.black87),
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.only(top: 2, bottom: 4),
                                        child: Text(timeText, style: TextStyle(fontSize: 10, color: Colors.grey[400])),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),

          // 이모티콘 패널
          if (_showStickers)
            Container(
              height: 160,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Colors.grey[200]!)),
              ),
              child: GridView.count(
                crossAxisCount: 4,
                children: stickerAssets.entries.map((entry) {
                  return GestureDetector(
                    onTap: () => _sendSticker(entry.key),
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: Image.asset(entry.value),
                    ),
                  );
                }).toList(),
              ),
            ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(
                      _showStickers ? Icons.keyboard : Icons.emoji_emotions_outlined,
                      color: Colors.grey[600],
                    ),
                    onPressed: () => setState(() => _showStickers = !_showStickers),
                  ),
                  IconButton(
                    icon: Icon(Icons.image_outlined, color: Colors.grey[600]),
                    onPressed: _sendImage,
                  ),
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: InputDecoration(
                        hintText: '메시지를 입력하세요',
                        filled: true,
                        fillColor: Colors.grey[100],
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    backgroundColor: _green,
                    child: IconButton(
                      icon: const Icon(Icons.send, color: Colors.white, size: 18),
                      onPressed: _send,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  Widget _buildReadIcon(bool isRead) {
    return Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isRead ? _green : Colors.white,
        border: Border.all(color: _green, width: 1.5),
      ),
      child: Icon(
        Icons.check,
        size: 9,
        color: isRead ? Colors.white : _green,
      ),
    );
  }
}