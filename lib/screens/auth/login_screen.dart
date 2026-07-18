import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/auth_service.dart';
import '../../services/user_service.dart';
import '../../widgets/common/ddaeng_modal.dart';
import '../onboarding/onboarding_screen.dart'; // OnboardingData
import 'signup_extra_screen.dart';

class LoginScreen extends StatefulWidget {
  final OnboardingData? onboardingData;
  const LoginScreen({super.key, this.onboardingData});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _auth = AuthService();
  final _emailCtrl = TextEditingController();
  final _pwCtrl = TextEditingController();

  bool _loading = false;
  bool _showEmailForm = false;
  bool _obscurePw = true;

  // 마지막으로 성공했던 로그인 방법 — 매번 4개 버튼 중 뭘 눌러야 할지
  // 헷갈리지 않도록 "최근 로그인" 배지로 알려준다. 아직 실제로 붙어있는
  // google/email만 기록한다(카카오·네이버·애플은 준비 중이라 기록할 대상이 없음).
  String? _lastMethod;

  @override
  void initState() {
    super.initState();
    _loadLastMethod();
  }

  Future<void> _loadLastMethod() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() => _lastMethod = prefs.getString('lastLoginMethod'));
  }

  Future<void> _rememberMethod(String method) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('lastLoginMethod', method);
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _pwCtrl.dispose();
    super.dispose();
  }

  Future<void> _afterAuthSuccess(User? user) async {
    if (user == null) return;

    // 신규 사용자라면 닉네임 설정(SignupExtraScreen)으로 이동.
    // pushReplacement로 직접 열면 main.dart의 AppGate가 트리에서 떨어져
    // 나가서 이메일 인증 게이트를 못 거치므로, 루트까지 pop해서 AppGate가
    // authStateChanges를 보고 알아서 다음 화면으로 라우팅하게 한다.
    // (구글 신규 가입은 이미 emailVerified=true라 인증 화면은 건너뛴다)
    if (await UserService().isNewUser(user.uid)) {
      if (!mounted) return;
      PendingOnboarding.data = widget.onboardingData;
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
    // 기존 사용자는 앱 로직에 따라 홈으로 자동 이동
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _loading = true);
    try {
      final user = await _auth.signInWithGoogle();
      if (user != null) unawaited(_rememberMethod('google'));
      await _afterAuthSuccess(user);
    } catch (e) {
      if (!mounted) return;
      await DdaengModal.alert(context,
          title: '로그인에 실패했어요',
          message: '잠시 후 다시 시도해주세요',
          type: ModalType.danger);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _signInWithEmail() async {
    final email = _emailCtrl.text.trim();
    final pw = _pwCtrl.text;
    if (email.isEmpty || pw.isEmpty) {
      await DdaengModal.alert(context,
          title: '입력값을 확인해주세요',
          message: '이메일과 비밀번호를 모두 입력해주세요',
          type: ModalType.warning);
      return;
    }

    setState(() => _loading = true);
    try {
      final user = await _auth.signInWithEmail(email, pw);
      if (user != null) unawaited(_rememberMethod('email'));
      await _afterAuthSuccess(user);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      await DdaengModal.alert(context,
          title: '로그인에 실패했어요',
          message: _auth.getErrorMessage(e),
          type: ModalType.danger);
    } catch (e) {
      if (!mounted) return;
      await DdaengModal.alert(context,
          title: '문제가 생겼어요',
          message: '잠시 후 다시 시도해주세요',
          type: ModalType.danger);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _forgotPassword() async {
    final emailCtrl = TextEditingController(text: _emailCtrl.text.trim());
    final formKey = GlobalKey<FormState>();

    final email = await DdaengModal.custom<String>(
      context,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('비밀번호를 잊으셨나요?',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              const Text('가입한 이메일로 재설정 링크를 보내드릴게요',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Color(0xFF667085))),
              const SizedBox(height: 20),
              TextFormField(
                controller: emailCtrl,
                keyboardType: TextInputType.emailAddress,
                autofocus: true,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return '이메일을 입력해주세요';
                  if (!v.contains('@')) return '이메일 형식이 올바르지 않아요';
                  return null;
                },
                decoration: InputDecoration(
                  hintText: 'example@ddaeng.com',
                  filled: true,
                  fillColor: const Color(0xFFF7F8FA),
                  contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        foregroundColor: const Color(0xFF667085),
                        side: const BorderSide(color: Color(0xFFE8ECF3)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('취소'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        if (formKey.currentState!.validate()) {
                          Navigator.pop(context, emailCtrl.text.trim());
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: const Color(0xFF1D4ED8),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('메일 보내기'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (email == null || !mounted) return;
    try {
      await _auth.sendPasswordResetEmail(email);
      if (!mounted) return;
      await DdaengModal.alert(
        context,
        title: '메일을 보냈어요',
        message: '$email 로 재설정 링크를 보냈어요.\n메일함(스팸함도 확인!)을 확인해주세요',
        type: ModalType.success,
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      await DdaengModal.alert(context,
          title: '전송에 실패했어요', message: _auth.getErrorMessage(e), type: ModalType.danger);
    } catch (_) {
      if (!mounted) return;
      await DdaengModal.alert(context,
          title: '문제가 생겼어요', message: '잠시 후 다시 시도해주세요', type: ModalType.danger);
    }
  }

  void _goToSignUp() {
    // 가입하기를 누르면 온보딩 화면으로 이동 (아직 가입 전이므로 데이터는 null)
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const OnboardingScreen()),
    );
  }

  void _comingSoon() {
    DdaengModal.alert(context,
        title: '준비 중이에요',
        message: '지금은 Google 또는 이메일로 이용해주세요',
        type: ModalType.coin,
        emoji: '🐶');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF9F0),
      body: Stack(
        children: [
          // ─── 은은하게 떠다니는 배경 블롭 ───
          const Positioned(top: 60, left: -30, child: _LoginBlob(color: Color(0xFFFFE3EC), size: 150)),
          const Positioned(top: 140, right: -40, child: _LoginBlob(color: Color(0xFFECE6FF), size: 130)),
          const Positioned(bottom: 40, left: -20, child: _LoginBlob(color: Color(0xFFFFF0C2), size: 120)),

          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(28, 0, 28, 24),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: MediaQuery.of(context).size.height -
                      MediaQuery.of(context).padding.top -
                      MediaQuery.of(context).padding.bottom -
                      24,
                ),
                // 🔥 Spacer 사용을 위해 IntrinsicHeight로 감싸주었습니다!
                child: IntrinsicHeight(
                  child: Column(
                    children: [
                      const Spacer(flex: 3),

                      // ─── 로고 ───
                      Image.asset(
                        'assets/images/ddaeng_logo_transparent_trimmed.png',
                        width: 236,
                        fit: BoxFit.contain,
                      ),

                      const Spacer(flex: 2),

                      // ─── 이메일 로그인 (토글) ───
                      AnimatedSize(
                        duration: const Duration(milliseconds: 240),
                        curve: Curves.easeOutCubic,
                        child: _showEmailForm
                            ? Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _EmailField(
                                controller: _emailCtrl,
                                hint: '이메일',
                                icon: Icons.mail_outline_rounded,
                              ),
                              const SizedBox(height: 10),
                              _EmailField(
                                controller: _pwCtrl,
                                hint: '비밀번호',
                                icon: Icons.lock_outline_rounded,
                                obscure: _obscurePw,
                                onToggleObscure: () =>
                                    setState(() => _obscurePw = !_obscurePw),
                              ),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: _loading ? null : _forgotPassword,
                                  style: TextButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    minimumSize: Size.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: const Text('비밀번호를 잊으셨나요?',
                                      style: TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF667085))),
                                ),
                              ),
                              const SizedBox(height: 4),
                              _LastUsedBadge(
                                show: _lastMethod == 'email',
                                child: _SocialButton(
                                  label: '이메일로 로그인',
                                  bg: const Color(0xFF1D4ED8),
                                  fg: Colors.white,
                                  onTap: _loading ? null : _signInWithEmail,
                                ),
                              ),
                              const SizedBox(height: 14),
                              const _Divider(),
                              const SizedBox(height: 14),
                            ],
                          ),
                        )
                            : const SizedBox.shrink(),
                      ),

                      // ─── 소셜 로그인 ───
                      _SocialButton(
                        label: '카카오로 계속하기',
                        bg: const Color(0xFFFEE500),
                        fg: const Color(0xFF191919),
                        icon: Image.asset('assets/images/카카오.png', width: 26, height: 26),
                        onTap: _loading ? null : _comingSoon,
                      ),
                      const SizedBox(height: 10),
                      _SocialButton(
                        label: '네이버로 계속하기',
                        bg: const Color(0xFF03C75A),
                        fg: Colors.white,
                        icon: const _SocialBadge(
                          bg: Colors.white,
                          child: Text('N',
                              style: TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w900, color: Color(0xFF03C75A))),
                        ),
                        onTap: _loading ? null : _comingSoon,
                      ),
                      const SizedBox(height: 10),
                      _LastUsedBadge(
                        show: _lastMethod == 'google',
                        child: _SocialButton(
                          label: 'Google로 계속하기',
                          bg: Colors.white,
                          fg: const Color(0xFF1F2937),
                          border: const Color(0xFFE8ECF3),
                          icon: Image.asset('assets/images/구글.png', width: 22, height: 22),
                          onTap: _loading ? null : _signInWithGoogle,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _SocialButton(
                        label: 'Apple로 계속하기',
                        bg: const Color(0xFF1A1F2E),
                        fg: Colors.white,
                        icon: const Icon(Icons.apple_rounded, size: 22, color: Colors.white),
                        onTap: _loading ? null : _comingSoon,
                      ),

                      const SizedBox(height: 18),
                      const _Divider(),
                      const SizedBox(height: 18),

                      // ─── 이메일로 계속하기 (아웃라인 CTA) ───
                      // 폼을 펼쳐야만 보이는 안쪽 버튼 말고, 접힌 초기 화면에서부터
                      // "최근 로그인" 배지가 바로 보여야 의미가 있어서 여기도 감싼다.
                      _LastUsedBadge(
                        show: _lastMethod == 'email' && !_showEmailForm,
                        child: SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: OutlinedButton(
                            onPressed: _loading
                                ? null
                                : () => setState(() => _showEmailForm = !_showEmailForm),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFFB8860B),
                              side: const BorderSide(color: Color(0xFFFFC93C), width: 1.6),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(27)),
                            ),
                            child: Text(
                              _showEmailForm ? '이메일 로그인 닫기' : '이메일로 계속하기',
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                            ),
                          ),
                        ),
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
                                strokeWidth: 2.4, color: Color(0xFFFFC93C)),
                          ),
                        )
                            : null,
                      ),

                      const Spacer(flex: 2),

                      // ─── 회원가입 안내 ───
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            '아직 통장이 없으신가요?',
                            style: TextStyle(
                                fontSize: 13, color: Color(0xFF98A2B3)),
                          ),
                          TextButton(
                            onPressed: _goToSignUp,
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 6),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text(
                              '통장 만들기',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF2F6BFF),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        '땡그랑',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF667085),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 지난번 로그인에 썼던 방법 위에 "최근 로그인" 배지를 얹어준다.
class _LastUsedBadge extends StatelessWidget {
  final bool show;
  final Widget child;
  const _LastUsedBadge({required this.show, required this.child});

  @override
  Widget build(BuildContext context) {
    if (!show) return child;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        Positioned(
          top: -8,
          right: 12,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFF2F6BFF),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 6,
                    offset: const Offset(0, 2)),
              ],
            ),
            child: const Text('최근 로그인',
                style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: Colors.white)),
          ),
        ),
      ],
    );
  }
}

class _LoginBlob extends StatelessWidget {
  final Color color;
  final double size;
  const _LoginBlob({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color, color.withValues(alpha: 0.0)],
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider(color: Color(0xFFEEEEF3), height: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text('또는',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade400)),
        ),
        const Expanded(child: Divider(color: Color(0xFFEEEEF3), height: 1)),
      ],
    );
  }
}

// ══════════ 이메일 입력 필드 ══════════

class _EmailField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final bool obscure;
  final VoidCallback? onToggleObscure;

  const _EmailField({
    required this.controller,
    required this.hint,
    required this.icon,
    this.obscure = false,
    this.onToggleObscure,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      style: const TextStyle(
          fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF191F28)),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(
            fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFFB0B8C1)),
        prefixIcon: Icon(icon, size: 19, color: const Color(0xFF98A2B3)),
        suffixIcon: onToggleObscure != null
            ? IconButton(
          icon: Icon(
              obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded,
              size: 19,
              color: const Color(0xFF98A2B3)),
          onPressed: onToggleObscure,
        )
            : null,
        filled: true,
        fillColor: const Color(0xFFF7F8FA),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF2F6BFF), width: 1.6),
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
  final Widget? icon;
  final VoidCallback? onTap;

  const _SocialButton({
    required this.label,
    required this.bg,
    required this.fg,
    this.border,
    this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: fg,
          disabledBackgroundColor: bg.withValues(alpha: 0.6),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
            side: border != null
                ? BorderSide(color: border!, width: 1.2)
                : BorderSide.none,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[icon!, const SizedBox(width: 10)],
            Text(
              label,
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: fg),
            ),
          ],
        ),
      ),
    );
  }
}

/// 소셜 로그인 버튼용 원형 아이콘 배지 (전용 로고 이미지가 없는 서비스는
/// 컬러/이니셜만으로 구분한다).
class _SocialBadge extends StatelessWidget {
  final Widget child;
  final Color bg;
  const _SocialBadge({required this.child, required this.bg});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: child,
    );
  }
}
