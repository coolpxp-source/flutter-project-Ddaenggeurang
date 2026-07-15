import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/user_service.dart';
import '../../widgets/common/ddaeng_modal.dart';
import '../avatar/my_avatar_screen.dart';
import '../avatar/point_shop_screen.dart';
import '../mission/mission_list_screen.dart';
import '../../widgets/common/Placeholder_screen.dart';
import 'coach_tone_setting_screen.dart';
import 'notification_setting_screen.dart';
import 'profile_edit_screen.dart';
import 'setting_screen.dart';

// 마이페이지 홈 — AppBar/BottomNav 없이 body만 그리는 위젯.
// home_screen.dart의 NavTab.myPage 탭 바디로 그대로 끼워 넣는다
// (_HomeDashboard / AiConsultScreen과 동일한 패턴).

const _accent = Color(0xFFF5A623);
const _accentSoft = Color(0xFFFFF0A6);
const _ink = Color(0xFF221A16);
const _inkSub = Color(0xFF8A7E77);
const _bg = Color(0xFFFAF8F6);
const _line = Color(0xFFF0E9E4);

// 홈 대시보드와 동일한 팔레트 — 메뉴 항목마다 성격에 맞는 색을 줘서
// 화면 간 톤을 통일한다.
const _amberDeep = Color(0xFF8A5200);
const _amberSoft = Color(0xFFFFF3DE);
const _blue = Color(0xFF4F7DF3);
const _blueSoft = Color(0xFFE8EFFE);
const _pink = Color(0xFFFF6F91);
const _pinkSoft = Color(0xFFFFE3EC);
const _purple = Color(0xFF6C5CE7);
const _purpleSoft = Color(0xFFEDE9FE);

class MyPageHomeScreen extends StatelessWidget {
  const MyPageHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    return Container(
      color: _bg,
      child: StreamBuilder<UserModel?>(
        stream: UserService().watchUser(uid),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator(color: _accent));
          }
          final user = snapshot.data!;
          final joinedDays = user.createdAt == null
              ? 0
              : DateTime.now().difference(user.createdAt!).inDays;

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ProfileCard(user: user, joinedDays: joinedDays),
                const SizedBox(height: 24),

                _MenuGroup(children: [
                  _MenuRow(
                    icon: Icons.bar_chart_rounded,
                    title: '월간 소비 통계',
                    subtitle: '카테고리별 지출 흐름 한눈에 보기',
                    iconColor: _blue,
                    iconBg: _blueSoft,
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => const PlaceholderScreen(title: '월간 소비 통계'))),
                  ),
                  _MenuRow(
                    icon: Icons.face_retouching_natural_rounded,
                    title: '아바타 꾸미기',
                    subtitle: '${user.coachTone.emoji} 캐릭터 커스터마이징',
                    iconColor: _purple,
                    iconBg: _purpleSoft,
                    onTap: () => Navigator.of(context)
                        .push(MaterialPageRoute(builder: (_) => const MyAvatarScreen())),
                  ),
                  _MenuRow(
                    icon: Icons.storefront_rounded,
                    title: '포인트 상점',
                    subtitle: '${user.points}P 보유',
                    iconColor: _amberDeep,
                    iconBg: _amberSoft,
                    onTap: () => Navigator.of(context)
                        .push(MaterialPageRoute(builder: (_) => const PointShopScreen())),
                  ),
                  _MenuRow(
                    icon: Icons.flag_rounded,
                    title: '예산 미션 기록',
                    subtitle: '출석하고 예산 지키면 포인트 적립',
                    iconColor: _pink,
                    iconBg: _pinkSoft,
                    onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const MissionListScreen())),
                  ),
                  _MenuRow(
                    icon: Icons.person_outline_rounded,
                    title: '프로필 수정',
                    subtitle: '닉네임 · 수입 · 연령대 · 직군',
                    iconColor: _amberDeep,
                    iconBg: _amberSoft,
                    onTap: () => Navigator.of(context)
                        .push(MaterialPageRoute(builder: (_) => const ProfileEditScreen())),
                  ),
                  _MenuRow(
                    icon: Icons.notifications_none_rounded,
                    title: '구독/결제일 알림',
                    subtitle: '고정비 · 구독 · 카드포인트 알림',
                    iconColor: _blue,
                    iconBg: _blueSoft,
                    onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const NotificationSettingScreen())),
                  ),
                  _MenuRow(
                    icon: Icons.record_voice_over_rounded,
                    title: '잔소리 캐릭터 설정',
                    subtitle:
                    '${user.coachTone.emoji} ${user.coachTone.label} · ${user.coachTone.title}',
                    iconColor: _purple,
                    iconBg: _purpleSoft,
                    onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const CoachToneSettingScreen())),
                  ),
                  _MenuRow(
                    icon: Icons.settings_outlined,
                    title: '설정',
                    subtitle: '로그아웃 · 회원탈퇴 · 앱 정보',
                    onTap: () => Navigator.of(context)
                        .push(MaterialPageRoute(builder: (_) => const SettingScreen())),
                    showDivider: false,
                  ),
                ]),
                const SizedBox(height: 28),

                Center(
                  child: TextButton(
                    onPressed: () async {
                      final ok = await DdaengModal.confirm(
                        context,
                        title: '로그아웃 하시겠어요?',
                        message: '다시 로그인하면 이어서 사용할 수 있어요',
                        type: ModalType.warning,
                        confirmText: '로그아웃',
                      );
                      if (ok) await AuthService().signOut();
                    },
                    style: TextButton.styleFrom(foregroundColor: _inkSub),
                    child: const Text('로그아웃',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────── 프로필 카드 ───────────────────────

class _ProfileCard extends StatelessWidget {
  final UserModel user;
  final int joinedDays;
  const _ProfileCard({required this.user, required this.joinedDays});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFB648), Color(0xFFFF7A45)],
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
              color: const Color(0xFFFF8A45).withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 10)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: Colors.white,
                child: Text(user.coachTone.emoji, style: const TextStyle(fontSize: 26)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user.nickname,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white)),
                    const SizedBox(height: 2),
                    Text(user.email,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withOpacity(0.85))),
                  ],
                ),
              ),
              InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => Navigator.of(context)
                    .push(MaterialPageRoute(builder: (_) => const ProfileEditScreen())),
                child: const Padding(
                  padding: EdgeInsets.all(6),
                  child: Icon(Icons.edit_outlined, size: 19, color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(height: 1, color: Colors.white.withOpacity(0.35)),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _stat('레벨', 'Lv.${user.level}')),
              _divider(),
              Expanded(child: _stat('포인트', '${user.points}P')),
              _divider(),
              Expanded(child: _stat('함께한 지', '$joinedDays일')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _divider() => Container(width: 1, height: 30, color: Colors.white.withOpacity(0.35));

  Widget _stat(String label, String value) => Column(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      Text(label,
          style: TextStyle(
              fontSize: 10.5, fontWeight: FontWeight.w600, color: Colors.white.withOpacity(0.85))),
      const SizedBox(height: 3),
      Text(value,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white)),
    ],
  );
}

// ─────────────────────── 공용 하위 위젯 ───────────────────────

class _MenuGroup extends StatelessWidget {
  final List<Widget> children;
  const _MenuGroup({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
              color: _ink.withOpacity(0.04), blurRadius: 14, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(children: children),
    );
  }
}

class _MenuRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Color iconColor;
  final Color iconBg;
  final bool showDivider;

  const _MenuRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.iconColor = _accent,
    this.iconBg = _accentSoft,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
                  alignment: Alignment.center,
                  child: Icon(icon, size: 18, color: iconColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w700, color: _ink)),
                      const SizedBox(height: 2),
                      Text(subtitle,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 11.5, fontWeight: FontWeight.w500, color: _inkSub)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, size: 20, color: _inkSub),
              ],
            ),
          ),
        ),
        if (showDivider) const Divider(height: 1, indent: 16, endIndent: 16, color: _line),
      ],
    );
  }
}
