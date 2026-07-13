import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'firebase_options.dart';
import 'services/user_service.dart';
import 'screens/onboarding/onboarding_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/signup_extra_screen.dart';
import 'screens/home/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const DdaengApp());
}

class DdaengApp extends StatelessWidget {
  const DdaengApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '땡그랑',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2F6BFF)),
        scaffoldBackgroundColor: Colors.white,
        useMaterial3: true,
      ),
      home: const AppGate(),
    );
  }
}

/// 앱 진입 분기
///  1. 로그인 O + users 문서 O  → 홈
///  2. 로그인 O + users 문서 X  → 회원가입 추가정보 (온보딩 데이터 없이)
///  3. 로그인 X + 온보딩 안 봄  → 온보딩
///  4. 로그인 X + 온보딩 봄     → 로그인
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
          return FutureBuilder<bool>(
            future: _seenOnboarding(),
            builder: (context, snap) {
              if (!snap.hasData) return const DdaengLoading();
              return snap.data! ? const LoginScreen() : const OnboardingScreen();
            },
          );
        }

        // ── 로그인 상태 ──
        return FutureBuilder<bool>(
          future: UserService().isNewUser(user.uid),
          builder: (context, snap) {
            if (snap.hasError) {
              return _ErrorView(message: '${snap.error}');
            }
            if (!snap.hasData) return const DdaengLoading();

            return snap.data!
                ? SignupExtraScreen(uid: user.uid, email: user.email ?? '')
                : const HomeScreen();
          },
        );
      },
    );
  }

  Future<bool> _seenOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('seenOnboarding') ?? false;
  }
}

/// 공용 로딩 화면
class DdaengLoading extends StatelessWidget {
  const DdaengLoading({super.key});

  @override
  Widget build(BuildContext context) => const Scaffold(
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
              style: const TextStyle(
                  fontSize: 13, color: Color(0xFF98A2B3)),
            ),
          ],
        ),
      ),
    ),
  );
}