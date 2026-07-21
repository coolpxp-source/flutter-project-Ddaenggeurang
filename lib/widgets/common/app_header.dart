import 'package:flutter/material.dart';
import '../../services/notification_history_service.dart';
import '../../screens/notification/notification_history_screen.dart';

PreferredSizeWidget buildDdaengHeader(BuildContext context, String uid, {required Color inkColor}) {
  return AppBar(
    backgroundColor: Colors.white,
    foregroundColor: inkColor,
    elevation: 0,
    scrolledUnderElevation: 0,
    surfaceTintColor: Colors.transparent,
    title: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset('assets/images/Icon.png', width: 26, height: 26),
        const SizedBox(width: 8),
        Text('땡그랑', style: TextStyle(fontWeight: FontWeight.w800, color: inkColor)),
      ],
    ),
    actions: [
      IconButton(
        icon: StreamBuilder<int>(
          stream: NotificationHistoryService().watchUnreadCount(uid),
          builder: (context, snap) {
            final unread = snap.data ?? 0;
            return Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  unread > 0 ? Icons.notifications_rounded : Icons.notifications_none_rounded,
                  size: 24,
                  color: inkColor,
                ),
                if (unread > 0)
                  Positioned(
                    top: -4,
                    right: -4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE5735A),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white, width: 1.4),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        unread > 9 ? '9+' : '$unread',
                        style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.white, height: 1.2),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
        tooltip: '알림',
        onPressed: () => Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const NotificationHistoryScreen())),
      ),
    ],
  );
}