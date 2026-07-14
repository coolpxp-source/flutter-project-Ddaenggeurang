import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/coach_tone.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/user_service.dart';
import '../../utils/formatters.dart';
import '../../widgets/common/app_drawer.dart';
import '../../widgets/common/bottom_nav_bar.dart';
import '../../widgets/common/Placeholder_screen.dart';
import '../expense/expense_input_screen.dart';
import '../onboarding/onboarding_screen.dart'; // DdaengColors

/// 홈 화면 전용 Material 3 컬러 스킴.
/// 땡그랑 로고(assets/images/logo.png)는 민트 링 + 골드 코인 + 흰 배경이라
/// 앱 전역에서 쓰는 DdaengColors(남색 위주)와는 결이 다르다.
/// 대시보드는 로고에서 실제로 뽑은 민트를 seed로 Material 3 팔레트를
/// 자동 생성하고, 골드(coin) 톤만 DdaengColors.gold로 고정해 브랜드와
/// 맞춘다. AppBar/BottomNav/Drawer는 앱 공통 남색 그대로 유지.
final ColorScheme _dashboardScheme = ColorScheme.fromSeed(
  seedColor: const Color(0xFF3CAE93), // 로고 링 민트
  brightness: Brightness.light,
).copyWith(
  tertiary: DdaengColors.gold,
  onTertiary: DdaengColors.navy,
  tertiaryContainer: const Color(0xFFFFF1CC),
  onTertiaryContainer: const Color(0xFF6B4E00),
);

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
      backgroundColor: _dashboardScheme.surface,
      appBar: AppBar(
        backgroundColor: DdaengColors.navy,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('땡그랑',
            style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => AuthService().signOut(),
          ),
        ],
        // leading은 지정 안 해도 됨 — drawer가 있으면 Scaffold가
        // 햄버거 버튼을 자동으로 왼쪽에 넣어줌
      ),
      drawer: const AppDrawer(),
      bottomNavigationBar: BottomNavBar(
        currentTab: _currentTab,
        onTabSelected: (tab) => setState(() => _currentTab = tab),
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
        return const _TabPlaceholder(title: 'AI상담');
      case NavTab.community:
        return const _TabPlaceholder(title: '커뮤니티');
      case NavTab.myPage:
        return const _TabPlaceholder(title: '마이');
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
// 실제로 받아오고, 예산·달력별 지출·최근 지출 내역은 성기필(예산)·
// 임예림(지출기록) 파트가 아직 완성 전이라 지금은 더미 데이터로 틀만
// 잡아둔 상태. 각 위젯에 남긴 TODO 지점만 실제 스트림/서비스로
// 바꿔 끼우면 됨.
//
// 여기서부터는 Theme(colorScheme: _dashboardScheme)로 감싸서
// Card / Chip / SegmentedButton / IconButton.filledTonal / ListTile 같은
// Flutter 기본 Material 3 위젯을 최대한 그대로 사용한다.
// ══════════════════════════════════════════════════════════

class _HomeDashboard extends StatefulWidget {
  final String uid;
  const _HomeDashboard({required this.uid});

  @override
  State<_HomeDashboard> createState() => _HomeDashboardState();
}

class _HomeDashboardState extends State<_HomeDashboard> {
  bool _isGroupMode = false;
  DateTime _month = DateTime.now();
  late DateTime _selectedDay = DateTime.now();

  // ─── 더미 데이터 (백엔드 연동 전 임시) ───
  static const _mockBudgetTotal = 2000000;
  static const _mockBudgetSpent = 1240000;
  static const _mockWeekSpent = 34600;
  static const _mockTopCategory = ('식비', 0.42);
  static final _mockDailySpend = <int, int>{
    2: 0, 3: 0, 4: 6500, 5: 0, 6: 7040, 7: 0,
  };
  static const _mockRecent = <_MockExpense>[
    _MockExpense(
      place: '스타벅스', category: '식비', date: '10.06',
      amount: -6500, color: Color(0xFFF79009), icon: Icons.local_cafe_rounded,
    ),
    _MockExpense(
      place: '지하철', category: '교통', date: '10.06',
      amount: -1400, color: Color(0xFF3CAE93), icon: Icons.directions_subway_rounded,
    ),
    _MockExpense(
      place: '편의점', category: '생활', date: '10.05',
      amount: -4200, color: DdaengColors.gold, icon: Icons.storefront_rounded,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(colorScheme: _dashboardScheme),
      child: Builder(builder: (context) {
        final scheme = Theme.of(context).colorScheme;
        return StreamBuilder<UserModel?>(
          stream: UserService().watchUser(widget.uid),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return Center(child: CircularProgressIndicator(color: scheme.primary));
            }
            final user = snapshot.data!;
            final remaining = _mockBudgetTotal - _mockBudgetSpent;
            final progress = _mockBudgetTotal == 0
                ? 0.0
                : (_mockBudgetSpent / _mockBudgetTotal).clamp(0.0, 1.0);

            return RefreshIndicator(
              color: scheme.primary,
              onRefresh: () async {},
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics()),
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _BudgetHeroCard(user: user, remaining: remaining, progress: progress),
                    const SizedBox(height: 14),

                    _FloatingStatsRow(
                      weekSpent: _mockWeekSpent,
                      topCategory: _mockTopCategory,
                    ),
                    const SizedBox(height: 26),

                    const _QuickActionsRow(),
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

                    _WeekCalendarStrip(
                      selectedDay: _selectedDay,
                      dailySpend: _mockDailySpend,
                      onSelect: (d) => setState(() => _selectedDay = d),
                    ),
                    const SizedBox(height: 18),

                    _CoachBubble(tone: user.coachTone),
                    const SizedBox(height: 30),

                    _RecentExpensesSection(items: _mockRecent),
                  ],
                ),
              ),
            );
          },
        );
      }),
    );
  }
}

// ─────────────────────── 예산 히어로 카드 ───────────────────────

class _BudgetHeroCard extends StatelessWidget {
  final UserModel user;
  final int remaining;
  final double progress;

  const _BudgetHeroCard({
    required this.user,
    required this.remaining,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      color: scheme.primaryContainer,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 19,
                  backgroundColor: scheme.surface,
                  child: Text(user.coachTone.emoji, style: const TextStyle(fontSize: 18)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('${user.nickname}님, 오늘도 파이팅!',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 16.5,
                          fontWeight: FontWeight.w800,
                          color: scheme.onPrimaryContainer)),
                ),
                Chip(
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  backgroundColor: scheme.tertiaryContainer,
                  side: BorderSide.none,
                  label: Text('Lv.${user.level} · ${user.points}P',
                      style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: scheme.onTertiaryContainer)),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text('이번 달 남은 예산',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: scheme.onPrimaryContainer.withOpacity(0.7))),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(comma(remaining),
                    style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        color: scheme.onPrimaryContainer,
                        height: 1)),
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 3),
                  child: Text('원',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: scheme.onPrimaryContainer)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 8,
                      backgroundColor: scheme.surface,
                      valueColor: AlwaysStoppedAnimation(
                        progress >= 0.9 ? scheme.error : scheme.primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text('${(progress * 100).round()}%',
                    style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: scheme.onPrimaryContainer.withOpacity(0.85))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────── 요약 통계 카드 ───────────────────────

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
            label: '이번 주 지출',
            value: '${comma(weekSpent)}원',
            useSecondary: true,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            icon: Icons.local_fire_department_rounded,
            label: '최다 지출 카테고리',
            value: '${topCategory.$1} · ${(topCategory.$2 * 100).round()}%',
            useSecondary: false,
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool useSecondary;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.useSecondary,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final iconBg = useSecondary ? scheme.secondaryContainer : scheme.tertiaryContainer;
    final iconFg = useSecondary ? scheme.onSecondaryContainer : scheme.onTertiaryContainer;

    return Card(
      elevation: 1,
      shadowColor: scheme.shadow.withOpacity(0.08),
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(radius: 15, backgroundColor: iconBg,
                child: Icon(icon, size: 16, color: iconFg)),
            const SizedBox(height: 10),
            Text(label,
                style: TextStyle(
                    fontSize: 10.5, fontWeight: FontWeight.w600, color: scheme.outline)),
            const SizedBox(height: 2),
            Text(value,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 13.5, fontWeight: FontWeight.w800, color: scheme.onSurface)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────── 빠른 실행 (사이드바 주요 메뉴 바로가기) ───────────────────────

class _QuickActionsRow extends StatelessWidget {
  const _QuickActionsRow();

  @override
  Widget build(BuildContext context) {
    final actions = [
      _QuickAction('내역입력', Icons.edit_note_rounded, () => const ExpenseInputScreen()),
      _QuickAction('영수증', Icons.camera_alt_outlined,
              () => const PlaceholderScreen(title: '영수증 촬영 업로드')),
      _QuickAction('구독관리', Icons.autorenew_rounded,
              () => const PlaceholderScreen(title: '구독/정기결제 관리')),
      _QuickAction('여행관리', Icons.flight_takeoff_rounded,
              () => const PlaceholderScreen(title: '여행 관리')),
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: actions.map((a) => _QuickActionButton(action: a)).toList(growable: false),
    );
  }
}

class _QuickAction {
  final String label;
  final IconData icon;
  final Widget Function() destination;
  _QuickAction(this.label, this.icon, this.destination);
}

class _QuickActionButton extends StatelessWidget {
  final _QuickAction action;
  const _QuickActionButton({required this.action});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 72,
      child: Column(
        children: [
          // Flutter/Material 3 기본 제공 위젯 그대로 사용 (secondaryContainer 톤 자동 적용)
          IconButton.filledTonal(
            iconSize: 22,
            style: IconButton.styleFrom(minimumSize: const Size(54, 54)),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => action.destination()),
            ),
            icon: Icon(action.icon),
          ),
          const SizedBox(height: 6),
          Text(action.label,
              style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface)),
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
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        IconButton(
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.chevron_left_rounded),
          onPressed: onPrev,
        ),
        Text('${month.month}월',
            style: TextStyle(
                fontSize: 19, fontWeight: FontWeight.w800, color: scheme.onSurface)),
        IconButton(
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.chevron_right_rounded),
          onPressed: onNext,
        ),
        const Spacer(),
        IconButton(
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.notifications_none_rounded),
          onPressed: () {},
        ),
      ],
    );
  }
}

// ─────────────────────── 개인/그룹 토글 ───────────────────────
// Flutter 기본 SegmentedButton(M3) 그대로 사용.

class _ModeToggle extends StatelessWidget {
  final bool isGroup;
  final ValueChanged<bool> onChanged;

  const _ModeToggle({required this.isGroup, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: SegmentedButton<bool>(
        segments: const [
          ButtonSegment(value: false, label: Text('개인')),
          ButtonSegment(value: true, label: Text('그룹')),
        ],
        selected: {isGroup},
        showSelectedIcon: false,
        onSelectionChanged: (s) => onChanged(s.first),
        style: SegmentedButton.styleFrom(
          visualDensity: VisualDensity.comfortable,
        ),
      ),
    );
  }
}

// ─────────────────────── 주간 달력 스트립 ───────────────────────

class _WeekCalendarStrip extends StatelessWidget {
  final DateTime selectedDay;
  final Map<int, int> dailySpend; // day → 지출액(더미)
  final ValueChanged<DateTime> onSelect;

  const _WeekCalendarStrip({
    required this.selectedDay,
    required this.dailySpend,
    required this.onSelect,
  });

  static const _weekLabels = ['일', '월', '화', '수', '목', '금', '토'];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final start = selectedDay.subtract(Duration(days: selectedDay.weekday % 7));
    final days = List.generate(7, (i) => start.add(Duration(days: i)));

    return Card(
      elevation: 1,
      shadowColor: scheme.shadow.withOpacity(0.06),
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
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
                      style: TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w600, color: scheme.outline)),
                  const SizedBox(height: 6),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected ? scheme.primary : Colors.transparent,
                      border: (!isSelected && isToday)
                          ? Border.all(color: scheme.tertiary, width: 1.8)
                          : null,
                    ),
                    alignment: Alignment.center,
                    child: Text('${d.day}',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: isSelected
                              ? scheme.onPrimary
                              : (isToday ? scheme.onTertiaryContainer : scheme.onSurface),
                        )),
                  ),
                  const SizedBox(height: 4),
                  SizedBox(
                    height: 12,
                    child: (amount != null && amount > 0)
                        ? Text(
                      amount >= 10000 ? '${(amount / 10000).toStringAsFixed(1)}만' : '$amount',
                      style: TextStyle(
                          fontSize: 9.5, fontWeight: FontWeight.w700, color: scheme.primary),
                    )
                        : null,
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  bool _isSameDate(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

// ─────────────────────── 코치 말풍선 ───────────────────────

class _CoachBubble extends StatelessWidget {
  final CoachTone tone;
  const _CoachBubble({required this.tone});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: scheme.tertiaryContainer,
          child: Text(tone.emoji, style: const TextStyle(fontSize: 20)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Card(
            elevation: 0,
            color: scheme.tertiaryContainer,
            margin: EdgeInsets.zero,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(18),
                bottomLeft: Radius.circular(18),
                bottomRight: Radius.circular(18),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              // TODO: 카페 지출 등 실데이터 기반 코멘트로 교체 (지출 파트 완성 후)
              child: Text(
                '이번 달 카페값만 벌써 12,000원… 이러다 텅장 되는거 아니죠?',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: scheme.onTertiaryContainer,
                  height: 1.4,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────── 최근 지출 ───────────────────────

class _MockExpense {
  final String place;
  final String category;
  final String date;
  final int amount; // 음수 = 지출, 양수 = 수입
  final Color color;
  final IconData icon;

  const _MockExpense({
    required this.place,
    required this.category,
    required this.date,
    required this.amount,
    required this.color,
    required this.icon,
  });
}

class _RecentExpensesSection extends StatelessWidget {
  final List<_MockExpense> items;
  const _RecentExpensesSection({required this.items});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('최근 지출',
                style: TextStyle(
                    fontSize: 15.5, fontWeight: FontWeight.w800, color: scheme.onSurface)),
            TextButton.icon(
              onPressed: () {},
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                foregroundColor: scheme.outline,
              ),
              icon: const Icon(Icons.chevron_right_rounded, size: 16),
              iconAlignment: IconAlignment.end,
              label: const Text('전체보기', style: TextStyle(fontSize: 12.5)),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Card(
          elevation: 0,
          color: scheme.surface,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(color: scheme.outlineVariant),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (final (i, e) in items.indexed) ...[
                if (i > 0) Divider(height: 1, color: scheme.outlineVariant),
                _ExpenseRow(item: e),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _ExpenseRow extends StatelessWidget {
  final _MockExpense item;
  const _ExpenseRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isIncome = item.amount > 0;
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: item.color.withOpacity(0.14),
        child: Icon(item.icon, size: 18, color: item.color),
      ),
      title: Text(item.place,
          style: TextStyle(
              fontSize: 14, fontWeight: FontWeight.w700, color: scheme.onSurface)),
      subtitle: Text('${item.category} · ${item.date}',
          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500, color: scheme.outline)),
      trailing: Text(
        '${isIncome ? '+' : '-'}${comma(item.amount.abs())}원',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w800,
          color: isIncome ? const Color(0xFF2E9E5B) : scheme.error,
        ),
      ),
    );
  }
}
