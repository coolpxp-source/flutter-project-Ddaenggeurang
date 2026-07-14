import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../services/chat_service.dart';
import '../../models/chat_model.dart';
import 'chat_room_screen.dart';

class ChatListScreen extends StatelessWidget {
  ChatListScreen({super.key});

  static const _green = Color(0xFF3B8B5E);

  // TODO: 로그인 연결되면 교체
  final String _myId = FirebaseAuth.instance.currentUser!.uid;

  @override
  Widget build(BuildContext context) {
    final service = ChatService();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('채팅', style: TextStyle(color: Colors.black)),
      ),
      body: StreamBuilder<List<Chat>>(
        stream: service.getChatsFor(_myId),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final chats = snapshot.data!;
          if (chats.isEmpty) {
            return const Center(child: Text('아직 채팅방이 없어요'));
          }
          return ListView.separated(
            itemCount: chats.length,
            separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey[200]),
            itemBuilder: (context, index) {
              final chat = chats[index];
              final other = chat.getOtherParticipant(_myId);
              final unread = chat.getUnreadCountFor(_myId);

              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: CircleAvatar(
                  radius: 22,
                  backgroundColor: _green,
                  backgroundImage: (other?.avatarUrl.isNotEmpty ?? false)
                      ? NetworkImage(other!.avatarUrl)
                      : null,
                  child: (other?.avatarUrl.isEmpty ?? true)
                      ? Text(other?.name.substring(0, 1) ?? '?',
                      style: const TextStyle(color: Colors.white))
                      : null,
                ),
                title: Text(other?.name ?? '알 수 없음',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: Text(
                  chat.lastMessage.isEmpty ? '대화를 시작해보세요' : chat.lastMessage,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                ),
                trailing: unread > 0
                    ? Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _green,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text('$unread',
                      style: const TextStyle(color: Colors.white, fontSize: 11)),
                )
                    : null,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => ChatRoomScreen(chatId: chat.chatId)),
                ),
              );
            },
          );
        },
      ),
    );
  }
}