import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/auth_service.dart';
import '../../widgets/common/ddaeng_modal.dart';
import '../onboarding/onboarding_screen.dart'; // OnboardingData, DdaengColors
import 'signup_extra_screen.dart';

enum _PwStrength { weak, medium, strong }

_PwStrength _calcPwStrength(String pw) {
  if (pw.length < 8) return _PwStrength.weak;
  int variety = 0;
  if (RegExp(r'[a-z]').hasMatch(pw)) variety++;
  if (RegExp(r'[A-Z]').hasMatch(pw)) variety++;
  if (RegExp(r'[0-9]').hasMatch(pw)) variety++;
  if (RegExp(r'[!@#$%^&*(),.?":{}|<>_\-+=~`\[\]/\\;]').hasMatch(pw)) {
    variety++;
  }
  if (variety <= 1) return _PwStrength.weak;
  if (variety == 2 || pw.length < 12) return _PwStrength.medium;
  return _PwStrength.strong;
}

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

  _PwStrength _pwStrength = _PwStrength.weak;

  @override
  void initState() {
    super.initState();
    _pwCtrl.addListener(_onPwChanged);
    _pw2Ctrl.addListener(() => setState(() {}));
  }

  void _onPwChanged() {
    setState(() => _pwStrength = _calcPwStrength(_pwCtrl.text));
  }

  bool get _isPwSafe =>
      _pwCtrl.text.isNotEmpty &&
      !_pwCtrl.text.contains(' ') &&
      _pwStrength != _PwStrength.weak;

  bool get _canSubmit =>
      !_loading && _isPwSafe && _pw2Ctrl.text == _pwCtrl.text;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _pwCtrl.dispose();
    _pw2Ctrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_isPwSafe) return;

    setState(() => _loading = true);
    try {
      final user =
      await _auth.signUpWithEmail(_emailCtrl.text.trim(), _pwCtrl.text);
      if (user == null) return;

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
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      await DdaengModal.alert(
        context,
        title: '통장을 만들지 못했어요',
        message: _auth.getErrorMessage(e),
        type: ModalType.danger,
      );
    } catch (e) {
      if (!mounted) return;
      await DdaengModal.alert(
        context,
        title: '문제가 생겼어요',
        message: '잠시 후 다시 시도해주세요',
        type: ModalType.danger,
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
                      colors: [
                        Color(0xFFFFE9A8),
                        Color(0xFFFFC93C),
                        Color(0xFFF5A623),
                      ],
                    ),
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    '₩',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF8A5B00),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  '새로운 통장을\n만들어볼까요',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    height: 1.4,
                    letterSpacing: -0.6,
                    color: DdaengColors.ink,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '이메일과 비밀번호만 있으면 바로 시작할 수 있어요',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                    color: DdaengColors.inkSub,
                  ),
                ),
                const SizedBox(height: 32),

                const _FieldLabel('이메일'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: DdaengColors.ink,
                  ),
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
                  inputFormatters: [FilteringTextInputFormatter.deny(RegExp(r'\s'))],
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: DdaengColors.ink,
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return '비밀번호를 입력해주세요';
                    if (v.contains(' ')) return '공백은 사용할 수 없어요';
                    if (v.length < 8) return '8자 이상 입력해주세요';
                    if (_pwStrength == _PwStrength.weak) {
                      return '영문/숫자/특수문자를 조합해 더 안전하게 만들어주세요';
                    }
                    return null;
                  },
                  decoration: _dec(
                    '8자 이상, 공백 없이 입력해주세요',
                    Icons.lock_outline_rounded,
                    suffix: IconButton(
                      icon: Icon(
                        _obscurePw
                            ? Icons.visibility_off_rounded
                            : Icons.visibility_rounded,
                        size: 19,
                        color: DdaengColors.inkSub,
                      ),
                      onPressed: () => setState(() => _obscurePw = !_obscurePw),
                    ),
                  ),
                ),
                if (_pwCtrl.text.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _PwStrengthMeter(strength: _pwStrength),
                ],
                const SizedBox(height: 20),

                const _FieldLabel('비밀번호 확인'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _pw2Ctrl,
                  obscureText: _obscurePw2,
                  inputFormatters: [FilteringTextInputFormatter.deny(RegExp(r'\s'))],
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: DdaengColors.ink,
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return '비밀번호를 한 번 더 입력해주세요';
                    if (v != _pwCtrl.text) return '비밀번호가 일치하지 않아요';
                    return null;
                  },
                  decoration: _dec(
                    '한 번 더 입력해주세요',
                    Icons.lock_outline_rounded,
                    suffix: IconButton(
                      icon: Icon(
                        _obscurePw2
                            ? Icons.visibility_off_rounded
                            : Icons.visibility_rounded,
                        size: 19,
                        color: DdaengColors.inkSub,
                      ),
                      onPressed: () => setState(() => _obscurePw2 = !_obscurePw2),
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                SizedBox(
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _canSubmit ? _submit : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: DdaengColors.navy,
                      disabledBackgroundColor: const Color(0xFFE5E8EB),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: _loading
                        ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: Colors.white,
                      ),
                    )
                        : const Text(
                      '통장 만들기',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _dec(String hint, IconData icon, {Widget? suffix}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: Color(0xFFB0B8C1),
      ),
      prefixIcon: Icon(icon, size: 19, color: DdaengColors.inkSub),
      suffixIcon: suffix,
      filled: true,
      fillColor: DdaengColors.bg,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: DdaengColors.blue, width: 1.6),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFF04438), width: 1.2),
      ),
      errorStyle: const TextStyle(fontSize: 11.5),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      fontSize: 13.5,
      fontWeight: FontWeight.w700,
      color: Color(0xFF4E5968),
    ),
  );
}

/// 비밀번호 강도 표시 바 — 낮음이면 빨강(위험), 보통이면 주황, 높음이면 초록(안전)
class _PwStrengthMeter extends StatelessWidget {
  final _PwStrength strength;
  const _PwStrengthMeter({required this.strength});

  static const _weakColor = Color(0xFFF04438);
  static const _mediumColor = Color(0xFFF79009);
  static const _strongColor = Color(0xFF12B76A);

  Color get _color {
    switch (strength) {
      case _PwStrength.weak:
        return _weakColor;
      case _PwStrength.medium:
        return _mediumColor;
      case _PwStrength.strong:
        return _strongColor;
    }
  }

  String get _label {
    switch (strength) {
      case _PwStrength.weak:
        return '강도 낮음(위험) · 8자 이상 영문/숫자/특수문자를 조합해주세요';
      case _PwStrength.medium:
        return '강도 보통 · 조금 더 복잡하게 만들면 좋아요';
      case _PwStrength.strong:
        return '강도 높음(안전) · 안전한 비밀번호예요';
    }
  }

  int get _filledBars {
    switch (strength) {
      case _PwStrength.weak:
        return 1;
      case _PwStrength.medium:
        return 2;
      case _PwStrength.strong:
        return 3;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: List.generate(3, (i) {
            final filled = i < _filledBars;
            return Expanded(
              child: Container(
                margin: EdgeInsets.only(right: i < 2 ? 6 : 0),
                height: 4,
                decoration: BoxDecoration(
                  color: filled ? _color : const Color(0xFFE5E8EB),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 6),
        Text(
          _label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: _color,
          ),
        ),
      ],
    );
  }
}