import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models/user_model.dart';
import 'firebase_options.dart';
import 'services/ai_service.dart';
import 'services/notification_service.dart';
import 'services/subscription_service.dart';
import 'services/user_service.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/signup_extra_screen.dart';
import 'screens/auth/email_verification_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/auth/splash_screen.dart'; // 방금 만든 스플래시 파일 import
import 'widgets/common/brand_loading_dots.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
            : const AppGate(key: ValueKey('gate')),
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
            unawaited(UserService().touchLoginStreak(user.uid, profile));
            unawaited(_maybeShowConsultReminder());
            unawaited(_maybeSyncSubscriptionReminders(user.uid, profile));
            return const HomeScreen();
          },
        );
      },
    );
  }
}

/// 하루 1번, 앱을 열었을 때 오늘 남은 AI상담 횟수를 로컬 알림으로 알려준다.
/// SharedPreferences에 오늘 날짜를 남겨서 같은 날 재실행/재빌드로 중복 발송되지 않게 한다.
Future<void> _maybeShowConsultReminder() async {
  final today = DateTime.now().toIso8601String().substring(0, 10);
  final prefs = await SharedPreferences.getInstance();
  if (prefs.getString('lastConsultReminderDate') == today) return;
  await prefs.setString('lastConsultReminderDate', today);
  await NotificationService.instance.showConsultReminder(AiService().consultRemaining);
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