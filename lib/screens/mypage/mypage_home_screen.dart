import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/user_service.dart';
import '../../widgets/common/ddaeng_modal.dart';
import '../avatar/my_avatar_screen.dart';
import '../avatar/point_shop_screen.dart';
import '../mission/mission_list_screen.dart';
import 'coach_tone_setting_screen.dart';
import 'monthly_report_screen.dart';
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

          return Stack(
            children: [
              // ── 은은하게 떠다니는 배경 블롭 ──
              Positioned(
                top: -30,
                right: -40,
                child: _Blob(color: _amberSoft, size: 150)
                    .animate(onPlay: (c) => c.repeat(reverse: true))
                    .moveY(begin: 0, end: 16, duration: 3400.ms, curve: Curves.easeInOut),
              ),
              Positioned(
                top: 260,
                left: -50,
                child: _Blob(color: _purpleSoft, size: 130)
                    .animate(onPlay: (c) => c.repeat(reverse: true))
                    .moveY(begin: 0, end: -14, duration: 3000.ms, curve: Curves.easeInOut),
              ),

              SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ProfileCard(user: user)
                        .animate()
                        .fadeIn(duration: 420.ms, curve: Curves.easeOut)
                        .slideY(begin: 0.08, end: 0, curve: Curves.easeOutCubic),
                    const SizedBox(height: 24),

                    const _SectionLabel('나의 활동'),
                    const SizedBox(height: 10),
                    _MenuGroup(children: [
                      _MenuRow(
                        icon: Icons.bar_chart_rounded,
                        title: '월간 소비 통계',
                        subtitle: '카테고리별 지출 흐름 한눈에 보기',
                        iconColor: _blue,
                        iconBg: _blueSoft,
                        onTap: () => Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => const MonthlyReportScreen())),
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
                        showDivider: false,
                      ),
                    ])
                        .animate(delay: 100.ms)
                        .fadeIn(duration: 420.ms, curve: Curves.easeOut)
                        .slideY(begin: 0.06, end: 0, curve: Curves.easeOutCubic),
                    const SizedBox(height: 22),

                    const _SectionLabel('계정 관리'),
                    const SizedBox(height: 10),
                    _MenuGroup(children: [
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
                    ])
                        .animate(delay: 160.ms)
                        .fadeIn(duration: 420.ms, curve: Curves.easeOut)
                        .slideY(begin: 0.06, end: 0, curve: Curves.easeOutCubic),
                    const SizedBox(height: 28),

                    Center(
                      child: TextButton.icon(
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
                        icon: const Icon(Icons.logout_rounded, size: 15),
                        label: const Text('로그아웃',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      ),
                    )
                        .animate(delay: 240.ms)
                        .fadeIn(duration: 380.ms),
                    const SizedBox(height: 4),
                    Center(
                      child: Text('땡그랑 v1.0.0',
                          style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w500,
                              color: _inkSub.withValues(alpha: 0.7))),
                    )
                        .animate(delay: 260.ms)
                        .fadeIn(duration: 380.ms),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Blob extends StatelessWidget {
  final Color color;
  final double size;
  const _Blob({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color, color.withValues(alpha: 0.0)]),
      ),
    );
  }
}

// ─────────────────────── 프로필 카드 ───────────────────────

class _ProfileCard extends StatelessWidget {
  final UserModel user;
  const _ProfileCard({required this.user});

  /// 레벨 공식(user_service.dart의 1 + points~/100, 즉 100포인트당 1레벨)과
  /// 맞춰서 다음 레벨까지 남은 포인트를 계산한다.
  int get _pointsIntoLevel => user.points % 100;
  int get _pointsToNextLevel => 100 - _pointsIntoLevel;

  /// 가입일 기준 함께한 일수. createdAt이 아직 없으면(구버전 문서 등) 표시 생략.
  int? get _daysSinceJoin {
    final createdAt = user.createdAt;
    if (createdAt == null) return null;
    final joinDay = DateTime(createdAt.year, createdAt.month, createdAt.day);
    final today = DateTime.now();
    final todayDay = DateTime(today.year, today.month, today.day);
    return todayDay.difference(joinDay).inDays + 1;
  }

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
              color: const Color(0xFFFF8A45).withValues(alpha: 0.32),
              blurRadius: 22,
              offset: const Offset(0, 12)),
        ],
      ),
      // 텍스트를 포함한 콘텐츠는 ClipRRect로 감싸지 않는다 — home_screen.dart의
      // _BudgetHero에서 확인된 렌더링 버그(ClipRRect가 그 안의 텍스트 첫 글자를
      // 깨뜨림)를 피하기 위해, 둥근 모서리는 바깥 Container의 BoxDecoration만으로
      // 처리하고 장식 원은 클리핑 없이 살짝 넘치게 둔다.
      child: Stack(
          children: [
            // 우상단 은은한 하이라이트 — 카드에 광택감을 준다
            Positioned(
              top: -40,
              right: -30,
              child: Container(
                width: 130,
                height: 130,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [Colors.white.withValues(alpha: 0.22), Colors.white.withValues(alpha: 0.0)],
                  ),
                ),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withValues(alpha: 0.55), width: 1.6),
                      ),
                      child: CircleAvatar(
                        radius: 27,
                        backgroundColor: Colors.white,
                        backgroundImage: AssetImage(user.coachTone.imagePath),
                      ),
                    )
                        .animate(onPlay: (c) => c.repeat(reverse: true))
                        .scaleXY(begin: 1.0, end: 1.04, duration: 1800.ms, curve: Curves.easeInOut),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(user.nickname,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white)),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.24),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text('Lv.${user.level}',
                                    style: const TextStyle(
                                        fontSize: 10.5, fontWeight: FontWeight.w800, color: Colors.white)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(user.email,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white.withValues(alpha: 0.85))),
                          if (_daysSinceJoin != null) ...[
                            const SizedBox(height: 2),
                            Text('함께한 지 $_daysSinceJoin일째',
                                style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white.withValues(alpha: 0.72))),
                          ],
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
                Container(height: 1, color: Colors.white.withValues(alpha: 0.35)),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(child: _stat(Icons.star_rounded, '레벨', 'Lv.${user.level}')),
                    _divider(),
                    Expanded(child: _stat(Icons.savings_rounded, '포인트', '${user.points}P')),
                    _divider(),
                    Expanded(
                        child: _stat(Icons.local_fire_department_rounded, '연속 접속',
                            '${user.loginStreak}일${_streakBadge(user.loginStreak)}')),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('다음 레벨까지 ${_pointsToNextLevel}P',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.white.withValues(alpha: 0.9))),
                    Text('Lv.${user.level + 1}',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.white.withValues(alpha: 0.9))),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: _pointsIntoLevel / 100),
                    duration: const Duration(milliseconds: 700),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, _) => LinearProgressIndicator(
                      value: value,
                      minHeight: 6,
                      backgroundColor: Colors.white.withValues(alpha: 0.25),
                      valueColor: const AlwaysStoppedAnimation(Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
    );
  }

  Widget _divider() => Container(width: 1, height: 34, color: Colors.white.withValues(alpha: 0.35));

  /// 연속 접속 마일스톤(main.dart의 축하 알림과 같은 기준) 달성 시 붙는 배지.
  String _streakBadge(int streak) {
    if (streak >= 100) return ' 👑';
    if (streak >= 30) return ' ⭐';
    if (streak >= 7) return ' 🔥';
    return '';
  }

  Widget _stat(IconData icon, String label, String value) => Column(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      Icon(icon, size: 14, color: Colors.white.withValues(alpha: 0.85)),
      const SizedBox(height: 4),
      Text(value,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white)),
      const SizedBox(height: 2),
      Text(label,
          style: TextStyle(
              fontSize: 10, fontWeight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.8))),
    ],
  );
}

// ─────────────────────── 공용 하위 위젯 ───────────────────────

/// 메뉴 그룹 위에 붙는 섹션 라벨 — 메뉴가 한 덩어리 리스트로 이어지지 않고
/// "나의 활동" / "계정 관리"로 성격이 나뉘어 보이도록 한다.
class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(text,
          style: const TextStyle(
              fontSize: 12.5, fontWeight: FontWeight.w800, color: _inkSub)),
    );
  }
}

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
              color: _ink.withValues(alpha: 0.05), blurRadius: 18, offset: const Offset(0, 6)),
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
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
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
