import 'package:flutter/material.dart';
import '../../services/chat_service.dart';
import '../../models/message_model.dart';
import '../../models/chat_model.dart';
import '../../utils/stickers.dart';

class ChatRoomScreen extends StatefulWidget {
  final String chatId;
  const ChatRoomScreen({super.key, required this.chatId});

  @override
  State<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends State<ChatRoomScreen> {
  final _chatService = ChatService();
  final _messageController = TextEditingController();
  static const _green = Color(0xFF3B8B5E);
  static const _myId = 'test_user_id';

  ChatParticipant? _otherParticipant;
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
      otherUserId: _otherParticipant != null
          ? _findOtherId()
          : '',
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
      otherUserId: _otherParticipant != null ? _findOtherId() : '',
    );

    setState(() => _showStickers = false);
  }

  String _findOtherId() {
    // TODO: chat.participantIds에서 본인 제외한 ID 정확히 가져오도록 개선 필요
    return '';
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
            child: StreamBuilder<List<Message>>(
              stream: _chatService.getMessages(widget.chatId),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final messages = snapshot.data!;
                if (messages.isEmpty) {
                  return const Center(child: Text('첫 메시지를 보내보세요'));
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final isMine = msg.senderId == _myId;

                    // 스티커 메시지는 다르게 렌더링
                    if (msg.type == MessageType.sticker) {
                      final path = stickerAssets[msg.stickerId] ?? '';
                      return Align(
                        alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: path.isNotEmpty
                              ? Image.asset(path, width: 80, height: 80)
                              : const SizedBox(),
                        ),
                      );
                    }

                    return Align(
                      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
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
}