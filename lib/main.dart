import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models/user_model.dart';
import 'firebase_options.dart';
import 'services/user_service.dart';
import 'screens/onboarding/onboarding_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/signup_extra_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/auth/splash_screen.dart'; // 방금 만든 스플래시 파일 import

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
      ),
      // 스플래시 상태에 따라 분기
      home: _showSplash
          ? SplashScreen(onFinished: () => setState(() => _showSplash = false))
          : const AppGate(),
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
            return snap.data == null
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
              style: const TextStyle(fontSize: 13, color: Color(0xFF98A2B3)),
            ),
          ],
        ),
      ),
    ),
  );
}