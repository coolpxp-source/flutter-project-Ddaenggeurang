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

/// 알림함 필터 — "전체"는 null(필터 없음), 나머지는 알림 type 값과 매칭
class _NotificationFilter {
  final String label;
  final String? type;
  const _NotificationFilter(this.label, this.type);
}

const _filters = [
  _NotificationFilter('전체', null),
  _NotificationFilter('좋아요', 'post_like'),
  _NotificationFilter('댓글', 'post_comment'),
  _NotificationFilter('채팅', 'chat_message'),
  _NotificationFilter('찜', 'product_favorite'),
  _NotificationFilter('다짐', 'resolution'),
  _NotificationFilter('AI 잔소리', 'nagging'),
  _NotificationFilter('AI 상담', 'consult'),
];

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

  String? _selectedType; // null = 전체

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
      case 'post_like':
        return (
        Icons.favorite_rounded,
        const Color(0xFFEE5586),
        const Color(0xFFFFE3EC),
        );
      case 'post_comment':
        return (
        Icons.mode_comment_rounded,
        const Color(0xFF5B9BD5),
        const Color(0xFFEAF2FA),
        );
      case 'chat_message':
        return (
        Icons.chat_bubble_rounded,
        const Color(0xFF00A86B),
        const Color(0xFFE0F7EC),
        );
      case 'product_favorite':
        return (
        Icons.storefront_rounded,
        const Color(0xFFFF8A3D),
        const Color(0xFFFFF0E8),
        );
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
          Column(
            children: [
              _buildFilterBar(),
              Expanded(
                child: StreamBuilder<List<NotificationEntry>>(
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
                    final allItems = snap.data!;
                    WidgetsBinding.instance.addPostFrameCallback(
                          (_) => _markAllRead(allItems),
                    );

                    final items = _selectedType == null
                        ? allItems
                        : allItems.where((e) => e.type == _selectedType).toList();

                    if (allItems.isEmpty) {
                      return const _EmptyHistory();
                    }

                    if (items.isEmpty) {
                      return _buildEmptyFilterResult();
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
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
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 알림 타입별 필터 칩 (전체/좋아요/댓글/채팅/찜)
  Widget _buildFilterBar() {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
        itemCount: _filters.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final filter = _filters[i];
          final selected = _selectedType == filter.type;

          return GestureDetector(
            onTap: () => setState(() => _selectedType = filter.type),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: selected ? _accent : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: selected ? _accent : Colors.grey[300]!,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                filter.label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                  color: selected ? Colors.white : Colors.grey[600],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyFilterResult() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.filter_list_off_rounded, size: 40, color: _inkSub),
            const SizedBox(height: 12),
            const Text(
              '해당 알림이 없어요',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _ink),
            ),
          ],
        ),
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