import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shimmer/shimmer.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/user_model.dart';
import '../../models/category_summary_model.dart';
import '../../models/budget_model.dart';
import '../../services/ai_service.dart';
import '../../services/auth_service.dart';
import '../../services/budget_service.dart';
import '../../services/category_summary_service.dart';
import '../../services/user_service.dart';
import '../../utils/formatters.dart';
import '../../widgets/common/app_drawer.dart';
import '../../widgets/common/coach_avatar.dart';
import '../../widgets/common/bottom_nav_bar.dart';
import '../../widgets/common/Placeholder_screen.dart';
import '../expense/expense_input_screen.dart';
import '../community/community_home_screen.dart';
import '../ai_chat/ai_consult_screen.dart';
import '../mypage/mypage_home_screen.dart';
import '../avatar/my_avatar_screen.dart';

/// 홈 대시보드 전용 팔레트.
/// 히어로는 앰버→코럴 그라데이션으로 임팩트를 주고, 나머지 카드는
/// 흰 배경 + 그림자(테두리 없음)로 통일해서 붕 떠 보이는 장식 없이도
/// 입체감이 나도록 구성. 퍼플/블루/민트/핑크를 섹션마다 다르게 써서
/// 단조롭지 않게 한다.
class _C {
  static const bg = Color(0xFFF8F7FB);
  static const card = Colors.white;
  static const ink = Color(0xFF221A20);
  static const inkSub = Color(0xFF8A8798);

  static const amber = Color(0xFFFFA733);
  static const amberSoft = Color(0xFFFFF3DE);
  static const amberDeep = Color(0xFF8A5200);

  static const purple = Color(0xFF6C5CE7);

  static const blue = Color(0xFF4F7DF3);
  static const blueSoft = Color(0xFFE8EFFE);

  static const pink = Color(0xFFFF6F91);
  static const pinkSoft = Color(0xFFFFE3EC);

  static const mint = Color(0xFF00C2A8);
  static const mintSoft = Color(0xFFDBF7F3);

  static const expense = Color(0xFFF04438);

  /// 카드 공통 그림자 — 테두리 대신 그림자로만 입체감을 준다.
  static List<BoxShadow> cardShadow = [
    BoxShadow(color: ink.withOpacity(0.05), blurRadius: 18, offset: const Offset(0, 8)),
  ];
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  NavTab _currentTab = NavTab.home;

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      backgroundColor: _C.bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: _C.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/images/Icon.png', width: 26, height: 26),
            const SizedBox(width: 8),
            const Text('땡그랑',
                style: TextStyle(fontWeight: FontWeight.w800, color: _C.ink)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: _C.inkSub),
            onPressed: () => AuthService().signOut(),
          ),
        ],
        // leading은 지정 안 해도 됨 — drawer가 있으면 Scaffold가
        // 햄버거 버튼을 자동으로 왼쪽에 넣어줌
      ),
      drawer: const AppDrawer(),
      bottomNavigationBar: BottomNavBar(
        currentTab: _currentTab,
        onTabSelected: (tab) {
          // 커뮤니티는 이미 만들어진 자체 화면(AppBar/BottomNav 포함)이 있어서
          // 탭 전환이 아니라 별도 화면으로 push한다.
          if (tab == NavTab.community) {
            Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const CommunityHomeScreen()));
            return;
          }
          setState(() => _currentTab = tab);
        },
      ),
      body: _buildBody(uid),
    );
  }

  Widget _buildBody(String uid) {
    switch (_currentTab) {
      case NavTab.home:
        return _HomeDashboard(uid: uid);
      case NavTab.expense:
        return const _TabPlaceholder(title: '지출');
      case NavTab.aiConsult:
        return const AiConsultScreen();
      case NavTab.community:
        return const _TabPlaceholder(title: '커뮤니티');
      case NavTab.myPage:
        return const MyPageHomeScreen();
    }
  }
}

/// 하단 탭 중 아직 화면이 없는 탭용 임시 바디
/// (Placeholder_screen.dart처럼 새 화면을 push하지 않고,
///  바텀네비 특성상 그 자리에서 body만 바뀌도록 구성)
class _TabPlaceholder extends StatelessWidget {
  final String title;
  const _TabPlaceholder({required this.title});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        '$title 화면 준비 중이에요',
        style: const TextStyle(fontSize: 16, color: Colors.grey),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
// 홈 대시보드
//
// nickname / coachTone / level / points는 users 컬렉션(내 파트)에서
// 실제로 받아오고, 예산·지출·소비유형 관련 내용은 성기필(예산)·
// 임예림(지출기록)·이태화(소비심리테스트) 파트가 아직 완성 전이라
// 지금은 더미 데이터로 틀만 잡아둔 상태. 각 위젯에 남긴 TODO 지점만
// 실제 스트림/서비스로 바꿔 끼우면 됨.
// ══════════════════════════════════════════════════════════

class _HomeDashboard extends StatefulWidget {
  final String uid;
  const _HomeDashboard({required this.uid});

  @override
  State<_HomeDashboard> createState() => _HomeDashboardState();
}

/// 데이터 로딩 중 보여주는 스켈레톤 — 실제 레이아웃 윤곽을 흐릿하게 미리 보여줘서
/// 스피너보다 자연스럽게 이어지도록 한다.
class _DashboardSkeleton extends StatelessWidget {
  const _DashboardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: const Color(0xFFEFEDF3),
      highlightColor: const Color(0xFFF8F7FB),
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _bar(width: 180, height: 20),
            const SizedBox(height: 18),
            _block(height: 190, radius: 26),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: _block(height: 84, radius: 18)),
              const SizedBox(width: 12),
              Expanded(child: _block(height: 84, radius: 18)),
            ]),
            const SizedBox(height: 24),
            Row(children: List.generate(4, (i) {
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: i == 3 ? 0 : 12),
                  child: Column(children: [
                    _circle(52),
                    const SizedBox(height: 8),
                    _bar(width: 40, height: 10),
                  ]),
                ),
              );
            })),
            const SizedBox(height: 28),
            _block(height: 160, radius: 18),
          ],
        ),
      ),
    );
  }

  Widget _bar({required double width, required double height}) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6)),
  );

  Widget _block({required double height, required double radius}) => Container(
    width: double.infinity,
    height: height,
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(radius)),
  );

  Widget _circle(double size) => Container(
    width: size,
    height: size,
    decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
  );
}

/// 개별 섹션이 자체 데이터를 불러오는 동안 보여주는 단일 시머 블록.
class _ShimmerBlock extends StatelessWidget {
  final double height;
  final double radius;
  const _ShimmerBlock({required this.height, required this.radius});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: const Color(0xFFEFEDF3),
      highlightColor: const Color(0xFFF8F7FB),
      child: Container(
        width: double.infinity,
        height: height,
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(radius)),
      ),
    );
  }
}

class _HomeDashboardState extends State<_HomeDashboard> {
  bool _isGroupMode = false;
  DateTime _month = DateTime.now();
  late DateTime _selectedDay = DateTime.now();

  // TODO: 소비심리테스트 파트(이태화) 완성 후 실데이터로 교체
  static const _mockSpendingType = '스트레스형 소비러';
  static const _mockSpendingTip =
      '감정 태그 중 스트레스 지출 비율이 높아요. 이번 주는 배달·카페 소비를 조금 줄여보는 걸 추천해요.';

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<UserModel?>(
      stream: UserService().watchUser(widget.uid),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const _DashboardSkeleton();
        }
        final user = snapshot.data!;

        return RefreshIndicator(
          color: _C.amber,
          onRefresh: () async {},
          child: SingleChildScrollView(
            physics:
            const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            padding: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: _GreetingRow(user: user),
                ),
                const SizedBox(height: 14),

                _LiveBudgetSection(
                    uid: widget.uid, month: _month, weekAnchor: _selectedDay),

                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _QuickActionsGrid(),
                      const SizedBox(height: 24),

                      _CategorySpendingSection(uid: widget.uid, month: _month),
                      const SizedBox(height: 28),

                      _MonthHeader(
                        month: _month,
                        onPrev: () => setState(
                                () => _month = DateTime(_month.year, _month.month - 1)),
                        onNext: () => setState(
                                () => _month = DateTime(_month.year, _month.month + 1)),
                      ),
                      const SizedBox(height: 12),
                      _ModeToggle(
                        isGroup: _isGroupMode,
                        onChanged: (v) => setState(() => _isGroupMode = v),
                      ),
                      const SizedBox(height: 16),

                      _LiveWeekCalendarStrip(
                        uid: widget.uid,
                        month: _month,
                        selectedDay: _selectedDay,
                        onSelect: (d) => setState(() => _selectedDay = d),
                      ),
                      const SizedBox(height: 20),

                      _CoachBubble(uid: widget.uid, tone: user.coachTone),
                      const SizedBox(height: 24),

                      _RecentExpensesSection(uid: widget.uid),
                      const SizedBox(height: 20),

                      _WalletTeaserCard(nickname: user.nickname, spendingType: _mockSpendingType),
                      const SizedBox(height: 16),

                      _SpendingTendencyCard(type: _mockSpendingType, tip: _mockSpendingTip),
                    ]
                        .animate(interval: 55.ms)
                        .fadeIn(duration: 320.ms, curve: Curves.easeOut)
                        .slideY(begin: 0.05, end: 0, curve: Curves.easeOutCubic),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────── 인사말 ───────────────────────

class _GreetingRow extends StatelessWidget {
  final UserModel user;
  const _GreetingRow({required this.user});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: _C.amberSoft,
          backgroundImage: AssetImage(user.coachTone.imagePath),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text('${user.nickname}님, 오늘도 파이팅!',
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 16.5, fontWeight: FontWeight.w800, color: _C.ink)),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: _C.pinkSoft,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text('Lv.${user.level} · ${user.points}P',
              style: const TextStyle(
                  fontSize: 11.5, fontWeight: FontWeight.w800, color: _C.pink)),
        ),
      ],
    );
  }
}

// ─────────────────────── 예산 히어로 + 통계 카드 (실데이터 로더) ───────────────────────

class _BudgetStats {
  final int total;
  final int spent;
  final int weekSpent;
  final (String, double) topCategory;
  const _BudgetStats({
    required this.total,
    required this.spent,
    required this.weekSpent,
    required this.topCategory,
  });
}

/// 예산(BudgetService) + 이번 달/이번 주 지출(CategorySummaryService)을 함께 불러와
/// _BudgetHero와 _FloatingStatsRow를 겹친 레이아웃 그대로 렌더링한다.
class _LiveBudgetSection extends StatefulWidget {
  final String uid;
  final DateTime month;
  final DateTime weekAnchor;
  const _LiveBudgetSection({required this.uid, required this.month, required this.weekAnchor});

  @override
  State<_LiveBudgetSection> createState() => _LiveBudgetSectionState();
}

class _LiveBudgetSectionState extends State<_LiveBudgetSection> {
  late Future<_BudgetStats> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void didUpdateWidget(covariant _LiveBudgetSection old) {
    super.didUpdateWidget(old);
    if (old.month != widget.month || old.weekAnchor != widget.weekAnchor || old.uid != widget.uid) {
      setState(() => _future = _load());
    }
  }

  Future<_BudgetStats> _load() async {
    final monthStr =
        '${widget.month.year}-${widget.month.month.toString().padLeft(2, '0')}';
    final weekStart =
        widget.weekAnchor.subtract(Duration(days: widget.weekAnchor.weekday % 7));

    final results = await Future.wait([
      BudgetService().getBudget(userId: widget.uid, month: monthStr),
      CategorySummaryService()
          .getCategorySummary(userId: widget.uid, year: widget.month.year, month: widget.month.month),
      CategorySummaryService().getWeeklyTotalExpense(userId: widget.uid, weekStart: weekStart),
    ]);

    final budget = results[0] as BudgetModel?;
    final summaries = results[1] as List<CategorySummaryModel>;
    final weekSpent = results[2] as int;

    final spent = summaries.fold<int>(0, (sum, s) => sum + s.totalAmount);
    final topCategory = summaries.isEmpty
        ? ('지출 없음', 0.0)
        : (summaries.first.categoryName, summaries.first.percentage / 100);

    return _BudgetStats(
      total: budget?.totalBudget ?? 0,
      spent: spent,
      weekSpent: weekSpent,
      topCategory: topCategory,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_BudgetStats>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: _ShimmerBlock(height: 190, radius: 26),
          );
        }
        final stats = snap.data ??
            const _BudgetStats(total: 0, spent: 0, weekSpent: 0, topCategory: ('지출 없음', 0.0));
        final remaining = stats.total - stats.spent;
        final progress =
            stats.total == 0 ? 0.0 : (stats.spent / stats.total).clamp(0.0, 1.0);

        return Column(
          children: [
            _BudgetHero(remaining: remaining, total: stats.total, progress: progress)
                .animate()
                .fadeIn(duration: 380.ms, curve: Curves.easeOut)
                .slideY(begin: 0.06, end: 0, curve: Curves.easeOutCubic),

            // 히어로 카드 아래로 살짝 겹치는 레이어드 통계 카드
            Transform.translate(
              offset: const Offset(0, -22),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _FloatingStatsRow(weekSpent: stats.weekSpent, topCategory: stats.topCategory)
                    .animate(delay: 120.ms)
                    .fadeIn(duration: 380.ms, curve: Curves.easeOut)
                    .slideY(begin: 0.1, end: 0, curve: Curves.easeOutCubic),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _BudgetHero extends StatelessWidget {
  final int remaining;
  final int total;
  final double progress;

  const _BudgetHero({required this.remaining, required this.total, required this.progress});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 0),
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 40),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFB648), Color(0xFFFF7A45)],
        ),
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
              color: const Color(0xFFFF8A45).withOpacity(0.35),
              blurRadius: 26,
              offset: const Offset(0, 14)),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('이번 달 남은 예산',
                    style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: Colors.white.withOpacity(0.92))),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(comma(remaining),
                        style: const TextStyle(
                            fontSize: 34,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            height: 1,
                            letterSpacing: -0.6)),
                    const Padding(
                      padding: EdgeInsets.only(left: 4, bottom: 4),
                      child: Text('원',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text('전체 ${comma(total)}원 중 여유',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withOpacity(0.85))),
              ],
            ),
          ),
          CircularPercentIndicator(
            radius: 42,
            lineWidth: 9,
            percent: progress,
            animation: true,
            animationDuration: 700,
            circularStrokeCap: CircularStrokeCap.round,
            backgroundColor: Colors.white.withOpacity(0.28),
            progressColor: Colors.white,
            center: Text('${(progress * 100).round()}%',
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────── 히어로 위에 뜨는 레이어드 카드 ───────────────────────

class _FloatingStatsRow extends StatelessWidget {
  final int weekSpent;
  final (String, double) topCategory;

  const _FloatingStatsRow({required this.weekSpent, required this.topCategory});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            icon: Icons.calendar_view_week_rounded,
            iconBg: _C.mintSoft,
            iconColor: _C.mint,
            label: '이번 주 지출',
            value: '${comma(weekSpent)}원',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            icon: Icons.local_fire_department_rounded,
            iconBg: _C.pinkSoft,
            iconColor: _C.pink,
            label: '최다 지출 카테고리',
            value: '${topCategory.$1} · ${(topCategory.$2 * 100).round()}%',
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String label;
  final String value;

  const _StatCard({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: iconColor.withOpacity(0.12), blurRadius: 14, offset: const Offset(0, 7)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(10)),
            alignment: Alignment.center,
            child: Icon(icon, size: 16, color: iconColor),
          ),
          const SizedBox(height: 10),
          Text(label,
              style: const TextStyle(
                  fontSize: 10.5, fontWeight: FontWeight.w600, color: _C.inkSub)),
          const SizedBox(height: 2),
          Text(value,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 13.5, fontWeight: FontWeight.w800, color: _C.ink)),
        ],
      ),
    );
  }
}

// ─────────────────────── 빠른 실행 (4칸 그리드) ───────────────────────

class _QuickActionsGrid extends StatelessWidget {
  const _QuickActionsGrid();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _QuickActionButton(
            label: '내역입력',
            icon: Icons.edit_note_rounded,
            bg: _C.amberSoft,
            fg: _C.amberDeep,
            onTap: (context) => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const ExpenseInputScreen())),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _QuickActionButton(
            label: '영수증',
            icon: Icons.camera_alt_outlined,
            bg: _C.mintSoft,
            fg: _C.mint,
            onTap: (context) => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const PlaceholderScreen(title: '영수증 촬영 업로드'))),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _QuickActionButton(
            label: '구독관리',
            icon: Icons.autorenew_rounded,
            bg: _C.pinkSoft,
            fg: _C.pink,
            onTap: (context) => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const PlaceholderScreen(title: '구독/정기결제 관리'))),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _QuickActionButton(
            label: '여행관리',
            icon: Icons.flight_takeoff_rounded,
            bg: _C.blueSoft,
            fg: _C.blue,
            onTap: (context) => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const PlaceholderScreen(title: '여행 관리'))),
          ),
        ),
      ],
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color bg;
  final Color fg;
  final void Function(BuildContext context)? onTap;
  const _QuickActionButton({
    required this.label,
    required this.icon,
    required this.bg,
    required this.fg,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap == null ? null : () => onTap!(context),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: bg,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: fg.withOpacity(0.14), blurRadius: 10, offset: const Offset(0, 5)),
              ],
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 21, color: fg),
          ),
          const SizedBox(height: 8),
          Text(label,
              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: _C.ink)),
        ],
      ),
    );
  }
}

// ─────────────────────── 월 선택 헤더 ───────────────────────

class _MonthHeader extends StatelessWidget {
  final DateTime month;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  const _MonthHeader({
    required this.month,
    required this.onPrev,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _iconBtn(Icons.chevron_left_rounded, onPrev),
        const SizedBox(width: 4),
        Text('${month.month}월',
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: _C.ink)),
        const SizedBox(width: 4),
        _iconBtn(Icons.chevron_right_rounded, onNext),
        const Spacer(),
        _iconBtn(Icons.notifications_none_rounded, () {}),
      ],
    );
  }

  Widget _iconBtn(IconData icon, VoidCallback onTap) => InkWell(
    borderRadius: BorderRadius.circular(18),
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.all(6),
      child: Icon(icon, size: 22, color: _C.inkSub),
    ),
  );
}

// ─────────────────────── 개인/그룹 토글 ───────────────────────

class _ModeToggle extends StatelessWidget {
  final bool isGroup;
  final ValueChanged<bool> onChanged;

  const _ModeToggle({required this.isGroup, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xFFF0EDF5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(child: _segment('개인', !isGroup, () => onChanged(false))),
          Expanded(child: _segment('그룹', isGroup, () => onChanged(true))),
        ],
      ),
    );
  }

  Widget _segment(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          gradient: selected
              ? const LinearGradient(colors: [Color(0xFFFFB648), Color(0xFFFF7A45)])
              : null,
          borderRadius: BorderRadius.circular(9),
          boxShadow: selected
              ? [
            BoxShadow(
                color: const Color(0xFFFF8A45).withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 3)),
          ]
              : null,
        ),
        alignment: Alignment.center,
        child: Text(label,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : _C.inkSub,
            )),
      ),
    );
  }
}

// ─────────────────────── 주간 달력 스트립 ───────────────────────

/// 이번 달 일자별 지출(CategorySummaryService.getDailyTotals)을 불러와
/// _WeekCalendarStrip에 실데이터로 꽂아 넣는다.
class _LiveWeekCalendarStrip extends StatefulWidget {
  final String uid;
  final DateTime month;
  final DateTime selectedDay;
  final ValueChanged<DateTime> onSelect;
  const _LiveWeekCalendarStrip({
    required this.uid,
    required this.month,
    required this.selectedDay,
    required this.onSelect,
  });

  @override
  State<_LiveWeekCalendarStrip> createState() => _LiveWeekCalendarStripState();
}

class _LiveWeekCalendarStripState extends State<_LiveWeekCalendarStrip> {
  late Future<Map<int, int>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void didUpdateWidget(covariant _LiveWeekCalendarStrip old) {
    super.didUpdateWidget(old);
    if (old.month != widget.month || old.uid != widget.uid) {
      setState(() => _future = _load());
    }
  }

  Future<Map<int, int>> _load() => CategorySummaryService()
      .getDailyTotals(userId: widget.uid, year: widget.month.year, month: widget.month.month);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<int, int>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const _ShimmerBlock(height: 88, radius: 18);
        }
        return _WeekCalendarStrip(
          selectedDay: widget.selectedDay,
          dailySpend: snap.data ?? const {},
          onSelect: widget.onSelect,
        );
      },
    );
  }
}

class _WeekCalendarStrip extends StatelessWidget {
  final DateTime selectedDay;
  final Map<int, int> dailySpend; // day → 지출액
  final ValueChanged<DateTime> onSelect;

  const _WeekCalendarStrip({
    required this.selectedDay,
    required this.dailySpend,
    required this.onSelect,
  });

  static const _weekLabels = ['일', '월', '화', '수', '목', '금', '토'];

  @override
  Widget build(BuildContext context) {
    final start = selectedDay.subtract(Duration(days: selectedDay.weekday % 7));
    final days = List.generate(7, (i) => start.add(Duration(days: i)));

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
      decoration: BoxDecoration(
        color: _C.card,
        borderRadius: BorderRadius.circular(18),
        boxShadow: _C.cardShadow,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: days.map((d) {
          final isSelected = d.day == selectedDay.day && d.month == selectedDay.month;
          final isToday = _isSameDate(d, DateTime.now());
          final amount = dailySpend[d.day];

          return GestureDetector(
            onTap: () => onSelect(d),
            child: Column(
              children: [
                Text(_weekLabels[d.weekday % 7],
                    style:
                    const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _C.inkSub)),
                const SizedBox(height: 6),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: isSelected
                        ? const LinearGradient(colors: [Color(0xFFFFB648), Color(0xFFFF7A45)])
                        : null,
                    border: (!isSelected && isToday) ? Border.all(color: _C.pink, width: 1.6) : null,
                  ),
                  alignment: Alignment.center,
                  child: Text('${d.day}',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: isSelected ? Colors.white : (isToday ? _C.pink : _C.ink),
                      )),
                ),
                const SizedBox(height: 4),
                SizedBox(
                  height: 12,
                  child: (amount != null && amount > 0)
                      ? Text(
                    amount >= 10000 ? '${(amount / 10000).toStringAsFixed(1)}만' : '$amount',
                    style: const TextStyle(
                        fontSize: 9.5, fontWeight: FontWeight.w700, color: _C.mint),
                  )
                      : null,
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  bool _isSameDate(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

// ─────────────────────── 코치 말풍선 ───────────────────────

class _CoachBubble extends StatefulWidget {
  final String uid;
  final CoachTone tone;
  const _CoachBubble({required this.uid, required this.tone});

  @override
  State<_CoachBubble> createState() => _CoachBubbleState();
}

class _CoachBubbleState extends State<_CoachBubble> {
  late Future<String> _messageFuture;

  @override
  void initState() {
    super.initState();
    _messageFuture = _buildMessage();
  }

  @override
  void didUpdateWidget(covariant _CoachBubble old) {
    super.didUpdateWidget(old);
    if (old.uid != widget.uid || old.tone != widget.tone) {
      _messageFuture = _buildMessage();
    }
  }

  /// 이번 달 카테고리별 실제 지출(CategorySummaryService)을 요약해서
  /// 땡코치 AI(은동 PC 로컬 Ollama)에게 잔소리 문구를 생성시킨다.
  /// AI 서버가 꺼져 있어도 실제 집계 숫자로 만든 문구는 그대로 보여준다.
  Future<String> _buildMessage() async {
    final now = DateTime.now();
    final summaries = await CategorySummaryService().getCategorySummary(
      userId: widget.uid,
      year: now.year,
      month: now.month,
    );

    if (summaries.isEmpty) {
      return '이번 달 지출 기록이 아직 없어요. 첫 기록을 남겨서 저와 함께 시작해볼까요?';
    }

    final top = summaries.first;
    final dataSummary =
        '이번 달 최다 지출 카테고리: ${top.categoryName} ${_won(top.totalAmount)} '
        '(전체 지출의 ${top.percentage.round()}%)';

    try {
      return await AiService().generateNagging(widget.tone, dataSummary);
    } on AiServerException {
      return '$dataSummary. (AI 코치가 잠깐 자리를 비웠어요 — 은동 PC 연결을 확인해주세요)';
    } catch (_) {
      return dataSummary;
    }
  }

  static String _won(int n) {
    final s = n.toString().replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},');
    return '$s원';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFF9EB5), Color(0xFFFF5C8A)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: _C.pink.withOpacity(0.28), blurRadius: 18, offset: const Offset(0, 8)),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.24),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withOpacity(0.4)),
            ),
            alignment: Alignment.center,
            child: CoachAvatar(imagePath: widget.tone.imagePath, size: 30),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FutureBuilder<String>(
              future: _messageFuture,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const _CoachBubbleLoading();
                }
                return Text(
                  snap.data ?? '오늘도 현명한 소비 하고 계신가요?',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    height: 1.45,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// 코치 문구를 AI로부터 받아오는 동안 보여주는 스켈레톤 라인.
class _CoachBubbleLoading extends StatelessWidget {
  const _CoachBubbleLoading();

  @override
  Widget build(BuildContext context) {
    Widget bar(double width) => Container(
          width: width,
          height: 11,
          margin: const EdgeInsets.only(bottom: 6),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.35),
            borderRadius: BorderRadius.circular(6),
          ),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [bar(double.infinity), bar(140)],
    )
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .fadeIn(duration: 700.ms, curve: Curves.easeInOut);
  }
}

// ─────────────────────── 카테고리별 지출 도넛 차트 ───────────────────────

class _CategorySlice {
  final String label;
  final int amount;
  final Color color;
  const _CategorySlice(this.label, this.amount, this.color);
}

/// 카테고리 키(food/transport/shopping/culture/housing/etc) → 브랜드 색상.
/// CategorySummaryService.categoryNames와 1:1로 맞춰 아이덴티티를 고정 배정.
const _categoryColors = <String, Color>{
  'food': _C.amber,
  'transport': _C.blue,
  'shopping': _C.pink,
  'culture': _C.mint,
  'housing': _C.purple,
  'etc': Color(0xFFC7C3D1),
};

const _categoryIcons = <String, IconData>{
  'food': Icons.restaurant_rounded,
  'transport': Icons.directions_subway_rounded,
  'shopping': Icons.shopping_bag_rounded,
  'culture': Icons.movie_outlined,
  'housing': Icons.home_outlined,
  'etc': Icons.category_outlined,
};

class _CategorySpendingSection extends StatefulWidget {
  final String uid;
  final DateTime month;
  const _CategorySpendingSection({required this.uid, required this.month});

  @override
  State<_CategorySpendingSection> createState() => _CategorySpendingSectionState();
}

class _CategorySpendingSectionState extends State<_CategorySpendingSection> {
  late Future<List<CategorySummaryModel>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void didUpdateWidget(covariant _CategorySpendingSection old) {
    super.didUpdateWidget(old);
    if (old.month != widget.month || old.uid != widget.uid) {
      setState(() => _future = _load());
    }
  }

  Future<List<CategorySummaryModel>> _load() => CategorySummaryService().getCategorySummary(
      userId: widget.uid, year: widget.month.year, month: widget.month.month);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<CategorySummaryModel>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const _ShimmerBlock(height: 190, radius: 20);
        }
        final summaries = snap.data ?? const [];
        final slices = summaries
            .map((s) => _CategorySlice(
                s.categoryName, s.totalAmount, _categoryColors[s.categoryKey] ?? const Color(0xFFC7C3D1)))
            .toList();
        return _CategorySpendingCard(slices: slices);
      },
    );
  }
}

class _CategorySpendingCard extends StatelessWidget {
  final List<_CategorySlice> slices;
  const _CategorySpendingCard({required this.slices});

  @override
  Widget build(BuildContext context) {
    final total = slices.fold<int>(0, (sum, s) => sum + s.amount);

    if (slices.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: _C.cardShadow,
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('카테고리별 지출',
                style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800, color: _C.ink)),
            SizedBox(height: 4),
            Text('이번 달 지출 기록이 아직 없어요',
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500, color: _C.inkSub)),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: _C.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('카테고리별 지출',
              style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800, color: _C.ink)),
          const SizedBox(height: 4),
          const Text('이번 달 지출을 카테고리로 나눠봤어요',
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500, color: _C.inkSub)),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 118,
                height: 118,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    PieChart(
                      PieChartData(
                        sections: [
                          for (final s in slices)
                            PieChartSectionData(
                              value: s.amount.toDouble(),
                              color: s.color,
                              radius: 20,
                              showTitle: false,
                            ),
                        ],
                        centerSpaceRadius: 39,
                        sectionsSpace: 3,
                        startDegreeOffset: -90,
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(koreanAmount(total),
                            style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w800, color: _C.ink)),
                        const Text('총 지출',
                            style: TextStyle(
                                fontSize: 9.5, fontWeight: FontWeight.w600, color: _C.inkSub)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  children: [
                    for (final s in slices)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Container(
                              width: 9,
                              height: 9,
                              decoration: BoxDecoration(color: s.color, shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(s.label,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                      color: _C.ink)),
                            ),
                            Text('${(s.amount / total * 100).round()}%',
                                style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: _C.inkSub)),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────── 최근 지출 ───────────────────────

/// 최근 지출 N건(CategorySummaryService.getRecentExpenses)을 불러와 보여준다.
/// 이 서브컬렉션 스키마엔 가맹점명이 없어 카테고리명을 대표 라벨로 쓴다.
class _RecentExpensesSection extends StatefulWidget {
  final String uid;
  const _RecentExpensesSection({required this.uid});

  @override
  State<_RecentExpensesSection> createState() => _RecentExpensesSectionState();
}

class _RecentExpensesSectionState extends State<_RecentExpensesSection> {
  late final Future<List<RecentExpenseEntry>> _future =
      CategorySummaryService().getRecentExpenses(userId: widget.uid);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('최근 지출',
                style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800, color: _C.ink)),
            Row(
              children: const [
                Text('전체보기',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: _C.inkSub)),
                Icon(Icons.chevron_right_rounded, size: 16, color: _C.inkSub),
              ],
            ),
          ],
        ),
        const SizedBox(height: 10),
        FutureBuilder<List<RecentExpenseEntry>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const _ShimmerBlock(height: 160, radius: 18);
            }
            final items = snap.data ?? const [];
            if (items.isEmpty) {
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 28),
                decoration: BoxDecoration(
                  color: _C.card,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: _C.cardShadow,
                ),
                child: const Center(
                  child: Text('아직 지출 기록이 없어요',
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: _C.inkSub)),
                ),
              );
            }
            return Container(
              decoration: BoxDecoration(
                color: _C.card,
                borderRadius: BorderRadius.circular(18),
                boxShadow: _C.cardShadow,
              ),
              child: Column(
                children: [
                  for (final (i, e) in items.indexed) ...[
                    if (i > 0)
                      const Divider(height: 1, indent: 16, endIndent: 16, color: Color(0xFFF0EDF5)),
                    _ExpenseRow(item: e),
                  ],
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

class _ExpenseRow extends StatelessWidget {
  final RecentExpenseEntry item;
  const _ExpenseRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final color = _categoryColors[item.categoryKey] ?? const Color(0xFFC7C3D1);
    final icon = _categoryIcons[item.categoryKey] ?? Icons.category_outlined;
    final date = '${item.date.month.toString().padLeft(2, '0')}.${item.date.day.toString().padLeft(2, '0')}';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(color: color.withOpacity(0.14), shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.categoryName,
                    style:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _C.ink)),
                const SizedBox(height: 2),
                Text(date,
                    style: const TextStyle(
                        fontSize: 11.5, fontWeight: FontWeight.w500, color: _C.inkSub)),
              ],
            ),
          ),
          Text(
            '-${comma(item.amount)}원',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: _C.expense,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────── 지갑멍 아바타 티저 카드 ───────────────────────

class _WalletTeaserCard extends StatelessWidget {
  final String nickname;
  final String spendingType;
  const _WalletTeaserCard({required this.nickname, required this.spendingType});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: _C.cardShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [_C.purple, Color(0xFF9B8CFF)],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            alignment: Alignment.center,
            child: const Text('👛', style: TextStyle(fontSize: 24)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$nickname님의 지갑멍',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w800, color: _C.ink)),
                const SizedBox(height: 3),
                // TODO: 소비심리테스트 결과(testResults) 연동 전까지는 더미 유형 표시
                Text('이번 달 소비 유형: $spendingType',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600, color: _C.inkSub)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const MyAvatarScreen())),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(color: _C.ink, borderRadius: BorderRadius.circular(20)),
              child: const Text('아바타 꾸미기',
                  style: TextStyle(
                      fontSize: 11.5, fontWeight: FontWeight.w700, color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────── 소비 성향 카드 ───────────────────────

class _SpendingTendencyCard extends StatelessWidget {
  final String type;
  final String tip;
  const _SpendingTendencyCard({required this.type, required this.tip});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: _C.pinkSoft, borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.favorite_rounded, size: 16, color: _C.pink),
              const SizedBox(width: 6),
              Text('소비 성향: $type',
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFFB8395C))),
            ],
          ),
          const SizedBox(height: 8),
          // TODO: 감정태그 집계(지출 파트) 완성 후 실데이터 기반 코멘트로 교체
          Text(tip,
              style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF8A5164),
                  height: 1.5)),
        ],
      ),
    );
  }
}
