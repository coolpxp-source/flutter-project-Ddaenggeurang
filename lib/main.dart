import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'firebase_options.dart';
import 'services/user_service.dart';

import 'screens/onboarding/onboarding_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/signup_extra_screen.dart';
import 'screens/budget/budget_setting_screen.dart';

Future<void> main() async {
  // Flutter 엔진 초기화
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase 초기화
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // 앱 실행
  runApp(const DdaengApp());
}

class DdaengApp extends StatelessWidget {
  const DdaengApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '땡그랑',

      // 앱 공통 테마
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2F6BFF),
        ),
        scaffoldBackgroundColor: Colors.white,
        useMaterial3: true,
      ),

      // 앱 시작 시 로그인 상태 등을 검사
      home: const AppGate(),
    );
  }
}

/// 앱 진입 화면을 결정하는 클래스
///
/// 1. 로그인 O + users 문서 O → 예산 설정 화면
/// 2. 로그인 O + users 문서 X → 회원가입 추가정보 화면
/// 3. 로그인 X + 온보딩 안 봄 → 온보딩 화면
/// 4. 로그인 X + 온보딩 봄 → 로그인 화면
class AppGate extends StatelessWidget {
  const AppGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      // Firebase 로그인 상태 실시간 감지
      stream: FirebaseAuth.instance.authStateChanges(),

      builder: (context, authSnap) {
        // 로그인 상태 확인 중
        if (authSnap.connectionState == ConnectionState.waiting) {
          return const DdaengLoading();
        }

        // Firebase Authentication 오류
        if (authSnap.hasError) {
          return _ErrorView(
            message: '${authSnap.error}',
          );
        }

        // 현재 로그인 사용자
        final User? user = authSnap.data;

        // ==========================================
        // 비로그인 상태
        // ==========================================
        if (user == null) {
          return FutureBuilder<bool>(
            // 온보딩을 이미 봤는지 확인
            future: _seenOnboarding(),

            builder: (context, snap) {
              // 온보딩 확인 중
              if (snap.connectionState == ConnectionState.waiting) {
                return const DdaengLoading();
              }

              // SharedPreferences 조회 오류
              if (snap.hasError) {
                return _ErrorView(
                  message: '${snap.error}',
                );
              }

              final bool hasSeenOnboarding = snap.data ?? false;

              // 온보딩을 이미 봤다면 로그인 화면
              if (hasSeenOnboarding) {
                return const LoginScreen();
              }

              // 온보딩을 안 봤다면 온보딩 화면
              return const OnboardingScreen();
            },
          );
        }

        // ==========================================
        // 로그인 상태
        // ==========================================
        return FutureBuilder<bool>(
          // Firestore의 users/{uid} 문서 존재 여부 확인
          future: UserService().isNewUser(user.uid),

          builder: (context, snap) {
            // 사용자 문서 확인 중
            if (snap.connectionState == ConnectionState.waiting) {
              return const DdaengLoading();
            }

            // Firestore 사용자 문서 확인 오류
            if (snap.hasError) {
              return _ErrorView(
                message: '${snap.error}',
              );
            }

            // true면 신규 사용자
            final bool isNewUser = snap.data ?? true;

            // 신규 사용자는 추가정보 입력 화면으로 이동
            if (isNewUser) {
              return SignupExtraScreen(
                uid: user.uid,
                email: user.email ?? '',
              );
            }

            // 기존 사용자는 예산 설정 화면으로 이동
            return BudgetSettingScreen(
              userId: user.uid,
            );
          },
        );
      },
    );
  }

  /// 온보딩을 이미 확인했는지 SharedPreferences에서 조회
  Future<bool> _seenOnboarding() async {
    final SharedPreferences prefs =
    await SharedPreferences.getInstance();

    return prefs.getBool('seenOnboarding') ?? false;
  }
}

/// 공용 로딩 화면
class DdaengLoading extends StatelessWidget {
  const DdaengLoading({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: SizedBox(
          width: 34,
          height: 34,
          child: CircularProgressIndicator(
            strokeWidth: 3,
            color: Color(0xFFFFC93C),
          ),
        ),
      ),
    );
  }
}

/// 공용 오류 화면
class _ErrorView extends StatelessWidget {
  // 표시할 오류 메시지
  final String message;

  const _ErrorView({
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '😿',
                style: TextStyle(
                  fontSize: 48,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                '문제가 생겼어요',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF98A2B3),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}