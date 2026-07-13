import 'package:flutter/material.dart';
import '../auth/signup_extra_screen.dart';
import '../../services/auth_service.dart';
import '../onboarding/onboarding_screen.dart'; // OnboardingData
import '../../widgets/common/ddaeng_modal.dart';
import '../../services/user_service.dart';


// 만약 UserService가 다른 파일에 있다면 import 문을 추가해야 합니다.
// import '../../services/user_service.dart';

class LoginScreen extends StatefulWidget {
  final OnboardingData? onboardingData;

  const LoginScreen({super.key, this.onboardingData});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _auth = AuthService();
  bool _loading = false;

  Future<void> _signInWithGoogle() async {
    setState(() => _loading = true);
    try {
      final user = await _auth.signInWithGoogle();
      if (user == null) return; // 사용자가 취소

      // 신규 사용자면 온보딩 데이터와 함께 회원가입 화면으로
      if (await UserService().isNewUser(user.uid)) {
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => SignupExtraScreen(
              uid: user.uid,
              email: user.email ?? '',
              onboardingData: widget.onboardingData,
            ),
          ),
        );
      }
      // 기존 사용자는 AppGate가 자동으로 홈으로 보냄
    } catch (e) {
      if (!mounted) return;
      await DdaengModal.alert(
        context,
        title: '로그인에 실패했어요',
        message: '잠시 후 다시 시도해주세요',
        type: ModalType.danger,
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // 1개만 남기고 중복 제거 완료!
  void _comingSoon() {
    DdaengModal.alert(
      context,
      title: '준비 중이에요',
      message: '지금은 Google 로그인을 이용해주세요',
      type: ModalType.coin,
      emoji: '🐶',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            children: [
              const Spacer(flex: 3),

              // ─── 로고 ───
              Image.asset(
                'assets/images/logo.png',
                width: 220,
                fit: BoxFit.contain,
              ),

              const Spacer(flex: 2),

              // ─── 소셜 로그인 ───
              _SocialButton(
                label: 'Kakao',
                bg: const Color(0xFFFEE500),
                fg: const Color(0xFF191919),
                onTap: _loading ? null : _comingSoon,
              ),
              const SizedBox(height: 10),
              _SocialButton(
                label: 'Naver',
                bg: const Color(0xFF03C75A),
                fg: Colors.white,
                onTap: _loading ? null : _comingSoon,
              ),
              const SizedBox(height: 10),
              _SocialButton(
                label: 'Google',
                bg: Colors.white,
                fg: const Color(0xFF1F2937),
                border: const Color(0xFFE8ECF3),
                onTap: _loading ? null : _signInWithGoogle,
              ),
              const SizedBox(height: 10),
              _SocialButton(
                label: 'Apple',
                bg: const Color(0xFF1A1F2E),
                fg: Colors.white,
                onTap: _loading ? null : _comingSoon,
              ),

              const SizedBox(height: 20),
              SizedBox(
                height: 24,
                child: _loading
                    ? const Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: Color(0xFFFFC93C),
                    ),
                  ),
                )
                    : null,
              ),

              const Spacer(flex: 2),

              const Text(
                '땡그랑',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF667085),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════ 소셜 버튼 ══════════

class _SocialButton extends StatelessWidget {
  final String label;
  final Color bg;
  final Color fg;
  final Color? border;
  final VoidCallback? onTap;

  const _SocialButton({
    required this.label,
    required this.bg,
    required this.fg,
    this.border,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: fg,
          disabledBackgroundColor: bg.withOpacity(0.6),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: border != null
                ? BorderSide(color: border!, width: 1.2)
                : BorderSide.none,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: fg,
          ),
        ),
      ),
    );
  }
}