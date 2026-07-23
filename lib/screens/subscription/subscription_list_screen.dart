import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:simple_icons/simple_icons.dart';


import '../../models/subscription_model.dart';
import '../../services/subscription_service.dart';
import 'subscription_add_screen.dart';
import 'subscription_edit_screen.dart';

// 앱 공통 핑크 테마 컬러 (홈 화면 퀵메뉴에서 구독관리 = 핑크로 지정됨)
const Color _mainColor = Color(0xFFFF6F91);
const Color _mainSoftColor = Color(0xFFFFE3EC);
const Color _mainBorderSoftColor = Color(0xFFFFD3E0);

class SubscriptionListScreen extends StatefulWidget {
  final String userId;

  const SubscriptionListScreen({
    super.key,
    required this.userId,
  });

  @override
  State<SubscriptionListScreen> createState() =>
      _SubscriptionListScreenState();
}

class _SubscriptionListScreenState extends State<SubscriptionListScreen> {
  final SubscriptionService _service = SubscriptionService();

  bool _paymentAlert = true;
  bool _trialAlert = true;
  bool _annualAlert = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F7FA),
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        backgroundColor: const Color(0xFFF8F7FA),
        surfaceTintColor: Colors.transparent,
        foregroundColor: const Color(0xFF222222),
        title: const Text(
          '구독/결제일 알림',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: CircleAvatar(
              radius: 17,
              backgroundColor: _mainSoftColor,
              child: Icon(
                Icons.notifications_rounded,
                size: 18,
                color: _mainColor,
              ),
            ),
          ),
        ],
      ),
      body: StreamBuilder<List<SubscriptionModel>>(
        stream: _service.getSubscriptions(widget.userId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                color: _mainColor,
              ),
            );
          }

          if (snapshot.hasError) {
            return _ErrorView(message: '${snapshot.error}');
          }

          final subscriptions = snapshot.data ?? [];
          final active =
          subscriptions.where((item) => item.isActive).toList();

          final total = active.fold<int>(
            0,
                (sum, item) => sum + item.amount,
          );

          final next = _findNext(active);
          final nextDays =
          next == null ? 0 : _daysUntilPayment(next.paymentDay);

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 110),
            children: [
              _SummaryCard(
                totalAmount: total,
                activeCount: active.length,
                nextAmount: next?.amount ?? 0,
                nextDays: nextDays,
              ),
              if (next != null) ...[
                const SizedBox(height: 14),
                _PaymentAlertCard(
                  subscription: next,
                  days: nextDays,
                ),
              ],
              const SizedBox(height: 14),
              _CalendarCard(subscriptions: active),
              const SizedBox(height: 14),
              _SectionCard(
                child: _SubscriptionSection(
                  subscriptions: subscriptions,
                  onAdd: _openAdd,
                  onEdit: _openEdit,
                  onDelete: _confirmDelete,
                ),
              ),
              const SizedBox(height: 14),
              _SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '알림 설정',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF222222),
                      ),
                    ),
                    _AlertSwitch(
                      title: '결제 하루 전 알림',
                      value: _paymentAlert,
                      onChanged: (value) {
                        setState(() => _paymentAlert = value);
                      },
                    ),
                    _AlertSwitch(
                      title: '무료 체험 종료 알림',
                      value: _trialAlert,
                      onChanged: (value) {
                        setState(() => _trialAlert = value);
                      },
                    ),
                    _AlertSwitch(
                      title: '연간 결제 경고',
                      value: _annualAlert,
                      onChanged: (value) {
                        setState(() => _annualAlert = value);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const _ReportCard(),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openAdd,
        backgroundColor: _mainColor,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(17),
        ),
        child: const Icon(Icons.add_rounded),
      ),
    );
  }

  SubscriptionModel? _findNext(List<SubscriptionModel> items) {
    if (items.isEmpty) return null;

    final sorted = [...items]
      ..sort(
            (a, b) => _daysUntilPayment(
          a.paymentDay,
        ).compareTo(
          _daysUntilPayment(b.paymentDay),
        ),
      );

    return sorted.first;
  }

  int _daysUntilPayment(int paymentDay) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final currentLastDay = DateTime(now.year, now.month + 1, 0).day;
    final safeDay = paymentDay.clamp(1, currentLastDay);

    var target = DateTime(now.year, now.month, safeDay);

    if (target.isBefore(today)) {
      final nextMonth = DateTime(now.year, now.month + 1, 1);
      final nextLastDay =
          DateTime(nextMonth.year, nextMonth.month + 1, 0).day;

      target = DateTime(
        nextMonth.year,
        nextMonth.month,
        paymentDay.clamp(1, nextLastDay),
      );
    }

    return target.difference(today).inDays;
  }

  void _openAdd() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SubscriptionAddScreen(userId: widget.userId),
      ),
    );
  }

  void _openEdit(SubscriptionModel subscription) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SubscriptionEditScreen(
          userId: widget.userId,
          subscription: subscription,
        ),
      ),
    );
  }

  Future<void> _confirmDelete(SubscriptionModel subscription) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text(
          '구독 삭제',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: Color(0xFF222222),
          ),
        ),
        content: Text(
          '${subscription.name} 구독을 삭제하시겠습니까?',
          style: const TextStyle(
            fontSize: 13,
            color: Color(0xFF555555),
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF999999),
            ),
            child: const Text('취소'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFE0483C),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );

    if (result != true) return;

    try {
      await _service.deleteSubscription(
        userId: widget.userId,
        subscriptionId: subscription.id,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('구독이 삭제되었습니다.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('구독 삭제 중 오류가 발생했습니다.\n$e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}

class _SummaryCard extends StatelessWidget {
  final int totalAmount;
  final int activeCount;
  final int nextAmount;
  final int nextDays;

  const _SummaryCard({
    required this.totalAmount,
    required this.activeCount,
    required this.nextAmount,
    required this.nextDays,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFF6F91), Color(0xFFFF9AB0)],
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '이번 달 고정 구독비',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${formatAmount(totalAmount)}원',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _SummaryItem(label: '이용 중', value: '$activeCount개'),
              const SizedBox(width: 8),
              _SummaryItem(
                label: '다음 결제',
                value: nextAmount == 0 ? '-' : 'D-$nextDays',
              ),
              const SizedBox(width: 8),
              _SummaryItem(
                label: '결제 예정',
                value: '${formatAmount(nextAmount)}원',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryItem({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.18),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 10,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaymentAlertCard extends StatelessWidget {
  final SubscriptionModel subscription;
  final int days;

  const _PaymentAlertCard({
    required this.subscription,
    required this.days,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _mainSoftColor,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            backgroundColor: _mainColor,
            child: Icon(
              Icons.warning_amber_rounded,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '${days == 0 ? '오늘' : '$days일 후'} '
                  '${subscription.name} '
                  '${formatAmount(subscription.amount)}원 결제 예정',
              style: const TextStyle(
                color: Color(0xFFC63A5C),
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CalendarCard extends StatelessWidget {
  final List<SubscriptionModel> subscriptions;

  const _CalendarCard({
    required this.subscriptions,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final paymentDays =
    subscriptions.map((item) => item.paymentDay).toSet();

    final dates = List.generate(
      7,
          (index) => now.add(Duration(days: index - 2)),
    );

    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '결제 캘린더 · ${now.month}월',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: Color(0xFF222222),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 70,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: dates.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, index) {
                final date = dates[index];
                final isToday =
                    date.year == now.year &&
                        date.month == now.month &&
                        date.day == now.day;

                return Container(
                  width: 46,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: isToday
                        ? _mainColor
                        : const Color(0xFFF6F7FA),
                    borderRadius: BorderRadius.circular(14),
                    border: paymentDays.contains(date.day) && !isToday
                        ? Border.all(color: _mainBorderSoftColor)
                        : null,
                  ),
                  child: Column(
                    children: [
                      Text(
                        _weekDay(date.weekday),
                        style: TextStyle(
                          color: isToday
                              ? Colors.white70
                              : const Color(0xFF9A9DA5),
                          fontSize: 10,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        '${date.day}',
                        style: TextStyle(
                          color: isToday
                              ? Colors.white
                              : const Color(0xFF33353A),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      CircleAvatar(
                        radius: 2.5,
                        backgroundColor: paymentDays.contains(date.day)
                            ? (isToday ? Colors.white : _mainColor)
                            : Colors.transparent,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  static String _weekDay(int weekday) {
    const days = ['월', '화', '수', '목', '금', '토', '일'];
    return days[weekday - 1];
  }
}

class _SubscriptionSection extends StatelessWidget {
  final List<SubscriptionModel> subscriptions;
  final VoidCallback onAdd;
  final ValueChanged<SubscriptionModel> onEdit;
  final ValueChanged<SubscriptionModel> onDelete;

  const _SubscriptionSection({
    required this.subscriptions,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                '내 구독 목록',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF222222),
                ),
              ),
            ),
            TextButton(
              onPressed: onAdd,
              style: TextButton.styleFrom(
                foregroundColor: _mainColor,
              ),
              child: const Text(
                '추가',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        if (subscriptions.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 30),
            child: Center(
              child: Column(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: const BoxDecoration(
                      color: _mainSoftColor,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.subscriptions_rounded,
                      size: 30,
                      color: _mainColor,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '등록된 구독이 없습니다.',
                    style: TextStyle(
                      color: Color(0xFF555555),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    height: 46,
                    child: FilledButton.icon(
                      onPressed: onAdd,
                      style: FilledButton.styleFrom(
                        backgroundColor: _mainColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text(
                        '구독 추가',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          ...subscriptions.map(
                (subscription) => Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: _SubscriptionTile(
                subscription: subscription,
                onEdit: () => onEdit(subscription),
                onDelete: () => onDelete(subscription),
              ),
            ),
          ),
      ],
    );
  }
}

class _SubscriptionTile extends StatelessWidget {
  final SubscriptionModel subscription;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _SubscriptionTile({
    required this.subscription,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final visual = SubscriptionIconResolver.resolve(subscription.name);

    return Material(
      color: const Color(0xFFF7F8FB),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onEdit,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: visual.background,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  visual.icon,
                  color: visual.foreground,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      subscription.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: subscription.isActive
                            ? const Color(0xFF25272C)
                            : const Color(0xFF9CA0A8),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '매월 ${subscription.paymentDay}일 결제',
                      style: const TextStyle(
                        color: Color(0xFF9A9DA5),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${formatAmount(subscription.amount)}원',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              PopupMenuButton<String>(
                icon: const Icon(
                  Icons.more_vert_rounded,
                  color: Color(0xFF999999),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                color: Colors.white,
                onSelected: (value) {
                  if (value == 'edit') onEdit();
                  if (value == 'delete') onDelete();
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(
                          Icons.edit_outlined,
                          size: 18,
                          color: _mainColor,
                        ),
                        SizedBox(width: 10),
                        Text('수정', style: TextStyle(fontSize: 13)),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(
                          Icons.delete_outline_rounded,
                          size: 18,
                          color: Color(0xFFE0483C),
                        ),
                        SizedBox(width: 10),
                        Text('삭제', style: TextStyle(fontSize: 13)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SubscriptionIconResolver {
  static ServiceVisual resolve(String serviceName) {
    final name = serviceName
        .toLowerCase()
        .replaceAll(' ', '')
        .replaceAll('-', '')
        .replaceAll('_', '');

    for (final item in _brands) {
      if (item.keywords.any(name.contains)) return item.visual;
    }

    return const ServiceVisual(
      icon: Icons.subscriptions_rounded,
      background: _mainColor,
    );
  }

  static final List<_BrandRule> _brands = [
    const _BrandRule(
      ['넷플릭스', 'netflix'],
      ServiceVisual(
        icon: SimpleIcons.netflix,
        background: Color(0xFFE50914),
      ),
    ),
    const _BrandRule(
      ['유튜브', 'youtube'],
      ServiceVisual(
        icon: SimpleIcons.youtube,
        background: Color(0xFFFF0000),
      ),
    ),
    const _BrandRule(
      ['디즈니플러스', '디즈니+', 'disneyplus', 'disney'],
      ServiceVisual(
        icon: Icons.castle_rounded,
        background: Color(0xFF113CCF),
      ),
    ),
    const _BrandRule(
      ['스포티파이', 'spotify'],
      ServiceVisual(
        icon: SimpleIcons.spotify,
        background: Color(0xFF1DB954),
      ),
    ),
    const _BrandRule(
      ['애플뮤직', 'applemusic'],
      ServiceVisual(
        icon: SimpleIcons.applemusic,
        background: Color(0xFFFA2D48),
      ),
    ),
    const _BrandRule(
      ['노션', 'notion'],
      ServiceVisual(
        icon: SimpleIcons.notion,
        background: Color(0xFF111111),
      ),
    ),
    const _BrandRule(
      ['깃허브', 'github'],
      ServiceVisual(
        icon: SimpleIcons.github,
        background: Color(0xFF181717),
      ),
    ),
    const _BrandRule(
      ['피그마', 'figma'],
      ServiceVisual(
        icon: SimpleIcons.figma,
        background: Color(0xFFF24E1E),
      ),
    ),
    const _BrandRule(
      ['챗지피티', 'chatgpt', 'openai'],
      ServiceVisual(
        icon: Icons.auto_awesome_rounded,
        background: Color(0xFF111111),
      ),
    ),
    const _BrandRule(
      ['티빙', 'tving'],
      ServiceVisual(
        icon: Icons.live_tv_rounded,
        background: Color(0xFFFF153C),
      ),
    ),
    const _BrandRule(
      ['웨이브', 'wavve'],
      ServiceVisual(
        icon: Icons.waves_rounded,
        background: Color(0xFF1351F9),
      ),
    ),
    const _BrandRule(
      ['왓챠', 'watcha'],
      ServiceVisual(
        icon: Icons.movie_filter_rounded,
        background: Color(0xFFFF0558),
      ),
    ),
    const _BrandRule(
      ['쿠팡플레이', 'coupangplay'],
      ServiceVisual(
        icon: Icons.play_circle_fill_rounded,
        background: Color(0xFF00A8E8),
      ),
    ),
    const _BrandRule(
      ['라프텔', 'laftel'],
      ServiceVisual(
        icon: Icons.animation_rounded,
        background: Color(0xFF816BFF),
      ),
    ),
    const _BrandRule(
      ['멜론', 'melon'],
      ServiceVisual(
        icon: Icons.music_note_rounded,
        background: Color(0xFF00CD3C),
      ),
    ),
    const _BrandRule(
      ['지니뮤직', '지니'],
      ServiceVisual(
        icon: Icons.headphones_rounded,
        background: Color(0xFF25B9D7),
      ),
    ),
    const _BrandRule(
      ['벅스', 'bugs'],
      ServiceVisual(
        icon: Icons.library_music_rounded,
        background: Color(0xFFFF4B45),
      ),
    ),
    const _BrandRule(
      ['플로', 'flo'],
      ServiceVisual(
        icon: Icons.graphic_eq_rounded,
        background: Color(0xFF6F4BFF),
      ),
    ),
    const _BrandRule(
      ['바이브', 'vibe'],
      ServiceVisual(
        icon: Icons.equalizer_rounded,
        background: Color(0xFF7B37FF),
      ),
    ),
    const _BrandRule(
      ['쿠팡와우', '로켓와우', 'coupang'],
      ServiceVisual(
        icon: Icons.local_shipping_rounded,
        background: Color(0xFF346AFF),
      ),
    ),
    const _BrandRule(
      ['네이버플러스', '네이버멤버십'],
      ServiceVisual(
        icon: Icons.workspace_premium_rounded,
        background: Color(0xFF03C75A),
      ),
    ),
    const _BrandRule(
      ['컬리멤버스', '마켓컬리', 'kurly'],
      ServiceVisual(
        icon: Icons.shopping_bag_rounded,
        background: Color(0xFF5F0080),
      ),
    ),
    const _BrandRule(
      ['배민클럽', '배달의민족', '배민'],
      ServiceVisual(
        icon: Icons.delivery_dining_rounded,
        background: Color(0xFF2AC1BC),
      ),
    ),
    const _BrandRule(
      ['요기패스', '요기요'],
      ServiceVisual(
        icon: Icons.delivery_dining_rounded,
        background: Color(0xFFFA0050),
      ),
    ),
    const _BrandRule(
      ['밀리의서재', '밀리'],
      ServiceVisual(
        icon: Icons.menu_book_rounded,
        background: Color(0xFFFFE500),
        foreground: Color(0xFF222222),
      ),
    ),
    const _BrandRule(
      ['리디셀렉트', '리디북스', '리디'],
      ServiceVisual(
        icon: Icons.auto_stories_rounded,
        background: Color(0xFF1E9EFF),
      ),
    ),
    const _BrandRule(
      ['윌라', '오디오북'],
      ServiceVisual(
        icon: Icons.headset_rounded,
        background: Color(0xFF6C4BF4),
      ),
    ),
    const _BrandRule(
      ['구글원', '구글드라이브'],
      ServiceVisual(
        icon: Icons.cloud_rounded,
        background: Color(0xFF4285F4),
      ),
    ),
    const _BrandRule(
      ['아이클라우드', 'icloud'],
      ServiceVisual(
        icon: Icons.cloud_rounded,
        background: Color(0xFF3693F3),
      ),
    ),
  ];
}

class _BrandRule {
  final List<String> keywords;
  final ServiceVisual visual;

  const _BrandRule(this.keywords, this.visual);
}

class ServiceVisual {
  final IconData icon;
  final Color background;
  final Color foreground;

  const ServiceVisual({
    required this.icon,
    required this.background,
    this.foreground = Colors.white,
  });
}

class _AlertSwitch extends StatelessWidget {
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _AlertSwitch({
    required this.title,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF444444),
              ),
            ),
          ),
          Transform.scale(
            scale: 0.85,
            child: CupertinoSwitch(
              value: value,
              onChanged: onChanged,
              activeTrackColor: _mainColor,
              inactiveTrackColor: const Color(0xFFE3E3E8),
              trackOutlineColor: const WidgetStatePropertyAll(
                Colors.transparent,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: _mainSoftColor,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: _mainBorderSoftColor),
      ),
      child: const Row(
        children: [
          CircleAvatar(
            backgroundColor: _mainColor,
            child: Icon(Icons.auto_graph_rounded, color: Colors.white),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              '구독 소비 리포트\n이번 달 구독료 변화를 확인해 보세요.',
              style: TextStyle(
                color: Color(0xFFC63A5C),
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: _mainColor),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final Widget child;

  const _SectionCard({
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFF0EDF0),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 14,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;

  const _ErrorView({
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          '구독 목록을 불러오지 못했습니다.\n$message',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFF555555),
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

String formatAmount(int amount) {
  return amount.toString().replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
        (match) => '${match[1]},',
  );
}