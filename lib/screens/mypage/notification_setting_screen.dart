import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/user_model.dart';
import '../../services/user_service.dart';

const _accent = Color(0xFFF5A623);
const _accentSoft = Color(0xFFFFF0A6);
const _ink = Color(0xFF221A16);
const _inkSub = Color(0xFF8A7E77);
const _bg = Color(0xFFFAF8F6);
const _line = Color(0xFFF0E9E4);

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

  Future<void> _toggle(NotificationSettings current, {
    bool? fixedExpenseAlert,
    bool? subscriptionAlert,
    bool? cardPointExpiryAlert,
  }) {
    return _userService.updateNotificationSettings(
      _uid,
      current.copyWith(
        fixedExpenseAlert: fixedExpenseAlert,
        subscriptionAlert: subscriptionAlert,
        cardPointExpiryAlert: cardPointExpiryAlert,
      ),
    );
  }

  Future<void> _toggleAll(NotificationSettings current, bool value) {
    return _userService.updateNotificationSettings(
      _uid,
      current.copyWith(
        fixedExpenseAlert: value,
        subscriptionAlert: value,
        cardPointExpiryAlert: value,
      ),
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
            ],
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
      ),
      child: Row(
        children: [
          const Icon(Icons.notifications_active_rounded, color: Colors.white, size: 22),
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
                        color: Colors.white.withOpacity(0.8))),
              ],
            ),
          ),
          Switch(
            value: allOn,
            onChanged: onChanged,
            activeThumbColor: Colors.white,
            activeTrackColor: Colors.white.withOpacity(0.35),
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: Colors.white.withOpacity(0.25),
          ),
        ],
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
        border: Border.all(color: _line),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
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
