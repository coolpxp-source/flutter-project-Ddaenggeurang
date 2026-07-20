import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models/emotion_summary_model.dart';
import 'models/user_model.dart';
import 'firebase_options.dart';
import 'services/activity_calendar_service.dart';
import 'services/ai_service.dart';
import 'services/app_badge_service.dart';
import 'services/budget_service.dart';
import 'services/category_summary_service.dart';
import 'services/emotion_summary_service.dart';
import 'services/notification_history_service.dart';
import 'services/notification_service.dart';
import 'services/recurring_payment_service.dart';
import 'services/subscription_service.dart';
import 'services/user_service.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/signup_extra_screen.dart';
import 'screens/auth/email_verification_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/auth/splash_screen.dart'; // 방금 만든 스플래시 파일 import
import 'widgets/common/app_lock_gate.dart';
import 'widgets/common/brand_loading_dots.dart';
import 'package:intl/date_symbol_data_local.dart'; // TableCalendar 한글번역팩
import 'package:flutter_dotenv/flutter_dotenv.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await initializeDateFormatting('ko_KR', null); // TableCalendar 한글번역팩
  await dotenv.load(fileName: ".env");

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const DdaengApp());
}

class DdaengApp extends StatefulWidget {
  const DdaengApp({super.key});

  @override
  State<DdaengApp> createState() => _DdaengAppState();
}

class _DdaengAppState extends State<DdaengApp> {
  bool _showSplash = true;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '땡그랑',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2F6BFF)),
        scaffoldBackgroundColor: Colors.white,
        useMaterial3: true,
        // 앱 전체 기본 폰트를 Gothic A1(구글 폰트, 한글 지원)로 통일.
        // 기존 화면들의 TextStyle(fontWeight/fontSize/color)은 fontFamily를
        // 지정 안 했으므로 이 테마의 폰트를 그대로 물려받는다 — 다른 파트
        // 화면도 별도 수정 없이 자동으로 폰트만 좋아짐.
        textTheme: GoogleFonts.gothicA1TextTheme(),
      ),
      // 스플래시 상태에 따라 분기 (전환 시 부드럽게 크로스페이드)
      home: AnimatedSwitcher(
        duration: const Duration(milliseconds: 450),
        switchInCurve: Curves.easeOut,
        child: _showSplash
            ? SplashScreen(
                key: const ValueKey('splash'),
                onFinished: () => setState(() => _showSplash = false),
              )
            : const AppLockGate(key: ValueKey('gate'), child: AppGate()),
      ),
    );
  }
}

/// 앱 진입 분기 (AppGate)
class AppGate extends StatelessWidget {
  const AppGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnap) {
        if (authSnap.connectionState == ConnectionState.waiting) {
          return const DdaengLoading();
        }

        final user = authSnap.data;

        // ── 비로그인 ──
        if (user == null) {
          _cancelAppBadgeSync();
          // 이제 온보딩 여부를 확인하지 않고 항상 로그인 화면으로 보냅니다.
          return const LoginScreen();
        }

        // ── 이메일 미인증 ──
        // 구글 로그인 계정은 Firebase가 emailVerified를 자동으로 true로
        // 채워주므로 이 단계를 그냥 통과한다. 이메일/비밀번호 가입 계정만
        // 인증 전이면 여기서 막힌다.
        if (!user.emailVerified) {
          return const EmailVerificationScreen();
        }

        // ── 로그인 상태 ──
        return StreamBuilder<UserModel?>(
          stream: UserService().watchUser(user.uid),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const DdaengLoading();
            }
            if (snap.hasError) {
              return _ErrorView(message: '${snap.error}');
            }
            final profile = snap.data;
            if (profile == null) {
              return SignupExtraScreen(
                  uid: user.uid,
                  email: user.email ?? '',
                  onboardingData: PendingOnboarding.data);
            }
            unawaited(_maybeCelebrateStreakMilestone(user.uid, profile));
            unawaited(_maybeBackfillActivityCalendar(user.uid, profile));
            unawaited(_maybeShowConsultReminder(user.uid, profile));
            unawaited(_maybeSyncSubscriptionReminders(user.uid, profile));
            unawaited(_maybeSyncFixedExpenseReminders(user.uid, profile));
            unawaited(_maybeShowDailyNagging(user.uid, profile));
            unawaited(_maybeShowDailyResolution(user.uid));
            unawaited(_maybeCelebrateLevelUp(user.uid, profile));
            unawaited(_maybeWarnBudgetOverage(user.uid, profile));
            _syncAppBadgeForUser(user.uid);
            return const HomeScreen();
          },
        );
      },
    );
  }
}

// 로그인 세션 동안 딱 한 번만 구독을 걸어두기 위한 전역 상태.
// AppGate.build()는 프로필 스트림이 갱신될 때마다 다시 호출되므로, uid가
// 그대로면 재구독하지 않고 넘어간다.
StreamSubscription<int>? _badgeSub;
String? _badgeSubUid;

/// 앱 아이콘 배지(안 읽은 알림 개수)를 로그인 세션 내내 실시간으로 동기화한다.
void _syncAppBadgeForUser(String uid) {
  if (_badgeSubUid == uid) return;
  _badgeSub?.cancel();
  _badgeSubUid = uid;
  _badgeSub = NotificationHistoryService()
      .watchUnreadCount(uid)
      .listen((count) => AppBadgeService.instance.setCount(count));
}

void _cancelAppBadgeSync() {
  _badgeSub?.cancel();
  _badgeSub = null;
  _badgeSubUid = null;
  unawaited(AppBadgeService.instance.clear());
}

/// 로그인 스트릭(users.loginStreak)을 갱신하고, 7/30/100일 마일스톤을
/// 처음 달성한 순간에만 축하 알림을 띄운다. 이미 축하한 마일스톤은
/// SharedPreferences에 남겨서 같은 스트릭 값으로는 다시 뜨지 않게 한다.
Future<void> _maybeCelebrateStreakMilestone(String uid, UserModel profile) async {
  final today = DateTime.now().toIso8601String().substring(0, 10);
  if (profile.lastLoginDate != today) {
    unawaited(ActivityCalendarService().markActive(uid, today));
  }

  final newStreak = await UserService().touchLoginStreak(uid, profile);

  const milestones = {7, 30, 100};
  if (!milestones.contains(newStreak)) return;

  final prefs = await SharedPreferences.getInstance();
  final key = 'celebratedStreak_$newStreak';
  if (prefs.getBool(key) == true) return;
  await prefs.setBool(key, true);

  final title = '연속 접속 $newStreak일 달성! 🔥';
  final body = '$newStreak일 동안 매일 와줬어요. 정말 대단해요!';
  await NotificationService.instance.showStreakMilestone(title: title, body: body);
  await NotificationHistoryService()
      .record(uid: uid, title: title, body: body, type: 'streak');
}

/// 접속 캘린더(activityDays)는 이 기능을 배포한 날부터만 기록되기 시작해서,
/// 그전부터 쌓여 있던 users.loginStreak과 화면에 보이는 숫자가 서로 안 맞는
/// 문제가 있었다. 기기당 한 번만 loginStreak 기준으로 과거 날짜를 역산해서
/// activityDays를 채워 넣어 두 값을 맞춘다.
Future<void> _maybeBackfillActivityCalendar(String uid, UserModel profile) async {
  final prefs = await SharedPreferences.getInstance();
  final key = 'activityBackfillDone_$uid';
  if (prefs.getBool(key) == true) return;
  await prefs.setBool(key, true);

  final lastLoginDate = profile.lastLoginDate;
  if (lastLoginDate == null) return;
  await ActivityCalendarService().backfillFromStreak(
    uid,
    lastLoginDate: lastLoginDate,
    loginStreak: profile.loginStreak,
  );
}

/// 포인트가 쌓여 레벨이 오른 순간을 감지해서 축하 알림을 띄운다. 미션 보상
/// 등 포인트가 어디서 지급되든(addPoints 호출부는 다른 파트 소관) users 문서의
/// level 필드 변화만 지켜보면 되므로, 마지막으로 확인한 레벨을 SharedPreferences에
/// uid별로 남겨서 그보다 올랐을 때만 반응한다. 처음 관찰하는 기기(첫 로그인 등)는
/// 기준값만 저장하고 축하하지 않는다 — 안 그러면 가입 직후 Lv.1도 "레벨업"으로 오인한다.
Future<void> _maybeCelebrateLevelUp(String uid, UserModel profile) async {
  final prefs = await SharedPreferences.getInstance();
  final key = 'lastKnownLevel_$uid';
  final lastKnown = prefs.getInt(key);
  if (lastKnown == null) {
    await prefs.setInt(key, profile.level);
    return;
  }
  if (profile.level <= lastKnown) return;
  await prefs.setInt(key, profile.level);

  final title = '레벨 업! Lv.${profile.level} 달성 🎉';
  final body = '포인트를 모아서 레벨이 올랐어요. 계속 이 기세로!';
  await NotificationService.instance.showLevelUp(title: title, body: body);
  await NotificationHistoryService()
      .record(uid: uid, title: title, body: body, type: 'levelup');
}

/// 이번 달 예산 사용률이 80%/100%에 도달하면 각각 한 번씩만 경고 알림을 띄운다.
/// budgets(성기필)/expenses(임예림) 컬렉션은 공개 서비스 메서드로만 읽는다.
Future<void> _maybeWarnBudgetOverage(String uid, UserModel profile) async {
  final now = DateTime.now();
  final monthStr = '${now.year}-${now.month.toString().padLeft(2, '0')}';

  final budget = await BudgetService().getBudget(userId: uid, month: monthStr);
  if (budget == null || budget.availableBudget <= 0) return;

  final summaries =
      await CategorySummaryService().getCategorySummary(userId: uid, year: now.year, month: now.month);
  final spent = summaries.fold<int>(0, (sum, s) => sum + s.totalAmount);
  final usedPercent = (spent / budget.availableBudget * 100).round();

  final prefs = await SharedPreferences.getInstance();

  Future<void> warnOnce(int threshold, String title, String body) async {
    final key = 'budgetWarned${threshold}_${uid}_$monthStr';
    if (prefs.getBool(key) == true) return;
    await prefs.setBool(key, true);
    await NotificationService.instance.showBudgetWarning(title: title, body: body);
    await NotificationHistoryService()
        .record(uid: uid, title: title, body: body, type: 'budget_warning');
  }

  if (usedPercent >= 100) {
    await warnOnce(100, '이번 달 예산을 다 썼어요 😮',
        '이번 달 지출이 예산 $usedPercent%에 도달했어요. 남은 기간 지출을 조절해보세요.');
  } else if (usedPercent >= 80) {
    await warnOnce(80, '이번 달 예산의 80%를 썼어요',
        '지출이 예산의 $usedPercent%에 도달했어요. 조금만 더 신경 써볼까요?');
  }
}

/// 하루 1번, 앱을 열었을 때 오늘 남은 AI상담 횟수를 로컬 알림으로 알려준다.
/// SharedPreferences에 오늘 날짜를 남겨서 같은 날 재실행/재빌드로 중복 발송되지 않게 한다.
Future<void> _maybeShowConsultReminder(String uid, UserModel profile) async {
  final today = DateTime.now().toIso8601String().substring(0, 10);
  final prefs = await SharedPreferences.getInstance();
  if (prefs.getString('lastConsultReminderDate') == today) return;
  await prefs.setString('lastConsultReminderDate', today);

  final shown = await NotificationService.instance.showConsultReminder(
    AiService().consultRemaining,
    coachEmoji: profile.coachTone.emoji,
    coachName: profile.coachDisplayName,
  );
  if (shown == null) return;
  await NotificationHistoryService()
      .record(uid: uid, title: shown.title, body: shown.body, type: 'consult');
}

/// 아침마다 하나씩 순서대로 보여줄 짧은 소비 습관 다짐 문구.
/// 잔소리(오늘의 잔소리)는 실제 지출 집계를 분석한 결과라 데이터가 있어야
/// 의미가 있지만, 이건 데이터 없이도 매일 가볍게 띄울 수 있는 고정 문구다.
const _dailyResolutions = <String>[
  '오늘은 커피 대신 물 한 잔 어때요?',
  '지출하기 전에 3초만 생각해봐요',
  '오늘 하루, 무지출 챌린지 어때요?',
  '갖고 싶은 게 있으면 장바구니에 담아두고 하루 지나서 다시 생각해봐요',
  '오늘 번 돈, 얼마나 저축할지 미리 정해볼까요?',
  '택시 대신 대중교통은 어때요?',
  '이번 주 예산, 한 번 확인해볼까요?',
  '작은 습관이 큰 저축을 만들어요',
  '오늘 지출은 미리 계획해두면 더 스마트해요',
  '필요한 것과 원하는 것을 구분해봐요',
  '오늘 하루도 현명한 소비 응원할게요!',
  '커피 한 잔 아끼면 한 달에 얼마일지 계산해볼까요?',
];

/// 하루 1번, 앱을 열었을 때 "오늘의 다짐" 문구를 로컬 알림으로 보여준다.
/// 날짜(연중 일수) 기준으로 목록을 순환시켜서 매일 다른 문구가 뜨게 한다.
Future<void> _maybeShowDailyResolution(String uid) async {
  final today = DateTime.now().toIso8601String().substring(0, 10);
  final prefs = await SharedPreferences.getInstance();
  if (prefs.getString('lastResolutionDate') == today) return;
  await prefs.setString('lastResolutionDate', today);

  final now = DateTime.now();
  final dayOfYear =
      DateTime(now.year, now.month, now.day).difference(DateTime(now.year, 1, 1)).inDays;
  final message = _dailyResolutions[dayOfYear % _dailyResolutions.length];

  await NotificationService.instance.showDailyResolution(message);
  await NotificationHistoryService()
      .record(uid: uid, title: '오늘의 다짐 ☀️', body: message, type: 'resolution');
}

/// 하루 1번, 활성 구독 목록 기준으로 결제일 알림을 다시 걸어준다(설정 꺼져 있으면 취소).
/// 구독을 새로 추가/해지해도 다음 앱 실행 시 자동으로 반영된다.
Future<void> _maybeSyncSubscriptionReminders(String uid, UserModel profile) async {
  final today = DateTime.now().toIso8601String().substring(0, 10);
  final prefs = await SharedPreferences.getInstance();
  if (prefs.getString('lastSubscriptionSyncDate') == today) return;
  await prefs.setString('lastSubscriptionSyncDate', today);

  final subs = await SubscriptionService().getSubscriptions(uid).first;
  await NotificationService.instance.syncSubscriptionReminders(
    enabled: profile.notificationSettings.subscriptionAlert,
    activeSubscriptions: subs.where((s) => s.isActive).toList(),
  );
}

/// 하루 1번, 활성 고정비(월세·공과금 등) 목록 기준으로 결제일 알림을 다시 걸어준다
/// (설정 꺼져 있으면 취소). _maybeSyncSubscriptionReminders와 동일한 패턴.
Future<void> _maybeSyncFixedExpenseReminders(String uid, UserModel profile) async {
  final today = DateTime.now().toIso8601String().substring(0, 10);
  final prefs = await SharedPreferences.getInstance();
  if (prefs.getString('lastFixedExpenseSyncDate') == today) return;
  await prefs.setString('lastFixedExpenseSyncDate', today);

  try {
    final payments = await RecurringPaymentService().getRecurringPayments(uid).first;
    await NotificationService.instance.syncFixedExpenseReminders(
      enabled: profile.notificationSettings.fixedExpenseAlert,
      activePayments: payments,
    );
  } catch (_) {
    // 고정비 목록 조회 실패(권한/네트워크 등) — 알림 없이 조용히 넘어간다.
  }
}

/// 하루 1번, 이번 달 최다 지출 카테고리를 계산해서(코드로) 코치 톤으로 문장을
/// 만든 뒤(AI) 로컬 알림으로 보여준다 — 홈 화면 코치 말풍선과 같은 데이터/캐시를
/// 재사용한다. AI 서버(은동 PC)가 꺼져 있으면 오늘 날짜를 저장하지 않고 조용히
/// 스킵해서 다음 실행 때 다시 시도한다.
Future<void> _maybeShowDailyNagging(String uid, UserModel profile) async {
  final today = DateTime.now().toIso8601String().substring(0, 10);
  final prefs = await SharedPreferences.getInstance();
  if (prefs.getString('lastNaggingDate') == today) return;

  final now = DateTime.now();
  final summaries = await CategorySummaryService()
      .getCategorySummary(userId: uid, year: now.year, month: now.month);
  if (summaries.isEmpty) return;

  final top = summaries.first;

  // 홈 화면 코치 말풍선(_CoachBubble)과 같은 기준(스트레스 30% 이상일 때만)으로
  // 감정 태그 정보를 덧붙인다.
  String emotionNote = '';
  try {
    final emotions = await EmotionSummaryService()
        .getEmotionSummary(userId: uid, year: now.year, month: now.month);
    EmotionSummaryModel? stress;
    for (final e in emotions) {
      if (e.emotionKey == 'stress') {
        stress = e;
        break;
      }
    }
    if (stress != null && stress.percentage >= 30) {
      emotionNote = ' 그리고 이번 달 지출의 ${stress.percentage.round()}%는 스트레스로 인한 소비였어요.';
    }
  } catch (_) {
    // 감정 태그 집계 실패 — 카테고리 정보만으로 잔소리를 만든다.
  }

  final dataSummary = '이번 달 최다 지출 카테고리: ${top.categoryName} ${_won(top.totalAmount)} '
      '(전체 지출의 ${top.percentage.round()}%).$emotionNote';

  try {
    final text = await AiService().generateNagging(profile.coachTone, dataSummary);
    final title = '${profile.coachTone.emoji} ${profile.coachDisplayName}가 한마디';
    await prefs.setString('lastNaggingDate', today);
    await NotificationService.instance.showDailyNagging(text, title: title);
    await NotificationHistoryService()
        .record(uid: uid, title: title, body: text, type: 'nagging');
  } catch (_) {
    // AI 서버 연결 실패 — 알림 없이 조용히 넘어간다.
  }
}

String _won(int n) {
  final s = n.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},');
  return '$s원';
}

/// 공용 로딩 화면 — 스플래시와 같은 톤(민트 그라데이션 + 브랜드 로고 + 점 3개)으로
/// 인증 상태/유저 데이터를 기다리는 짧은 순간에도 톤이 끊기지 않도록 한다.
class DdaengLoading extends StatelessWidget {
  const DdaengLoading({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.white, Color(0xFFD9F2EC), Colors.white],
                stops: [0.0, 0.55, 1.0],
              ),
            ),
          ),
          Positioned(
            top: -40,
            left: -50,
            child: _LoadingBlob(color: const Color(0xFFFFC93C).withValues(alpha: 0.3), size: 180)
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .moveY(begin: 0, end: 20, duration: 3400.ms, curve: Curves.easeInOut),
          ),
          Positioned(
            bottom: -60,
            right: -50,
            child: _LoadingBlob(color: const Color(0xFF63C5B5).withValues(alpha: 0.32), size: 200)
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .moveY(begin: 0, end: -18, duration: 3800.ms, curve: Curves.easeInOut),
          ),
          Positioned(
            bottom: 120,
            left: -30,
            child: _LoadingBlob(color: const Color(0xFFFF9EB5).withValues(alpha: 0.24), size: 120)
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .moveY(begin: 0, end: 14, duration: 3000.ms, curve: Curves.easeInOut),
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 210,
                      height: 210,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            const Color(0xFF63C5B5).withValues(alpha: 0.22),
                            const Color(0xFF63C5B5).withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                    )
                        .animate(onPlay: (c) => c.repeat(reverse: true))
                        .scaleXY(begin: 0.9, end: 1.08, duration: 1600.ms, curve: Curves.easeInOut),
                    Image.asset(
                      'assets/images/ddaeng_logo_transparent_trimmed.png',
                      width: 168,
                    )
                        .animate(onPlay: (c) => c.repeat(reverse: true))
                        .scaleXY(
                            begin: 0.95, end: 1.05, duration: 1100.ms, curve: Curves.easeInOut),
                  ],
                ),
                const SizedBox(height: 28),
                const BrandLoadingDots(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 로딩 화면 배경에 은은하게 떠다니는 장식 블롭.
class _LoadingBlob extends StatelessWidget {
  final Color color;
  final double size;
  const _LoadingBlob({required this.color, required this.size});

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

class _ErrorView extends StatelessWidget {
  final String message;
  const _ErrorView({required this.message});

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('😿', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 16),
            const Text(
              '문제가 생겼어요',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: Color(0xFF98A2B3)),
            ),
          ],
        ),
      ),
    ),
  );
}