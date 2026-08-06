import 'dart:async';
import 'package:ddaenggeurang/screens/travel/travel_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:shimmer/shimmer.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/user_model.dart';
import '../../models/category_summary_model.dart';
import '../../models/budget_model.dart';
import '../../models/emotion_summary_model.dart';
import '../../services/ai_service.dart';
import '../../services/budget_service.dart';
import '../../services/category_summary_service.dart';
import '../../services/emotion_summary_service.dart';
import '../../services/home_refresh_service.dart';
import '../../services/notification_history_service.dart';
import '../../services/psychology_test_service.dart';
import '../../services/spending_challenge_service.dart';
import '../../models/spending_challenge_model.dart';
import '../../services/user_service.dart';
import '../../utils/formatters.dart';
import '../../widgets/common/app_drawer.dart';
import '../../widgets/common/attendance_roulette_dialog.dart';
import '../../widgets/expense/category_icon_map.dart';
import '../../widgets/common/coach_avatar.dart';
import '../../widgets/common/bottom_nav_bar.dart';
import '../../widgets/common/spotlight_tour.dart';
import '../record/record_type_select_screen.dart';
import '../community/community_home_screen.dart';
import '../ai_chat/ai_consult_screen.dart';
import '../mypage/mypage_home_screen.dart';
import '../avatar/my_avatar_screen.dart';
import '../briefing/mothly_briefing_screen.dart';
import '../budget/budget_setting_screen.dart';
import '../psychology/psychology_test_start_screen.dart';
import '../group/group_create_join_screen.dart';
import '../notification/notification_history_screen.dart';
import '../history/transaction_history_screen.dart';
import '../subscription/subscription_list_screen.dart';
import '../budget/budget_vs_expense_screen.dart';
// 추가: 홈의 카테고리별 지출 카드에서 상세 집계 화면으로 이동하기 위한 import
import '../category/category_summary_screen.dart';
import '../../widgets/home/quick_add_fab.dart';
import '../../models/group_model.dart';
import '../../services/group_service.dart';
import '../group/shared_expense_list_screen.dart';

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
    BoxShadow(color: ink.withValues(alpha: 0.05), blurRadius: 18, offset: const Offset(0, 8)),
  ];
}

/// 큰 금액 숫자 전용 디스플레이 폰트 — 본문은 앱 전체 테마(Gothic A1)를 쓰되,
/// "이번 달 남은 예산" 같은 히어로 숫자만 더 굵고 개성 있는 폰트로 강조한다.
TextStyle _displayNumber({required double fontSize, required Color color, double letterSpacing = -0.5}) {
  return GoogleFonts.jua(fontSize: fontSize, color: color, height: 1, letterSpacing: letterSpacing);
}

class HomeScreen extends StatefulWidget {
  final NavTab? initialTab;
  const HomeScreen({super.key, this.initialTab});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late NavTab _currentTab;
  bool _fabOpen = false;

  // 홈 대시보드는 데이터를 FutureBuilder로 한 번만 읽어오므로, 지출 입력 등
  // 다른 화면에서 돌아왔을 때 HomeRefreshService 신호를 받으면 이 값을 올려서
  // _HomeDashboard에 새 key를 줘 통째로 다시 만든다(모든 FutureBuilder 재실행).
  int _dashboardVersion = 0;

  @override
  void initState() {
    super.initState();
    _currentTab = widget.initialTab ?? NavTab.home;
    HomeRefreshService.signal.addListener(_onHomeRefreshRequested);
    // 홈 화면(탭 전환이 아니라 앱 진입 시 한 번만 새로 만들어지는 최상위
    // 위젯)에 처음 들어왔을 때 하루 한 번 출석 룰렛을 띄운다.
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowRoulette());
  }

  @override
  void dispose() {
    HomeRefreshService.signal.removeListener(_onHomeRefreshRequested);
    super.dispose();
  }

  void _onHomeRefreshRequested() {
    if (mounted) setState(() => _dashboardVersion++);
  }

  Future<void> _maybeShowRoulette() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || !mounted) return;
    final should = await shouldShowAttendanceRoulette(uid);
    if (!should || !mounted) return;
    await showAttendanceRoulette(context, uid: uid);
  }

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
            icon: StreamBuilder<int>(
              stream: NotificationHistoryService().watchUnreadCount(uid),
              builder: (context, snap) {
                final unread = snap.data ?? 0;
                // 다른 헤더 아이콘(햄버거 메뉴)처럼 배경 없이 아이콘 자체만 두고,
                // 안 읽은 알림이 있을 때만 우상단에 작은 개수 배지를 얹는다.
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(
                      unread > 0 ? Icons.notifications_rounded : Icons.notifications_none_rounded,
                      size: 24,
                      color: _C.ink,
                    ),
                    if (unread > 0)
                      Positioned(
                        top: -4,
                        right: -4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                          decoration: BoxDecoration(
                            color: _C.pink,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white, width: 1.4),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            unread > 9 ? '9+' : '$unread',
                            style: const TextStyle(
                                fontSize: 9, fontWeight: FontWeight.w800, color: Colors.white, height: 1.2),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
            tooltip: '알림',
            onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const NotificationHistoryScreen())),
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
      floatingActionButton: _currentTab == NavTab.home
          ? QuickAddFab(
        isOpen: _fabOpen,
        onToggle: () => setState(() => _fabOpen = !_fabOpen),
      )
          : null,
    );
  }

  Widget _buildBody(String uid) {
    switch (_currentTab) {
      case NavTab.home:
        return _HomeDashboard(key: ValueKey(_dashboardVersion), uid: uid);
      case NavTab.expense:
        return const TransactionHistoryScreen();
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
// nickname/coachTone/level/points(users, 내 파트), 예산·카테고리·감정태그
// (BudgetService/CategorySummaryService/EmotionSummaryService, 성기필·임예림)
// 소비심리테스트 결과(PsychologyTestService, 이태화)까지 전부 실데이터로
// 연동돼 있다. 감정태그가 없거나 테스트를 안 한 경우엔 각 위젯이 빈 상태/
// 유도 문구를 보여준다.
// ══════════════════════════════════════════════════════════

class _HomeDashboard extends StatefulWidget {
  final String uid;
  const _HomeDashboard({super.key, required this.uid});

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
  final GroupService _groupService = GroupService.instance;

  List<GroupModel> _myGroups = [];
  bool _isLoadingGroups = false;
  bool _hasLoadedGroups = false;
  late DateTime _selectedDay = DateTime.now();

  // 첫 방문자 전용 스팟라이트 투어 — 대상 위젯 3곳의 위치만 알면 되므로
  // GlobalKey만 붙이고, 하이라이트/툴팁은 별도 오버레이(spotlight_tour.dart)가 그린다.
  final _budgetHeroKey = GlobalKey();
  final _quickActionsKey = GlobalKey();
  final _categoryCardKey = GlobalKey();
  final _tourController = SpotlightTourController();
  bool _tourChecked = false;

  @override
  void dispose() {
    _tourController.dispose();
    super.dispose();
  }
  // 현재 사용자가 참여 중인 그룹 목록을 불러오는 메서드
  Future<void> _loadMyGroups() async {
    if (_isLoadingGroups) {
      return;
    }

    setState(() {
      _isLoadingGroups = true;
    });

    try {
      final List<GroupModel> groups =
      await _groupService.getMyGroups();

      if (!mounted) {
        return;
      }

      setState(() {
        _myGroups = groups;
        _isLoadingGroups = false;
        _hasLoadedGroups = true;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _myGroups = [];
        _isLoadingGroups = false;
        _hasLoadedGroups = true;
      });

      debugPrint('홈 그룹 목록 조회 실패: $error');
    }
  }

  Future<void> _maybeStartTour() async {
    if (_tourChecked) return;
    _tourChecked = true;
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('homeTourShown') == true) return;
    await prefs.setBool('homeTourShown', true);
    if (!mounted) return;
    _tourController.start(context, [
      SpotlightStep(
        targetKey: _budgetHeroKey,
        title: '이번 달 예산 확인',
        description: '여기서 남은 예산과 사용률을 한눈에 볼 수 있어요',
      ),
      SpotlightStep(
        targetKey: _quickActionsKey,
        title: '빠르게 기록하기',
        description: '지출·수입·저축을 여기서 바로 입력할 수 있어요',
      ),
      SpotlightStep(
        targetKey: _categoryCardKey,
        title: '카테고리별 지출',
        description: '어디에 얼마나 썼는지 도넛 차트로 확인해보세요',
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<UserModel?>(
      stream: UserService().watchUser(widget.uid),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const _DashboardSkeleton();
        }
        final user = snapshot.data!;
        unawaited(_maybeStartTour());

        return Stack(
          children: [
            Positioned(
              top: -30,
              right: -50,
              child: _HomeBlob(color: _C.amberSoft, size: 190)
                  .animate(onPlay: (c) => c.repeat(reverse: true))
                  .moveY(begin: 0, end: 18, duration: 3600.ms, curve: Curves.easeInOut),
            ),
            Positioned(
              top: 420,
              left: -60,
              child: _HomeBlob(color: _C.mintSoft, size: 150)
                  .animate(onPlay: (c) => c.repeat(reverse: true))
                  .moveY(begin: 0, end: -16, duration: 3200.ms, curve: Curves.easeInOut),
            ),
            Positioned(
              top: 720,
              right: -40,
              child: _HomeBlob(color: _C.pinkSoft, size: 130)
                  .animate(onPlay: (c) => c.repeat(reverse: true))
                  .moveY(begin: 0, end: 14, duration: 3800.ms, curve: Curves.easeInOut),
            ),
            RefreshIndicator(
              color: _C.amber,
              onRefresh: () async {},
              child: SingleChildScrollView(
                physics:
                const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                padding: EdgeInsets.zero,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    KeyedSubtree(
                      key: _budgetHeroKey,
                      child: _LiveBudgetSection(
                          uid: widget.uid, user: user, month: _month, weekAnchor: _selectedDay),
                    ),

                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          KeyedSubtree(key: _quickActionsKey, child: const _QuickActionsGrid()),
                          const SizedBox(height: 24),

                          KeyedSubtree(
                            key: _categoryCardKey,
                            child: _CategorySpendingSection(uid: widget.uid, month: _month),
                          ),
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
                            onChanged: (bool value) {
                              setState(() {
                                _isGroupMode = value;
                              });

                              if (value && !_hasLoadedGroups) {
                                _loadMyGroups();
                              }
                            },
                          ),
                          if (_isGroupMode) ...[
                            const SizedBox(height: 10),

                            // 새 그룹 생성 및 초대 코드 참여 화면 이동 버튼
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton.icon(
                                onPressed: () async {
                                  await Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => const GroupCreateJoinScreen(),
                                    ),
                                  );

                                  if (!mounted) {
                                    return;
                                  }

                                  await _loadMyGroups();
                                },
                                icon: const Icon(
                                  Icons.group_add_rounded,
                                  size: 18,
                                ),
                                label: const Text('새 그룹 만들기'),
                                style: TextButton.styleFrom(
                                  foregroundColor: _C.purple,
                                  textStyle: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 6),

                            _HomeGroupList(
                              groups: _myGroups,
                              isLoading: _isLoadingGroups,
                              onGroupTap: (GroupModel group) {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => SharedExpenseListScreen(
                                      group: group,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
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

                          _LiveSpendingInsightSection(
                              uid: widget.uid, nickname: user.nickname, month: _month),
                          const SizedBox(height: 20),

                          _LiveChallengeSection(uid: widget.uid, tone: user.coachTone),
                          const SizedBox(height: 20),

                          _LiveWeeklyBriefingSection(uid: widget.uid, tone: user.coachTone),
                        ]
                            .animate(interval: 55.ms)
                            .fadeIn(duration: 320.ms, curve: Curves.easeOut)
                            .slideY(begin: 0.05, end: 0, curve: Curves.easeOutCubic),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// 대시보드 배경에 은은하게 떠다니는 장식 블롭.
class _HomeBlob extends StatelessWidget {
  final Color color;
  final double size;
  const _HomeBlob({required this.color, required this.size});

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

// ─────────────────────── 예산 히어로(인사말 통합) + 통계 카드 (실데이터 로더) ───────────────────────

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
  final UserModel user;
  final DateTime month;
  final DateTime weekAnchor;
  const _LiveBudgetSection({
    required this.uid,
    required this.user,
    required this.month,
    required this.weekAnchor,
  });

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
      setState(() {
        _future = _load();
      });
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
          return const _ShimmerBlock(height: 220, radius: 0);
        }
        final stats = snap.data ??
            const _BudgetStats(total: 0, spent: 0, weekSpent: 0, topCategory: ('지출 없음', 0.0));
        final remaining = stats.total - stats.spent;
        final progress =
        stats.total == 0 ? 0.0 : (stats.spent / stats.total).clamp(0.0, 1.0);

        return Column(
          children: [
            _BudgetHero(
                user: widget.user,
                remaining: remaining,
                total: stats.total,
                progress: progress,
                onBudgetChanged: () => setState(() {
                  _future = _load();
                }))
                .animate()
                .fadeIn(duration: 380.ms, curve: Curves.easeOut)
                .slideY(begin: 0.06, end: 0, curve: Curves.easeOutCubic),

            // 히어로 카드 아래로 살짝 겹치는 레이어드 통계 카드
            Transform.translate(
              offset: const Offset(0, -28),
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
  final UserModel user;
  final int remaining;
  final int total;
  final double progress;
  final VoidCallback onBudgetChanged;

  const _BudgetHero({
    required this.user,
    required this.remaining,
    required this.total,
    required this.progress,
    required this.onBudgetChanged,
  });

  @override
  Widget build(BuildContext context) {
    const heroRadius = BorderRadius.only(
      bottomLeft: Radius.circular(36),
      bottomRight: Radius.circular(36),
    );
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 44),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFC168), Color(0xFFFF7A45), Color(0xFFFF5C7A)],
          stops: [0.0, 0.55, 1.0],
        ),
        borderRadius: heroRadius,
        boxShadow: [
          BoxShadow(
              color: const Color(0xFFFF6A66).withValues(alpha: 0.4),
              blurRadius: 30,
              offset: const Offset(0, 16)),
        ],
      ),
      child: Stack(
        // 텍스트를 포함한 콘텐츠는 ClipRRect로 감싸지 않는다 — 이 에뮬레이터의
        // GPU 렌더링 파이프라인에서 ClipRRect(둥근 모서리 클립)가 그 안의 텍스트
        // 첫 글자를 깨뜨리는 렌더링 버그가 실제로 확인되어, 장식용 원은 클리핑 없이
        // 살짝 넘치는 쪽을 택했다 (부드러운 그라데이션이라 시각적 차이는 거의 없음).
        children: [
          Positioned(
            top: -60,
            right: -40,
            child: Container(
              width: 170,
              height: 170,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [Colors.white.withValues(alpha: 0.22), Colors.white.withValues(alpha: 0.0)],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -70,
            left: -50,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [Colors.white.withValues(alpha: 0.12), Colors.white.withValues(alpha: 0.0)],
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
                    padding: const EdgeInsets.all(2.5),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withValues(alpha: 0.6), width: 1.6),
                    ),
                    child: CircleAvatar(
                      radius: 19,
                      backgroundColor: Colors.white,
                      backgroundImage: AssetImage(user.coachTone.imagePath),
                    ),
                  )
                      .animate(onPlay: (c) => c.repeat(reverse: true))
                      .scaleXY(begin: 1.0, end: 1.05, duration: 1900.ms, curve: Curves.easeInOut),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text('${user.nickname}님, 오늘도 파이팅!',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 14.5, fontWeight: FontWeight.w800, color: Colors.white)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.24),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('Lv.${user.level} · ${user.points}P',
                        style: const TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white)),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text('이번 달 남은 예산',
                                style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white.withValues(alpha: 0.92))),
                            const SizedBox(width: 6),
                            InkWell(
                              borderRadius: BorderRadius.circular(20),
                              onTap: () => Navigator.of(context)
                                  .push(MaterialPageRoute(
                                  builder: (_) => BudgetSettingScreen(userId: user.userId)))
                                  .then((_) => onBudgetChanged()),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.22),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.settings_outlined, size: 14, color: Colors.white),
                                    const SizedBox(width: 3),
                                    const Text('예산 설정',
                                        style: TextStyle(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white)),
                                    if (total == 0) ...[
                                      const SizedBox(width: 3),
                                      Container(
                                        width: 14,
                                        height: 14,
                                        decoration: const BoxDecoration(
                                          color: Color(0xFFFF3B30),
                                          shape: BoxShape.circle,
                                        ),
                                        alignment: Alignment.center,
                                        child: const Text('!',
                                            style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w900,
                                                color: Colors.white,
                                                height: 1)),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(comma(remaining),
                                style: _displayNumber(fontSize: 38, color: Colors.white)),
                            Padding(
                              padding: const EdgeInsets.only(left: 4, bottom: 4),
                              child: Text('원',
                                  style: GoogleFonts.jua(
                                      fontSize: 16, color: Colors.white, height: 1)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Text('전체 ${comma(total)}원 중 여유',
                            style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: Colors.white)),
                      ],
                    ),
                  ),
                  InkWell(
                    borderRadius: BorderRadius.circular(50),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => BudgetVsExpenseScreen(userId: user.userId),
                      ),
                    ),
                    child: CircularPercentIndicator(
                      radius: 42,
                      lineWidth: 9,
                      percent: progress,
                      animation: true,
                      animationDuration: 700,
                      circularStrokeCap: CircularStrokeCap.round,
                      backgroundColor: Colors.white.withValues(alpha: 0.28),
                      progressColor: Colors.white,
                      center: Text('${(progress * 100).round()}%',
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────── 히어로 위에 뜨는 글래스모피즘 통계 카드 ───────────────────────

class _FloatingStatsRow extends StatelessWidget {
  final int weekSpent;
  final (String, double) topCategory;

  const _FloatingStatsRow({required this.weekSpent, required this.topCategory});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 108,
      child: Row(
        children: [
          _StatCard(
            icon: Icons.calendar_view_week_rounded,
            iconColor: _C.mint,
            label: '이번 주 지출',
            value: '${comma(weekSpent)}원',
          ),
          const SizedBox(width: 12),
          _StatCard(
            icon: Icons.local_fire_department_rounded,
            iconColor: _C.pink,
            label: '최다 지출 카테고리',
            value: '${topCategory.$1} · ${(topCategory.$2 * 100).round()}%',
          ),
        ],
      ),
    );
  }
}

/// 히어로 그라데이션 위에 겹치는 반투명 카드.
/// 실제 BackdropFilter 블러 대신 그라데이션+테두리로 유리질감을 흉내낸다 —
/// 에뮬레이터 소프트웨어 렌더링에서 블러가 겹치는 텍스트를 오염시키는 문제를 피하기 위함.
class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.white.withValues(alpha: 0.92), Colors.white.withValues(alpha: 0.72)],
          ),
          border: Border.all(color: Colors.white.withValues(alpha: 0.85), width: 1.4),
          boxShadow: [
            BoxShadow(color: const Color(0xFFFF7A45).withValues(alpha: 0.16), blurRadius: 18, offset: const Offset(0, 8)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: iconColor,
                borderRadius: BorderRadius.circular(9),
                boxShadow: [
                  BoxShadow(color: iconColor.withValues(alpha: 0.35), blurRadius: 8, offset: const Offset(0, 3)),
                ],
              ),
              alignment: Alignment.center,
              child: Icon(icon, size: 15, color: Colors.white),
            ),
            const SizedBox(height: 8),
            Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 10.5, fontWeight: FontWeight.w600, color: _C.inkSub)),
            const SizedBox(height: 2),
            Text(value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 13.5, fontWeight: FontWeight.w800, color: _C.ink)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────── 빠른 실행 (4칸 그리드) ───────────────────────

class _QuickActionsGrid extends StatelessWidget {
  const _QuickActionsGrid();

  @override
  Widget build(BuildContext context) {
    final items = [
      _QuickActionButton(
        label: '내역입력',
        icon: Icons.edit_note_rounded,
        bg: _C.amberSoft,
        fg: _C.amberDeep,
        onTap: (context) => Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const RecordTypeSelectScreen()))
            .then((_) => HomeRefreshService.requestRefresh()),
      ),
      _QuickActionButton(
        // 기존 영수증 촬영 자리를 월간 브리핑 바로가기로 변경한다.
        label: '월간 브리핑',
        icon: Icons.analytics_rounded,
        bg: _C.mintSoft,
        fg: _C.mint,
        onTap: (context) => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const MonthlyBriefingScreen(),
          ),
        ),
      ),
      _QuickActionButton(
        label: '구독관리',
        icon: Icons.autorenew_rounded,
        bg: _C.pinkSoft,
        fg: _C.pink,
        onTap: (context) => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => SubscriptionListScreen(
                userId: FirebaseAuth.instance.currentUser!.uid,
              ),
            )),
      ),
      _QuickActionButton(
        label: '여행관리',
        icon: Icons.flight_takeoff_rounded,
        bg: _C.blueSoft,
        fg: _C.blue,
        onTap: (context) => Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const TravelListScreen())),
      ),
    ];

    return AnimationLimiter(
      child: Row(
        children: List.generate(items.length, (i) {
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: i == items.length - 1 ? 0 : 12),
              child: AnimationConfiguration.staggeredList(
                position: i,
                duration: const Duration(milliseconds: 420),
                delay: const Duration(milliseconds: 60),
                child: ScaleAnimation(
                  scale: 0.7,
                  child: FadeInAnimation(child: items[i]),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _QuickActionButton extends StatefulWidget {
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
  State<_QuickActionButton> createState() => _QuickActionButtonState();
}

class _QuickActionButtonState extends State<_QuickActionButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.onTap == null ? null : (_) => setState(() => _pressed = true),
      onTapUp: widget.onTap == null ? null : (_) => setState(() => _pressed = false),
      onTapCancel: widget.onTap == null ? null : () => setState(() => _pressed = false),
      onTap: widget.onTap == null ? null : () => widget.onTap!(context),
      child: AnimatedScale(
        scale: _pressed ? 0.9 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [widget.bg, Color.lerp(widget.bg, Colors.white, 0.15)!],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                      color: widget.fg.withValues(alpha: 0.16), blurRadius: 10, offset: const Offset(0, 5)),
                ],
              ),
              alignment: Alignment.center,
              child: Icon(widget.icon, size: 21, color: widget.fg),
            ),
            const SizedBox(height: 8),
            Text(widget.label,
                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: _C.ink)),
          ],
        ),
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

// 홈 화면에 참여 중인 그룹을 3개씩 표시하는 위젯
class _HomeGroupList extends StatefulWidget {
  const _HomeGroupList({
    required this.groups,
    required this.isLoading,
    required this.onGroupTap,
  });

  final List<GroupModel> groups;
  final bool isLoading;
  final ValueChanged<GroupModel> onGroupTap;

  @override
  State<_HomeGroupList> createState() => _HomeGroupListState();
}

class _HomeGroupListState extends State<_HomeGroupList> {
  static const int _pageSize = 3;

  int _currentPage = 0;

  // 전체 페이지 수를 계산
  int get _totalPages {
    if (widget.groups.isEmpty) {
      return 0;
    }

    return (widget.groups.length / _pageSize).ceil();
  }

  // 현재 페이지에 표시할 그룹 목록을 반환
  List<GroupModel> get _visibleGroups {
    if (widget.groups.isEmpty) {
      return [];
    }

    final int startIndex = _currentPage * _pageSize;
    final int endIndex = (startIndex + _pageSize)
        .clamp(0, widget.groups.length);

    return widget.groups.sublist(startIndex, endIndex);
  }

  @override
  void didUpdateWidget(covariant _HomeGroupList oldWidget) {
    super.didUpdateWidget(oldWidget);

    // 그룹 삭제 등으로 전체 페이지 수가 줄었을 때 페이지 위치 보정
    final int lastPage =
    _totalPages > 0 ? _totalPages - 1 : 0;

    if (_currentPage > lastPage) {
      _currentPage = lastPage;
    }
  }

  // 이전 페이지로 이동
  void _movePreviousPage() {
    if (_currentPage <= 0) {
      return;
    }

    setState(() {
      _currentPage--;
    });
  }

  // 다음 페이지로 이동
  void _moveNextPage() {
    if (_currentPage >= _totalPages - 1) {
      return;
    }

    setState(() {
      _currentPage++;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isLoading) {
      return const SizedBox(
        height: 72,
        child: Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: _C.purple,
          ),
        ),
      );
    }

    if (widget.groups.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: _C.cardShadow,
        ),
        child: const Row(
          children: [
            Icon(
              Icons.group_off_rounded,
              color: _C.inkSub,
            ),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                '참여 중인 그룹이 없어요.',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _C.inkSub,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        ..._visibleGroups.map(_buildGroupCard),

        if (_totalPages > 1) ...[
          const SizedBox(height: 4),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                tooltip: '이전 그룹',
                onPressed:
                _currentPage > 0 ? _movePreviousPage : null,
                visualDensity: VisualDensity.compact,
                icon: const Icon(
                  Icons.chevron_left_rounded,
                ),
              ),

              Text(
                '${_currentPage + 1} / $_totalPages',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: _C.inkSub,
                ),
              ),

              IconButton(
                tooltip: '다음 그룹',
                onPressed: _currentPage < _totalPages - 1
                    ? _moveNextPage
                    : null,
                visualDensity: VisualDensity.compact,
                icon: const Icon(
                  Icons.chevron_right_rounded,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  // 참여 중인 그룹 카드 생성
  Widget _buildGroupCard(GroupModel group) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => widget.onGroupTap(group),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 13,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: _C.cardShadow,
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: const BoxDecoration(
                  color: _C.purple,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.groups_rounded,
                  size: 18,
                  color: Colors.white,
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      group.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: _C.ink,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${group.memberCount}명 참여 · 공동지출 보기',
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: _C.inkSub,
                      ),
                    ),
                  ],
                ),
              ),

              const Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: _C.inkSub,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
// ─────────────────────── 개인/그룹 토글 ───────────────────────

/// 그룹 모드 선택 시 뜨는 안내 배너 — 토글 자체는 보기 전환일 뿐이고,
/// 실제 "새 그룹 만들기/참여하기" 이동은 이 버튼으로 분리한다.
class _GroupManageBanner extends StatelessWidget {
  final VoidCallback onTap;
  const _GroupManageBanner({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: _C.cardShadow,
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: const BoxDecoration(color: _C.purple, shape: BoxShape.circle),
              alignment: Alignment.center,
              child: const Icon(Icons.group_add_rounded, size: 17, color: Colors.white),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text('새 그룹 만들기 · 초대 코드로 참여하기',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _C.ink)),
            ),
            const Icon(Icons.chevron_right_rounded, size: 20, color: _C.inkSub),
          ],
        ),
      ),
    );
  }
}

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
                color: const Color(0xFFFF8A45).withValues(alpha: 0.3),
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
      setState(() {
        _future = _load();
      });
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
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, _C.amberSoft.withValues(alpha: 0.55)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: _C.cardShadow,
      ),
      child: AnimationLimiter(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: List.generate(days.length, (i) {
            final d = days[i];
            final isSelected = d.day == selectedDay.day && d.month == selectedDay.month;
            final isToday = _isSameDate(d, DateTime.now());
            final amount = dailySpend[d.day];

            return AnimationConfiguration.staggeredList(
              position: i,
              duration: const Duration(milliseconds: 360),
              delay: const Duration(milliseconds: 40),
              child: ScaleAnimation(
                scale: 0.8,
                child: FadeInAnimation(
                  child: GestureDetector(
                    onTap: () => onSelect(d),
                    child: Column(
                      children: [
                        Text(_weekLabels[d.weekday % 7],
                            style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: isToday ? _C.pink : _C.inkSub)),
                        const SizedBox(height: 7),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 160),
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: isSelected
                                ? const LinearGradient(colors: [Color(0xFFFFB648), Color(0xFFFF7A45)])
                                : null,
                            border:
                            (!isSelected && isToday) ? Border.all(color: _C.pink, width: 1.6) : null,
                            boxShadow: isSelected
                                ? [
                              BoxShadow(
                                  color: const Color(0xFFFF7A45).withValues(alpha: 0.4),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4)),
                            ]
                                : null,
                          ),
                          alignment: Alignment.center,
                          child: Text('${d.day}',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
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
                  ),
                ),
              ),
            );
          }),
        ),
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

enum _CoachMood { happy, neutral, concerned }

class _CoachBubbleState extends State<_CoachBubble> {
  late Future<(String, _CoachMood)> _stateFuture;

  @override
  void initState() {
    super.initState();
    _stateFuture = _load();
  }

  @override
  void didUpdateWidget(covariant _CoachBubble old) {
    super.didUpdateWidget(old);
    if (old.uid != widget.uid || old.tone != widget.tone) {
      _stateFuture = _load();
    }
  }

  /// 이번 달 카테고리별 실제 지출(CategorySummaryService) + 감정 태그 집계
  /// (EmotionSummaryService) + 예산 사용률(BudgetService)을 함께 불러와서,
  /// 땡코치 AI(은동 PC 로컬 Ollama) 잔소리 문구와 캐릭터 기분을 같이 계산한다.
  /// 기분은 예산 사용률 기준(새 그림 없이 이모지 배지+애니메이션으로만 표현).
  Future<(String, _CoachMood)> _load() async {
    final now = DateTime.now();
    final monthStr = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    final results = await Future.wait([
      CategorySummaryService().getCategorySummary(
        userId: widget.uid,
        year: now.year,
        month: now.month,
      ),
      EmotionSummaryService().getEmotionSummary(
        userId: widget.uid,
        year: now.year,
        month: now.month,
      ),
      BudgetService().getBudget(userId: widget.uid, month: monthStr),
    ]);
    final summaries = results[0] as List<CategorySummaryModel>;
    final emotions = results[1] as List<EmotionSummaryModel>;
    final budget = results[2] as BudgetModel?;

    _CoachMood mood;
    if (budget != null && budget.availableBudget > 0) {
      final spent = summaries.fold<int>(0, (sum, s) => sum + s.totalAmount);
      final usedPercent = spent / budget.availableBudget * 100;
      mood = usedPercent >= 100
          ? _CoachMood.concerned
          : usedPercent >= 70
          ? _CoachMood.neutral
          : _CoachMood.happy;
    } else {
      mood = _CoachMood.neutral;
    }

    if (summaries.isEmpty) {
      return ('이번 달 지출 기록이 아직 없어요. 첫 기록을 남겨서 저와 함께 시작해볼까요?', mood);
    }

    final top = summaries.first;

    // _LiveSpendingInsightSection과 같은 기준(30% 이상)일 때만 감정 정보를
    // 얹는다 — 신호가 약할 땐 굳이 언급하지 않아 잔소리가 산만해지지 않게.
    EmotionSummaryModel? stress;
    for (final e in emotions) {
      if (e.emotionKey == 'stress') {
        stress = e;
        break;
      }
    }
    final emotionNote = (stress != null && stress.percentage >= 30)
        ? ' 그리고 이번 달 지출의 ${stress.percentage.round()}%는 스트레스로 인한 소비였어요.'
        : '';

    final dataSummary =
        '이번 달 최다 지출 카테고리: ${top.categoryName} ${_won(top.totalAmount)} '
        '(전체 지출의 ${top.percentage.round()}%).$emotionNote';

    String message;
    try {
      message = await AiService().generateNagging(widget.tone, dataSummary);
    } on AiServerException {
      message = '$dataSummary (AI 코치가 잠깐 자리를 비웠어요 — 은동 PC 연결을 확인해주세요)';
    } catch (_) {
      message = dataSummary;
    }
    return (message, mood);
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
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(color: _C.pink.withValues(alpha: 0.28), blurRadius: 18, offset: const Offset(0, 8)),
        ],
      ),
      // 텍스트를 포함한 콘텐츠는 ClipRRect로 감싸지 않는다 — _BudgetHero에서 확인된
      // 렌더링 버그(ClipRRect가 그 안의 텍스트 첫 글자를 깨뜨림)를 피하기 위해,
      // 둥근 모서리는 바깥 Container의 BoxDecoration만으로 처리하고 장식 원은
      // 클리핑 없이 살짝 넘치게 둔다.
      child: Stack(
        children: [
          Positioned(
            top: -34,
            right: -18,
            child: Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [Colors.white.withValues(alpha: 0.18), Colors.white.withValues(alpha: 0.0)],
                ),
              ),
            ),
          ),
          FutureBuilder<(String, _CoachMood)>(
            future: _stateFuture,
            builder: (context, snap) {
              final mood = snap.data?.$2 ?? _CoachMood.neutral;
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _CoachAvatarWithMood(imagePath: widget.tone.imagePath, mood: mood),
                  const SizedBox(width: 12),
                  Expanded(
                    child: snap.connectionState != ConnectionState.done
                        ? const _CoachBubbleLoading()
                        : Text(
                      snap.data?.$1 ?? '오늘도 현명한 소비 하고 계신가요?',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

/// 예산 사용률에 따른 코치 캐릭터 기분 표현 — 새 그림 에셋 없이 기존 아바타
/// 이미지 위에 작은 이모지 배지를 얹고, 애니메이션(평소엔 은은한 pulse, 예산
/// 초과 임박이면 살짝 흔들리는 shake)만으로 반응하는 느낌을 낸다.
class _CoachAvatarWithMood extends StatelessWidget {
  final String imagePath;
  final _CoachMood mood;
  const _CoachAvatarWithMood({required this.imagePath, required this.mood});

  String get _emoji {
    switch (mood) {
      case _CoachMood.happy:
        return '😊';
      case _CoachMood.neutral:
        return '😐';
      case _CoachMood.concerned:
        return '😰';
    }
  }

  @override
  Widget build(BuildContext context) {
    final avatar = Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.24),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
      ),
      alignment: Alignment.center,
      child: CoachAvatar(imagePath: imagePath, size: 30),
    );

    return Stack(
      clipBehavior: Clip.none,
      children: [
        mood == _CoachMood.concerned
            ? avatar.animate(onPlay: (c) => c.repeat(reverse: true)).shake(
            hz: 2.5, duration: 900.ms, curve: Curves.easeInOut, offset: const Offset(1.5, 0))
            : avatar
            .animate(onPlay: (c) => c.repeat(reverse: true))
            .scaleXY(begin: 1.0, end: 1.05, duration: 1800.ms, curve: Curves.easeInOut),
        Positioned(
          bottom: -4,
          right: -4,
          child: Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFFF5C8A), width: 1.5),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 3, offset: const Offset(0, 1)),
              ],
            ),
            alignment: Alignment.center,
            child: Text(_emoji, style: const TextStyle(fontSize: 13, height: 1)),
          ),
        ),
      ],
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
        color: Colors.white.withValues(alpha: 0.35),
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

/// 카테고리 색상 팔레트.
///
/// 원래는 food/transport/shopping/culture/housing/etc 6개 대분류 키로 고정
/// 매핑돼 있었는데, 실제 categories 컬렉션(임예림 파트)은 "차량정비"·"생필품"·
/// "병원" 같은 훨씬 세분화된 소분류 키/이름을 그대로 쓰고 있어서 6개 키 어디에도
/// 걸리지 않는 카테고리는 전부 회색 폴백으로만 보이는 문제가 있었다.
/// 매핑 테이블을 계속 늘리는 대신, 이름을 해시해서 팔레트에서 안정적으로 색을
/// 골라 쓴다 — 같은 카테고리는 항상 같은 색이 나오고, 카테고리가 새로 늘어나도
/// 이 파일을 다시 손댈 필요가 없다.
const _categoryPalette = <Color>[
  _C.amber,
  _C.blue,
  _C.pink,
  _C.mint,
  _C.purple,
  Color(0xFFE07A5F),
  Color(0xFF3D9970),
  Color(0xFF9B6B9E),
  Color(0xFFD4A017),
  Color(0xFF5B8DB8),
];

Color _colorForCategory(String key) =>
    _categoryPalette[key.hashCode.abs() % _categoryPalette.length];

/// 아이콘은 이 화면에서 따로 매핑을 관리하지 않고, 소분류 이름(예: "차량정비")
/// 기준으로 이미 있는 공용 매핑(CategoryIconMap, 지출 입력 화면과 동일)을 그대로
/// 재사용한다 — categoryKey가 아니라 categoryName으로 조회해야 매칭된다.
IconData _iconForCategory(String name) => CategoryIconMap.iconFor(name);

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
      setState(() {
        _future = _load();
      });
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
            s.categoryName, s.totalAmount, _colorForCategory(s.categoryKey)))
            .toList();
        return _CategorySpendingCard(
          slices: slices,

          // 추가: 홈 카드의 '전체보기'를 누르면 로그인 회원의
          // 카테고리별 월간 지출 상세 화면으로 이동한다.
          onViewAll: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (BuildContext context) {
                  return CategorySummaryScreen(
                    userId: widget.uid,
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}

class _CategorySpendingCard extends StatefulWidget {
  final List<_CategorySlice> slices;

  // 추가: 카테고리별 지출 상세 화면 이동 콜백
  final VoidCallback onViewAll;

  const _CategorySpendingCard({
    required this.slices,
    required this.onViewAll,
  });

  @override
  State<_CategorySpendingCard> createState() => _CategorySpendingCardState();
}

class _CategorySpendingCardState extends State<_CategorySpendingCard> {
  int? _touchedIndex;

  @override
  Widget build(BuildContext context) {
    final slices = widget.slices;
    final total = slices.fold<int>(0, (sum, s) => sum + s.amount);

    if (slices.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.white, _C.blueSoft.withValues(alpha: 0.4)],
          ),
          borderRadius: BorderRadius.circular(22),
          boxShadow: _C.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 추가: 지출 기록이 없어도 상세 화면을 열 수 있는 전체보기 버튼
            Row(
              children: [
                const Expanded(
                  child: Text(
                    '카테고리별 지출',
                    style: TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w800,
                      color: _C.ink,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: widget.onViewAll,
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('전체보기'),
                      SizedBox(width: 2),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 18,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text('이번 달 지출 기록이 아직 없어요',
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500, color: _C.inkSub)),
          ],
        ),
      );
    }

    final touched = _touchedIndex != null ? slices[_touchedIndex!] : null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, _C.blueSoft.withValues(alpha: 0.4)],
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: _C.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 추가: 카테고리 도넛 차트 우측에 상세 화면 이동 버튼 표시
          Row(
            children: [
              const Expanded(
                child: Text(
                  '카테고리별 지출',
                  style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                    color: _C.ink,
                  ),
                ),
              ),
              TextButton(
                onPressed: widget.onViewAll,
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('전체보기'),
                    SizedBox(width: 2),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text('탭하면 카테고리별 비중을 볼 수 있어요',
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500, color: _C.inkSub)),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 132,
                height: 132,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    PieChart(
                      PieChartData(
                        pieTouchData: PieTouchData(
                          touchCallback: (event, response) {
                            if (!event.isInterestedForInteractions ||
                                response?.touchedSection == null) {
                              setState(() => _touchedIndex = null);
                              return;
                            }
                            setState(() => _touchedIndex =
                                response!.touchedSection!.touchedSectionIndex);
                          },
                        ),
                        sections: [
                          for (final (i, s) in slices.indexed)
                            PieChartSectionData(
                              value: s.amount.toDouble(),
                              color: s.color,
                              radius: i == _touchedIndex ? 26 : 20,
                              showTitle: false,
                            ),
                        ],
                        centerSpaceRadius: 44,
                        sectionsSpace: 3,
                        startDegreeOffset: -90,
                      ),
                      duration: const Duration(milliseconds: 220),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: touched != null
                          ? [
                        Text('${(touched.amount / total * 100).round()}%',
                            textAlign: TextAlign.center,
                            style: _displayNumber(fontSize: 20, color: touched.color)),
                        Text(touched.label,
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 10.5, fontWeight: FontWeight.w600, color: _C.inkSub)),
                      ]
                          : [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            '${comma(total)}원',
                            textAlign: TextAlign.center,
                            style: _displayNumber(
                              fontSize: 15,
                              color: _C.ink,
                            ),
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          '총 지출',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w600,
                            color: _C.inkSub,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: AnimationLimiter(
                  child: Column(
                    children: List.generate(slices.length, (i) {
                      final s = slices[i];
                      return AnimationConfiguration.staggeredList(
                        position: i,
                        duration: const Duration(milliseconds: 380),
                        child: SlideAnimation(
                          horizontalOffset: 24,
                          child: FadeInAnimation(
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(10),
                                onTap: () => setState(
                                        () => _touchedIndex = _touchedIndex == i ? null : i),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  padding:
                                  const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: i == _touchedIndex
                                        ? s.color.withValues(alpha: 0.1)
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 9,
                                        height: 9,
                                        decoration: BoxDecoration(
                                            color: s.color, shape: BoxShape.circle),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(s.label,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                                fontSize: 12.5,
                                                fontWeight: i == _touchedIndex
                                                    ? FontWeight.w800
                                                    : FontWeight.w600,
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
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
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
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const TransactionHistoryScreen())),
              child: Row(
                children: const [
                  Text('전체보기',
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: _C.inkSub)),
                  Icon(Icons.chevron_right_rounded, size: 16, color: _C.inkSub),
                ],
              ),
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
              child: AnimationLimiter(
                child: Column(
                  children: [
                    for (final (i, e) in items.indexed) ...[
                      if (i > 0)
                        const Divider(height: 1, indent: 16, endIndent: 16, color: Color(0xFFF0EDF5)),
                      AnimationConfiguration.staggeredList(
                        position: i,
                        duration: const Duration(milliseconds: 380),
                        delay: const Duration(milliseconds: 40),
                        child: SlideAnimation(
                          horizontalOffset: 24,
                          child: FadeInAnimation(child: _ExpenseRow(item: e)),
                        ),
                      ),
                    ],
                  ],
                ),
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
    final color = _colorForCategory(item.categoryKey);
    final icon = _iconForCategory(item.categoryName);
    final date = '${item.date.month.toString().padLeft(2, '0')}.${item.date.day.toString().padLeft(2, '0')}';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 34,
            margin: const EdgeInsets.only(right: 10),
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
          ),
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [color.withValues(alpha: 0.18), color.withValues(alpha: 0.08)],
              ),
              shape: BoxShape.circle,
            ),
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

// ─────────────────────── 소비심리테스트 + 감정태그 실데이터 로더 ───────────────────────

/// resultType(psychology_test_progress_screen.dart의 채점 결과 코드) → 한글 유형명.
/// lib/screens/psychology/psychology_test_result_screen.dart의 _getResultData와
/// 같은 매핑을 유지해야 한다 — 그 화면이 표시하는 유형명과 항상 일치해야 하므로.
String _spendingTypeLabel(String? resultType) {
  switch (resultType) {
    case 'impulsive_spender':
      return '충동 소비형';
    case 'emotion_spender':
      return '감정 소비형';
    case 'balanced_spender':
      return '균형 소비형';
    case 'planned_spender':
      return '계획 소비형';
    default:
      return '테스트 전';
  }
}

class _SpendingInsight {
  final String? resultType; // null이면 아직 테스트를 안 한 상태
  final String tip;
  const _SpendingInsight({required this.resultType, required this.tip});
}

/// 소비심리테스트 최신 결과(PsychologyTestService) + 이번 달 감정 태그 집계
/// (EmotionSummaryService)를 함께 불러와 지갑멍 카드/소비 성향 카드를 그린다.
class _LiveSpendingInsightSection extends StatefulWidget {
  final String uid;
  final String nickname;
  final DateTime month;
  const _LiveSpendingInsightSection({
    required this.uid,
    required this.nickname,
    required this.month,
  });

  @override
  State<_LiveSpendingInsightSection> createState() => _LiveSpendingInsightSectionState();
}

class _LiveSpendingInsightSectionState extends State<_LiveSpendingInsightSection> {
  late Future<_SpendingInsight> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void didUpdateWidget(covariant _LiveSpendingInsightSection old) {
    super.didUpdateWidget(old);
    if (old.uid != widget.uid || old.month != widget.month) {
      setState(() {
        _future = _load();
      });
    }
  }

  // 소비심리 테스트 화면에서 돌아온 뒤 최신 결과를 다시 조회하는 메서드
  Future<void> _openPsychologyTest() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const PsychologyTestStartScreen(),
      ),
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _future = _load();
    });
  }

  Future<_SpendingInsight> _load() async {
    final results = await Future.wait([
      PsychologyTestService().getLatestTestResult(),
      EmotionSummaryService().getEmotionSummary(
          userId: widget.uid, year: widget.month.year, month: widget.month.month),
    ]);
    final testResult = results[0] as Map<String, dynamic>?;
    final emotions = results[1] as List<EmotionSummaryModel>;

    String tip;
    if (emotions.isEmpty) {
      tip = '이번 달은 감정 태그가 달린 지출이 아직 없어요. 지출 기록에 감정을 남기면 소비 습관을 더 자세히 알려드려요.';
    } else {
      EmotionSummaryModel? stress;
      for (final e in emotions) {
        if (e.emotionKey == 'stress') {
          stress = e;
          break;
        }
      }
      if (stress != null && stress.percentage >= 30) {
        tip = '감정 태그 중 스트레스 지출 비율이 ${stress.percentage.round()}%예요. '
            '이번 주는 배달·카페 소비를 조금 줄여보는 걸 추천해요.';
      } else {
        final top = emotions.first;
        tip = '이번 달은 ${top.emotionName} 소비가 ${top.percentage.round()}%로 가장 많아요.';
      }
    }

    return _SpendingInsight(resultType: testResult?['resultType'] as String?, tip: tip);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_SpendingInsight>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return Column(
            children: const [
              _ShimmerBlock(height: 88, radius: 20),
              SizedBox(height: 16),
              _ShimmerBlock(height: 130, radius: 20),
            ],
          );
        }
        final insight = snap.data ?? const _SpendingInsight(resultType: null, tip: '');
        final typeLabel = _spendingTypeLabel(insight.resultType);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _WalletTeaserCard(nickname: widget.nickname, spendingType: typeLabel),
            const SizedBox(height: 16),
            _SpendingTendencyCard(
              resultType: insight.resultType,
              type: typeLabel,
              tip: insight.resultType == null
                  ? '아직 소비심리 테스트를 안 하셨어요. 테스트하고 나만의 소비 유형을 확인해보세요!'
                  : insight.tip,
              hasResult: insight.resultType != null,
              onTestTap: _openPsychologyTest,
            ),
          ],
        );
      },
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
                Text('나의 소비 유형: $spendingType',
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
  final String? resultType;
  final String type;
  final String tip;
  final bool hasResult;
  final Future<void> Function() onTestTap;

  const _SpendingTendencyCard({
    required this.resultType,
    required this.type,
    required this.tip,
    required this.hasResult,
    required this.onTestTap,
  });
  // 소비심리 유형별 대표 색상을 반환하는 메서드
  Color _typeColor() {
    switch (resultType) {
      case 'impulsive_spender':
        return const Color(0xFFFF6B81);

      case 'emotion_spender':
        return const Color(0xFFFFA94D);

      case 'balanced_spender':
        return const Color(0xFF8566FF);

      case 'planned_spender':
        return const Color(0xFF36BFA0);

      default:
        return const Color(0xFF9A9DAA);
    }
  }

// 소비심리 유형별 연한 배경색을 반환하는 메서드
  Color _typeBackgroundColor() {
    switch (resultType) {
      case 'impulsive_spender':
        return const Color(0xFFFFEEF2);

      case 'emotion_spender':
        return const Color(0xFFFFF4E7);

      case 'balanced_spender':
        return const Color(0xFFF3F0FF);

      case 'planned_spender':
        return const Color(0xFFEAF9F5);

      default:
        return const Color(0xFFF4F5F7);
    }
  }

// 소비심리 유형별 아이콘을 반환하는 메서드
  IconData _typeIcon() {
    switch (resultType) {
      case 'impulsive_spender':
        return Icons.bolt_rounded;

      case 'emotion_spender':
        return Icons.cloud_rounded;

      case 'balanced_spender':
        return Icons.balance_rounded;

      case 'planned_spender':
        return Icons.event_note_rounded;

      default:
        return Icons.psychology_alt_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color typeColor = _typeColor();
    final Color backgroundColor = _typeBackgroundColor();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: typeColor.withValues(alpha: 0.25),
        ),
        boxShadow: [
          BoxShadow(
            color: typeColor.withValues(alpha: 0.12),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _typeIcon(),
                size: 17,
                color: typeColor,
              ),
              const SizedBox(width: 6),
              Text(
                hasResult ? '소비 성향: $type' : '소비 성향 미확인',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: typeColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            tip,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              color: typeColor.withValues(alpha: 0.82),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 14),
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onTestTap,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: typeColor.withValues(alpha: 0.16),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.psychology_alt_rounded,
                    size: 16,
                    color: typeColor,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    hasResult ? '테스트 다시 하기' : '소비심리 테스트하러가기',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: typeColor,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.arrow_forward_rounded,
                    size: 14,
                    color: typeColor,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────── 소비 챌린지 ───────────────────────

/// 매달 "지난달 대비 가장 많이 늘어난 카테고리" 절약 챌린지를 보여준다.
/// 지출 이력이 두 달 미만이면 아직 비교할 데이터가 없다는 안내만 보여준다.
class _LiveChallengeSection extends StatefulWidget {
  final String uid;
  final CoachTone tone;
  const _LiveChallengeSection({required this.uid, required this.tone});

  @override
  State<_LiveChallengeSection> createState() => _LiveChallengeSectionState();
}

class _LiveChallengeSectionState extends State<_LiveChallengeSection> {
  late Future<SpendingChallengeModel?> _future;

  @override
  void initState() {
    super.initState();
    _future = SpendingChallengeService().getOrCreateCurrentChallenge(widget.uid);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<SpendingChallengeModel?>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const _ShimmerBlock(height: 150, radius: 20);
        }
        final challenge = snap.data;
        if (challenge == null) {
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
                Text('이번 달 절약 챌린지',
                    style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800, color: _C.ink)),
                SizedBox(height: 4),
                Text('두 달 이상 지출 기록이 쌓이면 챌린지가 시작돼요',
                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500, color: _C.inkSub)),
              ],
            ),
          );
        }
        return _ChallengeCard(uid: widget.uid, tone: widget.tone, challenge: challenge);
      },
    );
  }
}

class _ChallengeCard extends StatefulWidget {
  final String uid;
  final CoachTone tone;
  final SpendingChallengeModel challenge;
  const _ChallengeCard({required this.uid, required this.tone, required this.challenge});

  @override
  State<_ChallengeCard> createState() => _ChallengeCardState();
}

class _ChallengeCardState extends State<_ChallengeCard> {
  late Future<int> _currentSpendFuture;
  late Future<String> _messageFuture;

  @override
  void initState() {
    super.initState();
    _currentSpendFuture = widget.challenge.status == 'in_progress'
        ? SpendingChallengeService().getCurrentSpend(widget.uid, widget.challenge.categoryKey)
        : Future.value(widget.challenge.previousAmount);
    _messageFuture = _buildMessage();
  }

  Future<String> _buildMessage() async {
    final c = widget.challenge;
    final dataSummary = '카테고리: ${c.categoryName}, 목표: ${comma(c.targetAmount)}원 이하, '
        '지난달: ${comma(c.previousAmount)}원';
    try {
      return await AiService().generateChallenge(widget.tone, dataSummary);
    } catch (_) {
      return '이번 달은 ${c.categoryName} 지출을 ${comma(c.targetAmount)}원 이하로 줄여봐요!';
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.challenge;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF34D399), Color(0xFF10B981)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: const Color(0xFF10B981).withValues(alpha: 0.3),
              blurRadius: 18,
              offset: const Offset(0, 8)),
        ],
      ),
      // ClipRRect로 감싸지 않는다 — home_screen.dart의 다른 카드들에서 확인된
      // 렌더링 버그(ClipRRect가 그 안의 텍스트 첫 글자를 깨뜨림)를 피하기 위해,
      // 장식 원은 클리핑 없이 살짝 넘치게 두고 진행률 바도 ClipRRect 없이 그린다.
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
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.24), shape: BoxShape.circle),
                    alignment: Alignment.center,
                    child: Icon(
                        c.status == 'success' ? Icons.emoji_events_rounded : Icons.eco_rounded,
                        size: 17,
                        color: Colors.white),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text('이번 달 절약 챌린지 · ${c.categoryName}',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 14.5, fontWeight: FontWeight.w800, color: Colors.white)),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (c.status == 'in_progress')
                FutureBuilder<int>(
                  future: _currentSpendFuture,
                  builder: (context, snap) {
                    final spent = snap.data ?? 0;
                    final progress =
                    c.targetAmount == 0 ? 0.0 : (spent / c.targetAmount).clamp(0.0, 1.0);
                    final over = spent > c.targetAmount;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Stack(
                          children: [
                            Container(
                              height: 8,
                              decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.28),
                                  borderRadius: BorderRadius.circular(8)),
                            ),
                            FractionallySizedBox(
                              widthFactor: progress,
                              child: Container(
                                height: 8,
                                decoration: BoxDecoration(
                                  color: over ? const Color(0xFFFFD166) : Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text('${comma(spent)}원 / 목표 ${comma(c.targetAmount)}원 이하',
                            style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
                      ],
                    );
                  },
                )
              else
                Text(
                  c.status == 'success'
                      ? '🎉 목표 달성! +${c.pointsReward}P 적립됐어요'
                      : '아쉽게 목표는 못 채웠어요. 다음 달에 다시 도전!',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white),
                ),
              const SizedBox(height: 12),
              FutureBuilder<String>(
                future: _messageFuture,
                builder: (context, snap) {
                  if (snap.connectionState != ConnectionState.done) {
                    return const SizedBox(height: 14);
                  }
                  return Text(snap.data ?? '',
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white, height: 1.4));
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────── 주간 브리핑 ───────────────────────

class _WeeklyBriefing {
  final int totalSpent;
  final int weekOverWeekPercent;
  final int noSpendDays;
  final int budgetRemainPercent;
  final String topCategory;
  final int topCategoryPercent;
  final String aiMessage;

  const _WeeklyBriefing({
    required this.totalSpent,
    required this.weekOverWeekPercent,
    required this.noSpendDays,
    required this.budgetRemainPercent,
    required this.topCategory,
    required this.topCategoryPercent,
    required this.aiMessage,
  });
}

/// 이번 주 지출을 요약해서 보여준다. 카테고리별 "주간" 집계 메서드가 따로 없어서
/// 최다 카테고리는 이번 달 집계로 근사한다(화면에도 그렇게 표시).
class _LiveWeeklyBriefingSection extends StatefulWidget {
  final String uid;
  final CoachTone tone;
  const _LiveWeeklyBriefingSection({required this.uid, required this.tone});

  @override
  State<_LiveWeeklyBriefingSection> createState() => _LiveWeeklyBriefingSectionState();
}

class _LiveWeeklyBriefingSectionState extends State<_LiveWeeklyBriefingSection> {
  late final Future<_WeeklyBriefing?> _future = _load();

  Future<_WeeklyBriefing?> _load() async {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday % 7));
    final lastWeekStart = weekStart.subtract(const Duration(days: 7));
    final monthStr = '${now.year}-${now.month.toString().padLeft(2, '0')}';

    final results = await Future.wait([
      CategorySummaryService().getWeeklyTotalExpense(userId: widget.uid, weekStart: weekStart),
      CategorySummaryService().getWeeklyTotalExpense(userId: widget.uid, weekStart: lastWeekStart),
      CategorySummaryService().getDailyTotals(userId: widget.uid, year: now.year, month: now.month),
      CategorySummaryService().getCategorySummary(userId: widget.uid, year: now.year, month: now.month),
      BudgetService().getBudget(userId: widget.uid, month: monthStr),
    ]);

    final thisWeekTotal = results[0] as int;
    final lastWeekTotal = results[1] as int;
    final dailyTotals = results[2] as Map<int, int>;
    final categories = results[3] as List<CategorySummaryModel>;
    final budget = results[4] as BudgetModel?;

    if (thisWeekTotal == 0 && lastWeekTotal == 0 && categories.isEmpty) return null;

    final wowPercent =
    lastWeekTotal == 0 ? 0 : (((thisWeekTotal - lastWeekTotal) / lastWeekTotal) * 100).round();

    var noSpendDays = 0;
    for (var i = 0; i < 7; i++) {
      final d = weekStart.add(Duration(days: i));
      if (d.isAfter(now)) break;
      if (d.month != now.month) continue;
      if ((dailyTotals[d.day] ?? 0) == 0) noSpendDays++;
    }

    final monthSpent = categories.fold<int>(0, (sum, c) => sum + c.totalAmount);
    final budgetRemainPercent = (budget == null || budget.availableBudget == 0)
        ? 0
        : (((budget.availableBudget - monthSpent) / budget.availableBudget) * 100)
        .round()
        .clamp(0, 100);

    final topCategory = categories.isEmpty ? null : categories.first;

    String aiMessage;
    try {
      aiMessage = await AiService().generateWeekly(
        widget.tone,
        totalSpent: thisWeekTotal,
        budgetRemainPercent: budgetRemainPercent,
        topCategory: topCategory?.categoryName ?? '없음',
        topCategoryPercent: topCategory == null ? 0 : topCategory.percentage.round(),
        noSpendDays: noSpendDays,
        weekOverWeekPercent: wowPercent,
      );
    } catch (_) {
      aiMessage = '이번 주도 잘 관리하고 계세요!';
    }

    return _WeeklyBriefing(
      totalSpent: thisWeekTotal,
      weekOverWeekPercent: wowPercent,
      noSpendDays: noSpendDays,
      budgetRemainPercent: budgetRemainPercent,
      topCategory: topCategory?.categoryName ?? '없음',
      topCategoryPercent: topCategory == null ? 0 : topCategory.percentage.round(),
      aiMessage: aiMessage,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_WeeklyBriefing?>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const _ShimmerBlock(height: 170, radius: 20);
        }
        final data = snap.data;
        if (data == null) {
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
                Text('이번 주 브리핑',
                    style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800, color: _C.ink)),
                SizedBox(height: 4),
                Text('이번 주 지출 기록이 쌓이면 브리핑을 보여드려요',
                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500, color: _C.inkSub)),
              ],
            ),
          );
        }

        final wow = data.weekOverWeekPercent;
        final wowText = wow == 0 ? '전주와 비슷해요' : (wow > 0 ? '전주 대비 +$wow%' : '전주 대비 $wow%');

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF6C93FF), Color(0xFF6C5CE7)],
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                  color: _C.purple.withValues(alpha: 0.3), blurRadius: 18, offset: const Offset(0, 8)),
            ],
          ),
          // ClipRRect로 감싸지 않는다 — 텍스트 첫 글자가 깨지는 렌더링 버그 회피
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('이번 주 브리핑',
                      style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: Colors.white)),
                  const SizedBox(height: 2),
                  Text(wowText,
                      style: const TextStyle(
                          fontSize: 11.5, fontWeight: FontWeight.w600, color: Colors.white70)),
                  const SizedBox(height: 14),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(comma(data.totalSpent),
                          style: _displayNumber(fontSize: 28, color: Colors.white)),
                      const Padding(
                        padding: EdgeInsets.only(left: 4, bottom: 3),
                        child: Text('원', style: TextStyle(fontSize: 13, color: Colors.white)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(child: _stat('무지출일', '${data.noSpendDays}일')),
                      Expanded(child: _stat('예산 잔여율', '${data.budgetRemainPercent}%')),
                      Expanded(
                          child: _stat('최다 카테고리(월)',
                              '${data.topCategory} ${data.topCategoryPercent}%')),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(data.aiMessage,
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white, height: 1.4)),
                  ),
                  const SizedBox(height: 10),
                  InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const MonthlyBriefingScreen())),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text('월간 브리핑 더보기',
                              style: TextStyle(
                                  fontSize: 11.5, fontWeight: FontWeight.w700, color: Colors.white)),
                          SizedBox(width: 2),
                          Icon(Icons.chevron_right_rounded, size: 15, color: Colors.white),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _stat(String label, String value) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.white70)),
      const SizedBox(height: 3),
      Text(value,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Colors.white)),
    ],
  );
}
