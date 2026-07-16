import 'dart:async';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../services/auth_service.dart';
import '../../widgets/common/ddaeng_modal.dart';

const _accent = Color(0xFFF5A623);
const _accentSoft = Color(0xFFFFF0A6);
const _ink = Color(0xFF221A16);
const _inkSub = Color(0xFF8A7E77);
const _bg = Color(0xFFFAF8F6);
const _line = Color(0xFFF0E9E4);
const _errorColor = Color(0xFFF04438);
const _okColor = Color(0xFF12B76A);

enum _PwStrength { weak, medium, strong }

_PwStrength _calcPwStrength(String pw) {
  if (pw.length < 6) return _PwStrength.weak;
  var variety = 0;
  if (RegExp(r'[a-z]').hasMatch(pw)) variety++;
  if (RegExp(r'[A-Z]').hasMatch(pw)) variety++;
  if (RegExp(r'[0-9]').hasMatch(pw)) variety++;
  if (RegExp(r'[^a-zA-Z0-9]').hasMatch(pw)) variety++;
  if (variety <= 1) return _PwStrength.weak;
  if (variety == 2 || pw.length < 10) return _PwStrength.medium;
  return _PwStrength.strong;
}

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _auth = AuthService();
  final _codeCtrl = TextEditingController();
  final _pwCtrl = TextEditingController();
  final _pwConfirmCtrl = TextEditingController();

  bool _sending = false;
  bool _submitting = false;
  bool _obscurePw = true;
  bool _obscureConfirm = true;
  int _cooldown = 0;
  Timer? _cooldownTimer;
  _PwStrength _pwStrength = _PwStrength.weak;

  String get _email => FirebaseAuth.instance.currentUser?.email ?? '';

  bool get _canSubmit =>
      !_submitting &&
      _codeCtrl.text.trim().length == 6 &&
      _pwCtrl.text.length >= 6 &&
      _pwStrength != _PwStrength.weak &&
      _pwCtrl.text == _pwConfirmCtrl.text;

  @override
  void initState() {
    super.initState();
    _pwCtrl.addListener(() {
      setState(() => _pwStrength = _calcPwStrength(_pwCtrl.text));
    });
    _codeCtrl.addListener(() => setState(() {}));
    _pwConfirmCtrl.addListener(() => setState(() {}));
    _requestOtp();
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _codeCtrl.dispose();
    _pwCtrl.dispose();
    _pwConfirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _requestOtp() async {
    if (_cooldown > 0 || _sending) return;
    setState(() => _sending = true);
    try {
      await _auth.requestPasswordChangeOtp();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$_email 로 인증번호를 보냈어요'),
          backgroundColor: _ink,
          behavior: SnackBarBehavior.floating,
        ),
      );
      _startCooldown();
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      await DdaengModal.alert(
        context,
        title: '전송에 실패했어요',
        message: _auth.getFunctionsErrorMessage(e),
        type: ModalType.danger,
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _startCooldown() {
    setState(() => _cooldown = 60);
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_cooldown <= 1) {
        t.cancel();
        setState(() => _cooldown = 0);
      } else {
        setState(() => _cooldown--);
      }
    });
  }

  Future<void> _submit() async {
    if (!_canSubmit) return;
    setState(() => _submitting = true);
    try {
      await _auth.verifyPasswordChangeOtp(_codeCtrl.text.trim(), _pwCtrl.text);
      if (!mounted) return;
      await DdaengModal.alert(
        context,
        title: '비밀번호를 변경했어요',
        message: '다음 로그인부터 새 비밀번호를 사용해주세요',
        type: ModalType.success,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      await DdaengModal.alert(
        context,
        title: '변경에 실패했어요',
        message: _auth.getFunctionsErrorMessage(e),
        type: ModalType.danger,
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: _ink,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text('비밀번호 변경', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _accentSoft,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Icon(Icons.mark_email_read_outlined, color: _accent, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '$_email 로 인증번호를 보냈어요.\n5분 이내에 아래에 입력해주세요.',
                    style: const TextStyle(
                        fontSize: 12.5, fontWeight: FontWeight.w600, color: _ink, height: 1.5),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          const _FieldLabel('인증번호', icon: Icons.password_rounded),
          const SizedBox(height: 8),
          TextField(
            controller: _codeCtrl,
            keyboardType: TextInputType.number,
            maxLength: 6,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: const TextStyle(
                fontSize: 20, fontWeight: FontWeight.w800, color: _ink, letterSpacing: 6),
            decoration: InputDecoration(
              counterText: '',
              hintText: '000000',
              hintStyle: const TextStyle(color: Color(0xFFD8D0C9), letterSpacing: 6),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _line)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _line)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: _accent, width: 1.6)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 4),
            child: GestureDetector(
              onTap: (_cooldown > 0 || _sending) ? null : _requestOtp,
              child: Text(
                _cooldown > 0 ? '재전송 ($_cooldown초 후 가능)' : '인증번호 다시 받기',
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: (_cooldown > 0 || _sending) ? _inkSub : _accent),
              ),
            ),
          ),
          const SizedBox(height: 22),

          const _FieldLabel('새 비밀번호', icon: Icons.lock_outline_rounded),
          const SizedBox(height: 8),
          TextField(
            controller: _pwCtrl,
            obscureText: _obscurePw,
            inputFormatters: [FilteringTextInputFormatter.deny(RegExp(r'\s'))],
            style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: _ink),
            decoration: InputDecoration(
              hintText: '영문/숫자/특수문자 조합 6자 이상',
              hintStyle: const TextStyle(fontSize: 13, color: Color(0xFFB8AEA5)),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              suffixIcon: IconButton(
                icon: Icon(_obscurePw ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    size: 19, color: _inkSub),
                onPressed: () => setState(() => _obscurePw = !_obscurePw),
              ),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _line)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _line)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: _accent, width: 1.6)),
            ),
          ),
          if (_pwCtrl.text.isNotEmpty) ...[
            const SizedBox(height: 10),
            _PwStrengthMeter(strength: _pwStrength),
          ],
          const SizedBox(height: 18),

          const _FieldLabel('새 비밀번호 확인', icon: Icons.lock_outline_rounded),
          const SizedBox(height: 8),
          TextField(
            controller: _pwConfirmCtrl,
            obscureText: _obscureConfirm,
            inputFormatters: [FilteringTextInputFormatter.deny(RegExp(r'\s'))],
            style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: _ink),
            decoration: InputDecoration(
              hintText: '새 비밀번호를 다시 입력해주세요',
              hintStyle: const TextStyle(fontSize: 13, color: Color(0xFFB8AEA5)),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              suffixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
              suffixIcon: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_pwConfirmCtrl.text.isNotEmpty)
                      Icon(
                        _pwCtrl.text == _pwConfirmCtrl.text
                            ? Icons.check_circle_rounded
                            : Icons.cancel_rounded,
                        size: 18,
                        color: _pwCtrl.text == _pwConfirmCtrl.text ? _okColor : _errorColor,
                      ),
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      icon: Icon(
                          _obscureConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                          size: 18,
                          color: _inkSub),
                      onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                    ),
                  ],
                ),
              ),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _line)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _line)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: _accent, width: 1.6)),
            ),
          ),
          if (_pwConfirmCtrl.text.isNotEmpty && _pwCtrl.text != _pwConfirmCtrl.text)
            const Padding(
              padding: EdgeInsets.only(top: 6, left: 4),
              child: Text('비밀번호가 일치하지 않아요',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _errorColor)),
            ),
          const SizedBox(height: 32),

          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: _canSubmit ? _submit : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: _accent,
                disabledBackgroundColor: const Color(0xFFE8E1D8),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: _submitting
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                  : const Text('비밀번호 변경하기',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          ),
        ]
            .animate(interval: 55.ms)
            .fadeIn(duration: 340.ms, curve: Curves.easeOut)
            .slideY(begin: 0.06, end: 0, curve: Curves.easeOutCubic),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  final IconData icon;
  const _FieldLabel(this.text, {required this.icon});

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(icon, size: 15, color: _inkSub),
          const SizedBox(width: 6),
          Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _ink)),
        ],
      );
}

class _PwStrengthMeter extends StatelessWidget {
  final _PwStrength strength;
  const _PwStrengthMeter({required this.strength});

  int get _bars {
    switch (strength) {
      case _PwStrength.weak:
        return 1;
      case _PwStrength.medium:
        return 2;
      case _PwStrength.strong:
        return 3;
    }
  }

  Color get _color {
    switch (strength) {
      case _PwStrength.weak:
        return _errorColor;
      case _PwStrength.medium:
        return _accent;
      case _PwStrength.strong:
        return _okColor;
    }
  }

  String get _label {
    switch (strength) {
      case _PwStrength.weak:
        return '약함 — 다른 문자 조합을 섞어보세요';
      case _PwStrength.medium:
        return '보통';
      case _PwStrength.strong:
        return '강함';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Row(
            children: List.generate(3, (i) {
              return Expanded(
                child: Container(
                  margin: EdgeInsets.only(right: i < 2 ? 4 : 0),
                  height: 4,
                  decoration: BoxDecoration(
                    color: i < _bars ? _color : _line,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              );
            }),
          ),
        ),
        const SizedBox(width: 10),
        Text(_label, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: _color)),
      ],
    );
  }
}
