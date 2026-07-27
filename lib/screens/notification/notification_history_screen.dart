import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/notification_entry_model.dart';
import '../../services/notification_history_service.dart';
import '../../services/notification_service.dart';
import '../../widgets/common/ddaeng_modal.dart';

const _accent = Color(0xFFF5A623);
const _ink = Color(0xFF221A16);
const _inkSub = Color(0xFF8A7E77);
const _bg = Color(0xFFFAF8F6);
const _purple = Color(0xFF6C5CE7);
const _purpleSoft = Color(0xFFEDE9FE);
const _amberSoft = Color(0xFFFFF3DE);

/// 알림함 — 앱이 켜져 있을 때 실제로 띄운 로컬 알림(상담 리마인더/오늘의 잔소리)의
/// 기록. 화면을 열면 안 읽은 알림을 전부 읽음 처리한다.
class NotificationHistoryScreen extends StatefulWidget {
  const NotificationHistoryScreen({super.key});

  @override
  State<NotificationHistoryScreen> createState() =>
      _NotificationHistoryScreenState();
}

class _NotificationHistoryScreenState extends State<NotificationHistoryScreen> {
  final _service = NotificationHistoryService();
  String get _uid => FirebaseAuth.instance.currentUser!.uid;
  bool _markedRead = false;

  Future<void> _markAllRead(List<NotificationEntry> items) async {
    if (_markedRead) return;
    _markedRead = true;
    for (final e in items.where((e) => !e.read)) {
      await _service.markRead(_uid, e.id);
    }
  }

  String _relativeTime(DateTime d) {
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 1) return '방금';
    if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
    if (diff.inHours < 24) return '${diff.inHours}시간 전';
    if (diff.inDays < 7) return '${diff.inDays}일 전';
    return '${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}';
  }

  Future<void> _clearAll() async {
    final ok = await DdaengModal.confirm(
      context,
      title: '알림을 전부 삭제할까요?',
      message: '삭제하면 되돌릴 수 없어요',
      type: ModalType.danger,
      confirmText: '전체 삭제',
    );
    if (ok) await _service.deleteAll(_uid);
  }

  (IconData, Color, Color) _visualFor(String type) {
    switch (type) {
      case 'nagging':
        return (Icons.record_voice_over_rounded, _purple, _purpleSoft);
      case 'resolution':
        return (
          Icons.wb_sunny_rounded,
          const Color(0xFF00C2A8),
          const Color(0xFFDBF7F3),
        );
      case 'streak':
        return (
          Icons.local_fire_department_rounded,
          const Color(0xFFF04438),
          const Color(0xFFFEE4E2),
        );
      case 'levelup':
        return (
          Icons.military_tech_rounded,
          const Color(0xFFFFB300),
          const Color(0xFFFFF3D6),
        );
      case 'budget_warning':
        return (
          Icons.savings_outlined,
          const Color(0xFFF04438),
          const Color(0xFFFEE4E2),
        );
      case 'consult':
        return (
          Icons.chat_bubble_outline_rounded,
          const Color(0xFF2F6BFF),
          const Color(0xFFEEF4FF),
        );
      default:
        return (Icons.forum_rounded, _accent, _amberSoft);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: _ink,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text('알림함', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            onPressed: _clearAll,
            icon: const Icon(Icons.delete_sweep_outlined, size: 22),
            tooltip: '전체 삭제',
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned(
            right: -60,
            bottom: -40,
            child: Opacity(
              opacity: 0.06,
              child: Transform.rotate(
                angle: -0.2,
                child: Image.asset(
                  'assets/images/ddaeng_logo_transparent_trimmed.png',
                  width: 320,
                ),
              ),
            ),
          ),
          StreamBuilder<List<NotificationEntry>>(
            stream: _service.watchHistory(_uid),
            builder: (context, snap) {
              if (!snap.hasData) {
                return const Center(
                  child: CircularProgressIndicator(
                    color: _accent,
                    strokeWidth: 2.4,
                  ),
                );
              }
              final items = snap.data!;
              WidgetsBinding.instance.addPostFrameCallback(
                (_) => _markAllRead(items),
              );

              if (items.isEmpty) {
                return const _EmptyHistory();
              }
              return ListView.separated(
                padding: const EdgeInsets.all(20),
                itemCount: items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, i) => _NotificationCard(
                  entry: items[i],
                  uid: _uid,
                  visual: _visualFor(items[i].type),
                  relativeTime: _relativeTime(items[i].date),
                ),
              );
            },
          ),
        ],
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
            const Icon(
              Icons.notifications_none_rounded,
              size: 44,
              color: _inkSub,
            ),
            const SizedBox(height: 14),
            const Text(
              '아직 온 알림이 없어요',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: _ink,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              '상담 리마인더, 오늘의 잔소리 같은 알림이\n오면 여기에 모여요',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, color: _inkSub, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final NotificationEntry entry;
  final String uid;
  final (IconData, Color, Color) visual;
  final String relativeTime;
  const _NotificationCard({
    required this.entry,
    required this.uid,
    required this.visual,
    required this.relativeTime,
  });

  @override
  Widget build(BuildContext context) {
    final (icon, color, soft) = visual;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => NotificationService.navigateForPayload(entry.type),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: entry.read ? Colors.white : soft.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: _ink.withValues(alpha: 0.045),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [soft, Color.lerp(soft, Colors.white, 0.15)!],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.18),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: Icon(icon, size: 19, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            entry.title,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: _ink,
                            ),
                          ),
                        ),
                        Text(
                          relativeTime,
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: _inkSub,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      entry.body,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        color: _inkSub,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              InkWell(
                onTap: () => NotificationHistoryService().delete(uid, entry.id),
                borderRadius: BorderRadius.circular(20),
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.close_rounded, size: 16, color: _inkSub),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
