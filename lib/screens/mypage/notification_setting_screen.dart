import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/user_model.dart';
import '../../services/notification_service.dart';
import '../../services/subscription_service.dart';
import '../../services/user_service.dart';

const _accent = Color(0xFFF5A623);
const _accentSoft = Color(0xFFFFF0A6);
const _ink = Color(0xFF221A16);
const _inkSub = Color(0xFF8A7E77);
const _bg = Color(0xFFFAF8F6);

const _blue = Color(0xFF2F6BFF);
const _blueSoft = Color(0xFFEEF4FF);
const _coral = Color(0xFFFF6F61);
const _coralSoft = Color(0xFFFFE8E4);

class NotificationSettingScreen extends StatefulWidget {
  const NotificationSettingScreen({super.key});

  @override
  State<NotificationSettingScreen> createState() => _NotificationSettingScreenState();
}

class _NotificationSettingScreenState extends State<NotificationSettingScreen> {
  final _userService = UserService();
  String get _uid => FirebaseAuth.instance.currentUser!.uid;

  // 방해금지 시간대 — 기기 로컬 설정(SharedPreferences)이라 Firestore의
  // NotificationSettings와 별개로 관리한다. null이면 아직 로딩 중.
  bool? _dndEnabled;
  int _dndStartMinutes = 22 * 60;
  int _dndEndMinutes = 7 * 60;

  @override
  void initState() {
    super.initState();
    _loadDndSettings();
    // 마이페이지 "시작하기 체크리스트"의 "알림 설정 확인하기" 항목용 방문 기록.
    SharedPreferences.getInstance()
        .then((prefs) => prefs.setBool('visitedNotificationSettings', true));
  }

  Future<void> _loadDndSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _dndEnabled = prefs.getBool('dndEnabled') ?? false;
      _dndStartMinutes = prefs.getInt('dndStartMinutes') ?? 22 * 60;
      _dndEndMinutes = prefs.getInt('dndEndMinutes') ?? 7 * 60;
    });
  }

  Future<void> _toggleDnd(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('dndEnabled', value);
    if (mounted) setState(() => _dndEnabled = value);
  }

  Future<void> _pickDndTime({required bool isStart}) async {
    final initial = isStart ? _dndStartMinutes : _dndEndMinutes;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: initial ~/ 60, minute: initial % 60),
    );
    if (picked == null) return;
    final minutes = picked.hour * 60 + picked.minute;
    final prefs = await SharedPreferences.getInstance();
    if (isStart) {
      await prefs.setInt('dndStartMinutes', minutes);
      if (mounted) setState(() => _dndStartMinutes = minutes);
    } else {
      await prefs.setInt('dndEndMinutes', minutes);
      if (mounted) setState(() => _dndEndMinutes = minutes);
    }
  }

  Future<void> _toggle(NotificationSettings current, {
    bool? fixedExpenseAlert,
    bool? subscriptionAlert,
    bool? cardPointExpiryAlert,
  }) async {
    await _userService.updateNotificationSettings(
      _uid,
      current.copyWith(
        fixedExpenseAlert: fixedExpenseAlert,
        subscriptionAlert: subscriptionAlert,
        cardPointExpiryAlert: cardPointExpiryAlert,
      ),
    );
    if (subscriptionAlert != null) await _syncSubscriptionReminders(subscriptionAlert);
  }

  Future<void> _toggleAll(NotificationSettings current, bool value) async {
    await _userService.updateNotificationSettings(
      _uid,
      current.copyWith(
        fixedExpenseAlert: value,
        subscriptionAlert: value,
        cardPointExpiryAlert: value,
      ),
    );
    await _syncSubscriptionReminders(value);
  }

  /// 토글을 켜고 끌 때 다음 날까지 기다리지 않고 바로 알림 예약을 반영한다.
  Future<void> _syncSubscriptionReminders(bool enabled) async {
    final subs = await SubscriptionService().getSubscriptions(_uid).first;
    await NotificationService.instance.syncSubscriptionReminders(
      enabled: enabled,
      activeSubscriptions: subs.where((s) => s.isActive).toList(),
    );
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
        title: const Text('알림 설정', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: StreamBuilder<UserModel?>(
        stream: _userService.watchUser(_uid),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator(color: _accent));
          }
          final settings = snapshot.data!.notificationSettings;
          final allOn = settings.fixedExpenseAlert &&
              settings.subscriptionAlert &&
              settings.cardPointExpiryAlert;
          final allOff = !settings.fixedExpenseAlert &&
              !settings.subscriptionAlert &&
              !settings.cardPointExpiryAlert;

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Text('땡그랑이 챙겨드릴 알림을 골라주세요',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: _inkSub)),
              const SizedBox(height: 14),

              _MasterTile(
                allOn: allOn,
                mixed: !allOn && !allOff,
                onChanged: (v) => _toggleAll(settings, v),
              ),
              const SizedBox(height: 18),
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 10),
                child: Text('알림 종류',
                    style:
                    TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: _inkSub)),
              ),

              _SettingTile(
                icon: Icons.receipt_long_rounded,
                iconBg: _blueSoft,
                iconColor: _blue,
                title: '고정비 알림',
                subtitle: '월세·공과금 등 고정 지출일이 다가오면 알려드려요',
                value: settings.fixedExpenseAlert,
                onChanged: (v) => _toggle(settings, fixedExpenseAlert: v),
              ),
              const SizedBox(height: 10),
              _SettingTile(
                icon: Icons.autorenew_rounded,
                iconBg: _accentSoft,
                iconColor: _accent,
                title: '구독 알림',
                subtitle: 'OTT·정기결제 갱신일 전에 미리 알려드려요',
                value: settings.subscriptionAlert,
                onChanged: (v) => _toggle(settings, subscriptionAlert: v),
              ),
              const SizedBox(height: 10),
              _SettingTile(
                icon: Icons.card_giftcard_rounded,
                iconBg: _coralSoft,
                iconColor: _coral,
                title: '카드포인트 만료 알림',
                subtitle: '보유 중인 카드포인트 소멸 임박 시 알려드려요',
                value: settings.cardPointExpiryAlert,
                onChanged: (v) => _toggle(settings, cardPointExpiryAlert: v),
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 10),
                child: Text('방해금지 시간대',
                    style:
                    TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: _inkSub)),
              ),
              _QuietHoursTile(
                enabled: _dndEnabled ?? false,
                startMinutes: _dndStartMinutes,
                endMinutes: _dndEndMinutes,
                onToggle: _dndEnabled == null ? null : _toggleDnd,
                onPickStart: () => _pickDndTime(isStart: true),
                onPickEnd: () => _pickDndTime(isStart: false),
              ),
            ]
                .animate(interval: 60.ms)
                .fadeIn(duration: 340.ms, curve: Curves.easeOut)
                .slideY(begin: 0.06, end: 0, curve: Curves.easeOutCubic),
          );
        },
      ),
    );
  }
}

class _MasterTile extends StatelessWidget {
  final bool allOn;
  final bool mixed;
  final ValueChanged<bool> onChanged;
  const _MasterTile({required this.allOn, required this.mixed, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_accent, Color(0xFFFF8A50)],
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
              color: _accent.withValues(alpha: 0.28), blurRadius: 18, offset: const Offset(0, 8)),
        ],
      ),
      // 텍스트를 포함한 콘텐츠는 ClipRRect로 감싸지 않는다 — home_screen.dart의
      // _BudgetHero에서 확인된 렌더링 버그(ClipRRect가 그 안의 텍스트 첫 글자를
      // 깨뜨림)를 피하기 위해, 둥근 모서리는 바깥 Container의 BoxDecoration만으로
      // 처리하고 장식 원은 클리핑 없이 살짝 넘치게 둔다.
      child: Stack(
          children: [
            Positioned(
              top: -30,
              right: -20,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [Colors.white.withValues(alpha: 0.18), Colors.white.withValues(alpha: 0.0)],
                  ),
                ),
              ),
            ),
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.22), shape: BoxShape.circle),
                  alignment: Alignment.center,
                  child: const Icon(Icons.notifications_active_rounded,
                      color: Colors.white, size: 20),
                )
                    .animate(onPlay: (c) => c.repeat(reverse: true))
                    .rotate(begin: -0.03, end: 0.03, duration: 1400.ms, curve: Curves.easeInOut),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('전체 알림',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white)),
                      const SizedBox(height: 2),
                      Text(mixed ? '일부 알림이 꺼져 있어요' : (allOn ? '모두 켜져 있어요' : '모두 꺼져 있어요'),
                          style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w500,
                              color: Colors.white.withValues(alpha: 0.8))),
                    ],
                  ),
                ),
                Switch(
                  value: allOn,
                  onChanged: onChanged,
                  activeThumbColor: Colors.white,
                  activeTrackColor: Colors.white.withValues(alpha: 0.35),
                  inactiveThumbColor: Colors.white,
                  inactiveTrackColor: Colors.white.withValues(alpha: 0.25),
                ),
              ],
            ),
          ],
        ),
    );
  }
}

class _QuietHoursTile extends StatelessWidget {
  final bool enabled;
  final int startMinutes;
  final int endMinutes;
  final ValueChanged<bool>? onToggle;
  final VoidCallback onPickStart;
  final VoidCallback onPickEnd;

  const _QuietHoursTile({
    required this.enabled,
    required this.startMinutes,
    required this.endMinutes,
    required this.onToggle,
    required this.onPickStart,
    required this.onPickEnd,
  });

  String _format(int minutes) {
    final h = (minutes ~/ 60).toString().padLeft(2, '0');
    final m = (minutes % 60).toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: _ink.withValues(alpha: 0.045), blurRadius: 14, offset: const Offset(0, 5)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFEDE9FE), Color.lerp(const Color(0xFFEDE9FE), Colors.white, 0.15)!],
                  ),
                  boxShadow: const [
                    BoxShadow(
                        color: Color(0x296C5CE7), blurRadius: 8, offset: Offset(0, 3)),
                  ],
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.bedtime_rounded, size: 19, color: Color(0xFF6C5CE7)),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('방해금지 시간대',
                        style: TextStyle(
                            fontSize: 14.5, fontWeight: FontWeight.w700, color: _ink)),
                    SizedBox(height: 3),
                    Text('이 시간엔 다짐·잔소리 같은 가벼운 알림을 미뤄요',
                        style: TextStyle(
                            fontSize: 11.5, fontWeight: FontWeight.w500, color: _inkSub, height: 1.4)),
                  ],
                ),
              ),
              Switch(value: enabled, onChanged: onToggle, activeThumbColor: _accent),
            ],
          ),
          if (enabled) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(child: _TimeButton(label: '시작', time: _format(startMinutes), onTap: onPickStart)),
                const SizedBox(width: 10),
                Expanded(child: _TimeButton(label: '종료', time: _format(endMinutes), onTap: onPickEnd)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _TimeButton extends StatelessWidget {
  final String label;
  final String time;
  final VoidCallback onTap;
  const _TimeButton({required this.label, required this.time, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(color: _bg, borderRadius: BorderRadius.circular(12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: _inkSub)),
            const SizedBox(height: 2),
            Text(time, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _ink)),
          ],
        ),
      ),
    );
  }
}

class _SettingTile extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SettingTile({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: _ink.withValues(alpha: 0.045), blurRadius: 14, offset: const Offset(0, 5)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [iconBg, Color.lerp(iconBg, Colors.white, 0.15)!],
              ),
              boxShadow: [
                BoxShadow(
                    color: iconColor.withValues(alpha: 0.16),
                    blurRadius: 8,
                    offset: const Offset(0, 3)),
              ],
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 19, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 14.5, fontWeight: FontWeight.w700, color: _ink)),
                const SizedBox(height: 3),
                Text(subtitle,
                    style: const TextStyle(
                        fontSize: 11.5, fontWeight: FontWeight.w500, color: _inkSub, height: 1.4)),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged, activeThumbColor: _accent),
        ],
      ),
    );
  }
}
