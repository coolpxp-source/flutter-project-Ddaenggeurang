import 'dart:async';
import 'package:flutter/material.dart';
import '../../main.dart'; // AppGate
import '../../services/auth_service.dart';
import '../../widgets/common/ddaeng_modal.dart';
import '../onboarding/onboarding_screen.dart'; // DdaengColors

/// 이메일/비밀번호로 가입한 계정이 emailVerified가 될 때까지 막아서는 화면.
/// 구글 로그인 계정은 Firebase가 자동으로 emailVerified=true를 주기 때문에
/// 이 화면을 거치지 않는다 (main.dart의 AppGate에서 분기).
class EmailVerificationScreen extends StatefulWidget {
  const EmailVerificationScreen({super.key});

  @override
  State<EmailVerificationScreen> createState() => _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  final _auth = AuthService();
  bool _checking = false;
  bool _resending = false;
  int _resendCooldown = 0;
  Timer? _cooldownTimer;

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkVerified() async {
    setState(() => _checking = true);
    final verified = await _auth.refreshEmailVerified();
    if (!mounted) return;
    setState(() => _checking = false);

    if (verified) {
      // AppGate를 새로 띄워서 (스트림이 이미 최신 emailVerified를 반영한
      // currentUser를 갖고 있으므로) 다음 단계로 자연스럽게 넘어가게 한다.
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AppGate()),
        (route) => false,
      );
    } else {
      await DdaengModal.alert(
        context,
        title: '아직 인증 전이에요',
        message: '메일함(스팸함도 확인!)에서 인증 링크를 눌러주세요',
        type: ModalType.warning,
      );
    }
  }

  Future<void> _resend() async {
    if (_resendCooldown > 0 || _resending) return;
    setState(() => _resending = true);
    try {
      await _auth.sendEmailVerification();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('인증 메일을 다시 보냈어요'),
          backgroundColor: DdaengColors.navy,
          behavior: SnackBarBehavior.floating,
        ),
      );
      _startCooldown();
    } catch (_) {
      if (!mounted) return;
      await DdaengModal.alert(
        context,
        title: '전송에 실패했어요',
        message: '잠시 후 다시 시도해주세요',
        type: ModalType.danger,
      );
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  void _startCooldown() {
    setState(() => _resendCooldown = 60);
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_resendCooldown <= 1) {
        t.cancel();
        setState(() => _resendCooldown = 0);
      } else {
        setState(() => _resendCooldown--);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final email = _auth.currentUser?.email ?? '';

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 0, 28, 24),
          child: Column(
            children: [
              const Spacer(flex: 3),
              Container(
                width: 84,
                height: 84,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    center: Alignment(-0.3, -0.4),
                    colors: [Color(0xFFFFE9A8), Color(0xFFFFC93C), Color(0xFFF5A623)],
                  ),
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.mark_email_unread_rounded,
                    size: 36, color: DdaengColors.navy),
              ),
              const SizedBox(height: 24),
              const Text(
                '이메일을 인증해주세요',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  color: DdaengColors.ink,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '$email 주소로 인증 메일을 보냈어요.\n메일함에서 링크를 눌러 인증을 완료해주세요.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13.5,
                  height: 1.6,
                  fontWeight: FontWeight.w500,
                  color: DdaengColors.inkSub,
                ),
              ),
              const SizedBox(height: 36),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _checking ? null : _checkVerified,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: DdaengColors.navy,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _checking
                      ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                      : const Text('인증 완료했어요',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(height: 6),
              TextButton(
                onPressed: (_resendCooldown > 0 || _resending) ? null : _resend,
                child: Text(
                  _resendCooldown > 0 ? '재전송 ($_resendCooldown초 후 가능)' : '인증 메일 다시 받기',
                  style: const TextStyle(
                      fontSize: 13.5, fontWeight: FontWeight.w600, color: DdaengColors.inkSub),
                ),
              ),
              const Spacer(flex: 2),
              TextButton(
                onPressed: () => AuthService().signOut(),
                child: const Text('다른 계정으로 로그인',
                    style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600, color: DdaengColors.inkSub)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
