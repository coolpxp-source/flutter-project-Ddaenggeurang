import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async'; // 타임아웃 처리를 위해 추가

import '../../services/auth_service.dart';
import '../../widgets/common/ddaeng_modal.dart';
import '../onboarding/onboarding_screen.dart'; // OnboardingData, DdaengColors
import 'signup_extra_screen.dart';

class EmailSignUpScreen extends StatefulWidget {
  final OnboardingData? onboardingData;
  const EmailSignUpScreen({super.key, this.onboardingData});

  @override
  State<EmailSignUpScreen> createState() => _EmailSignUpScreenState();
}

class _EmailSignUpScreenState extends State<EmailSignUpScreen> {
  final _auth = AuthService();
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _pwCtrl = TextEditingController();
  final _pw2Ctrl = TextEditingController();

  bool _loading = false;
  bool _obscurePw = true;
  bool _obscurePw2 = true;

  @override
  void initState() {
    super.initState();
    // 비밀번호 입력될 때마다 실시간으로 위험도 UI 업데이트
    _pwCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _pwCtrl.dispose();
    _pw2Ctrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    try {
      debugPrint('🔵 [이메일 회원가입] 요청 시작: ${_emailCtrl.text.trim()}');

      // 🔥 15초 안에 응답이 없으면 강제로 TimeoutException을 발생시킵니다 (무한 로딩 방지)
      final user = await _auth.signUpWithEmail(_emailCtrl.text.trim(), _pwCtrl.text)
          .timeout(const Duration(seconds: 15));

      debugPrint('🟢 [이메일 회원가입] 완료: UID=${user?.uid}');

      if (user == null) {
        if (mounted) setState(() => _loading = false);
        return;
      }

      if (!mounted) return;

      debugPrint('🔵 [이메일 회원가입] 추가 정보 입력 화면으로 이동');
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => SignupExtraScreen(
            uid: user.uid,
            email: user.email ?? '',
            onboardingData: widget.onboardingData,
          ),
        ),
      );

    } on FirebaseAuthException catch (e) {
      debugPrint('🔴 [회원가입 실패 - Firebase Auth Error] ${e.code}');
      if (!mounted) return;
      setState(() => _loading = false); // 모달 띄우기 전 반드시 로딩 해제
      await DdaengModal.alert(context,
          title: '통장을 만들지 못했어요',
          message: _auth.getErrorMessage(e),
          type: ModalType.danger);

    } on TimeoutException catch (_) {
      debugPrint('🔴 [회원가입 실패 - 시간 초과]');
      if (!mounted) return;
      setState(() => _loading = false); // 타임아웃 시 로딩 해제
      await DdaengModal.alert(context,
          title: '응답 시간이 초과되었어요',
          message: '네트워크 연결이 불안정합니다.\n잠시 후 다시 시도해주세요.',
          type: ModalType.warning);

    } catch (e) {
      debugPrint('🔴 [회원가입 실패 - 알 수 없는 에러] $e');
      if (!mounted) return;
      setState(() => _loading = false); // 에러 시 로딩 해제
      await DdaengModal.alert(context,
          title: '문제가 생겼어요',
          message: '오류 원인: $e\n잠시 후 다시 시도해주세요.',
          type: ModalType.danger);
    }
  }

  @override
  Widget build(BuildContext context) {
    // ─── 비밀번호 안전도 계산 로직 ───
    int pwLevel = 0; // 1: 위험, 2: 보통, 3: 안전
    String pwLevelText = '';
    Color pwLevelColor = Colors.transparent;

    final pw = _pwCtrl.text;
    if (pw.isNotEmpty) {
      if (pw.length < 6) {
        pwLevel = 1;
        pwLevelText = '너무 짧아요 (6자 이상)';
        pwLevelColor = const Color(0xFFF04438);
      } else {
        bool hasLetters = RegExp(r'[a-zA-Z]').hasMatch(pw);
        bool hasNumbers = RegExp(r'[0-9]').hasMatch(pw);
        bool hasSpecials = RegExp(r'[^a-zA-Z0-9]').hasMatch(pw);

        int mixCount = 0;
        if (hasLetters) mixCount++;
        if (hasNumbers) mixCount++;
        if (hasSpecials) mixCount++;

        if (mixCount == 1) {
          pwLevel = 1;
          pwLevelText = '위험 (영문, 숫자, 특수문자 조합 권장)';
          pwLevelColor = const Color(0xFFF04438);
        } else if (mixCount == 2) {
          pwLevel = 2;
          pwLevelText = '보통 (특수문자를 추가하면 더 안전해요)';
          pwLevelColor = const Color(0xFFFFA900);
        } else {
          pwLevel = 3;
          pwLevelText = '안전 (완벽한 비밀번호예요!)';
          pwLevelColor = const Color(0xFF03C75A);
        }
      }
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: DdaengColors.ink,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(28, 0, 28, 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 8),
                Container(
                  width: 64,
                  height: 64,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      center: Alignment(-0.3, -0.4),
                      colors: [Color(0xFFFFE9A8), Color(0xFFFFC93C), Color(0xFFF5A623)],
                    ),
                  ),
                  alignment: Alignment.center,
                  child: const Text('₩', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Color(0xFF8A5B00))),
                ),
                const SizedBox(height: 20),
                const Text('새로운 통장을\n만들어볼까요', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, height: 1.4, letterSpacing: -0.6, color: DdaengColors.ink)),
                const SizedBox(height: 8),
                const Text('이메일과 비밀번호만 있으면 바로 시작할 수 있어요', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500, color: DdaengColors.inkSub)),
                const SizedBox(height: 32),

                const _FieldLabel('이메일'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  inputFormatters: [FilteringTextInputFormatter.deny(RegExp(r'\s'))], // 공백 차단
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: DdaengColors.ink),
                  validator: (v) {
                    if (v == null || v.isEmpty) return '이메일을 입력해주세요';
                    if (!v.contains('@')) return '이메일 형식이 올바르지 않아요';
                    return null;
                  },
                  decoration: _dec('example@ddaeng.com', Icons.mail_outline_rounded),
                ),
                const SizedBox(height: 20),

                const _FieldLabel('비밀번호'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _pwCtrl,
                  obscureText: _obscurePw,
                  inputFormatters: [FilteringTextInputFormatter.deny(RegExp(r'\s'))], // 공백 차단
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: DdaengColors.ink),
                  validator: (v) {
                    if (v == null || v.isEmpty) return '비밀번호를 입력해주세요';
                    if (v.length < 6) return '6자 이상 입력해주세요';
                    return null;
                  },
                  decoration: _dec(
                    '6자 이상 (공백 제외)',
                    Icons.lock_outline_rounded,
                    suffix: IconButton(
                      icon: Icon(_obscurePw ? Icons.visibility_off_rounded : Icons.visibility_rounded, size: 19, color: DdaengColors.inkSub),
                      onPressed: () => setState(() => _obscurePw = !_obscurePw),
                    ),
                  ),
                ),

                // ─── 비밀번호 위험도 표시 바 ───
                if (pw.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 10, bottom: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            _buildStrengthBar(pwLevel >= 1, pwLevelColor),
                            const SizedBox(width: 4),
                            _buildStrengthBar(pwLevel >= 2, pwLevelColor),
                            const SizedBox(width: 4),
                            _buildStrengthBar(pwLevel >= 3, pwLevelColor),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(pwLevelText, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: pwLevelColor)),
                      ],
                    ),
                  ),

                const SizedBox(height: 20),

                const _FieldLabel('비밀번호 확인'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _pw2Ctrl,
                  obscureText: _obscurePw2,
                  inputFormatters: [FilteringTextInputFormatter.deny(RegExp(r'\s'))], // 공백 차단
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: DdaengColors.ink),
                  validator: (v) {
                    if (v != _pwCtrl.text) return '비밀번호가 일치하지 않아요';
                    return null;
                  },
                  decoration: _dec(
                    '한 번 더 입력해주세요',
                    Icons.lock_outline_rounded,
                    suffix: IconButton(
                      icon: Icon(_obscurePw2 ? Icons.visibility_off_rounded : Icons.visibility_rounded, size: 19, color: DdaengColors.inkSub),
                      onPressed: () => setState(() => _obscurePw2 = !_obscurePw2),
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                SizedBox(
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: DdaengColors.navy,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: _loading
                        ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                        : const Text('통장 만들기', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStrengthBar(bool isActive, Color color) {
    return Expanded(
      child: Container(
        height: 4,
        decoration: BoxDecoration(
          color: isActive ? color : const Color(0xFFE5E8EB),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  InputDecoration _dec(String hint, IconData icon, {Widget? suffix}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFFB0B8C1)),
      prefixIcon: Icon(icon, size: 19, color: DdaengColors.inkSub),
      suffixIcon: suffix,
      filled: true,
      fillColor: DdaengColors.bg,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: DdaengColors.blue, width: 1.6)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFF04438), width: 1.2)),
      errorStyle: const TextStyle(fontSize: 11.5),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(text, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: Color(0xFF4E5968)));
}