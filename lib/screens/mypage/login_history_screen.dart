import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/login_history_entry.dart';
import '../../services/login_history_service.dart';

const _accent = Color(0xFFF5A623);
const _ink = Color(0xFF221A16);
const _inkSub = Color(0xFF8A7E77);
const _bg = Color(0xFFFAF8F6);
const _blue = Color(0xFF4F7DF3);
const _blueSoft = Color(0xFFE8EFFE);

/// 설정 > 로그인 활동 — 언제/어떤 방법으로 로그인했는지 최근 기록을 보여준다.
/// 알림함(notification_history_screen.dart)과 동일한 리스트 톤을 따른다.
class LoginHistoryScreen extends StatelessWidget {
  const LoginHistoryScreen({super.key});

  String _relativeTime(DateTime d) {
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 1) return '방금';
    if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
    if (diff.inHours < 24) return '${diff.inHours}시간 전';
    if (diff.inDays < 7) return '${diff.inDays}일 전';
    return '${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}';
  }

  String _methodLabel(String method) {
    switch (method) {
      case 'google':
        return 'Google 로그인';
      case 'email':
        return '이메일 로그인';
      default:
        return method;
    }
  }

  IconData _methodIcon(String method) {
    switch (method) {
      case 'google':
        return Icons.g_mobiledata_rounded;
      case 'email':
        return Icons.mail_outline_rounded;
      default:
        return Icons.login_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: _ink,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text('로그인 활동', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: uid == null
          ? const SizedBox.shrink()
          : StreamBuilder<List<LoginHistoryEntry>>(
              stream: LoginHistoryService().watchHistory(uid),
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const Center(
                      child: CircularProgressIndicator(color: _accent, strokeWidth: 2.4));
                }
                final items = snap.data!;
                if (items.isEmpty) {
                  return const _EmptyHistory();
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(20),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, i) => _LoginHistoryCard(
                    label: _methodLabel(items[i].method),
                    icon: _methodIcon(items[i].method),
                    relativeTime: _relativeTime(items[i].date),
                    isLatest: i == 0,
                  ),
                );
              },
            ),
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.history_rounded, size: 44, color: _inkSub),
            const SizedBox(height: 14),
            const Text('아직 로그인 기록이 없어요',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _ink)),
            const SizedBox(height: 6),
            const Text('로그인할 때마다 여기에 기록이 쌓여요',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12.5, color: _inkSub, height: 1.5)),
          ],
        ),
      ),
    );
  }
}

class _LoginHistoryCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final String relativeTime;
  final bool isLatest;

  const _LoginHistoryCard({
    required this.label,
    required this.icon,
    required this.relativeTime,
    required this.isLatest,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: _ink.withValues(alpha: 0.045), blurRadius: 14, offset: const Offset(0, 5)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [_blueSoft, Color.lerp(_blueSoft, Colors.white, 0.15)!],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: _blue.withValues(alpha: 0.18), blurRadius: 8, offset: const Offset(0, 3)),
              ],
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 20, color: _blue),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Row(
              children: [
                Text(label,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _ink)),
                if (isLatest) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: _blue.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text('최근',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: _blue)),
                  ),
                ],
              ],
            ),
          ),
          Text(relativeTime,
              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: _inkSub)),
        ],
      ),
    );
  }
}
