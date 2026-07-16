import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../widgets/common/ddaeng_modal.dart';

const _accent = Color(0xFFF5A623);
const _accentSoft = Color(0xFFFFF0A6);
const _ink = Color(0xFF221A16);
const _inkSub = Color(0xFF8A7E77);
const _bg = Color(0xFFFAF8F6);
const _line = Color(0xFFF0E9E4);

const _kCategories = ['계정/로그인', '결제/포인트', '버그 신고', '기능 제안', '기타'];

class ContactScreen extends StatefulWidget {
  const ContactScreen({super.key});

  @override
  State<ContactScreen> createState() => _ContactScreenState();
}

class _ContactScreenState extends State<ContactScreen> {
  final _messageCtrl = TextEditingController();
  String _category = _kCategories.first;
  bool _submitting = false;

  bool get _canSubmit => !_submitting && _messageCtrl.text.trim().length >= 5;

  @override
  void initState() {
    super.initState();
    _messageCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _messageCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_canSubmit) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _submitting = true);
    try {
      await FirebaseFirestore.instance.collection('inquiries').add({
        'uid': user.uid,
        'email': user.email ?? '',
        'category': _category,
        'message': _messageCtrl.text.trim(),
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (!mounted) return;
      await DdaengModal.alert(
        context,
        title: '문의가 접수됐어요',
        message: '확인 후 가입하신 이메일로 답변드릴게요',
        type: ModalType.success,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      await DdaengModal.alert(
        context,
        title: '접수에 실패했어요',
        message: '잠시 후 다시 시도해주세요',
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
        title: const Text('문의하기', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text('무엇을 도와드릴까요?',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: _ink)),
          const SizedBox(height: 4),
          const Text('남겨주신 내용은 가입하신 이메일로 답변드려요',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: _inkSub)),
          const SizedBox(height: 24),

          const Text('카테고리', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _ink)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _kCategories.map((c) {
              final sel = c == _category;
              return GestureDetector(
                onTap: () => setState(() => _category = c),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(
                    color: sel ? _accentSoft : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: sel ? _accent : _line, width: sel ? 1.4 : 1),
                  ),
                  child: Text(c,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: sel ? const Color(0xFF8A5A00) : _inkSub)),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 22),

          const Text('문의 내용', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _ink)),
          const SizedBox(height: 10),
          TextField(
            controller: _messageCtrl,
            maxLines: 8,
            maxLength: 1000,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: _ink, height: 1.5),
            decoration: InputDecoration(
              hintText: '어떤 문제가 있었는지, 언제 발생했는지 최대한 자세히 적어주시면 도움이 돼요',
              hintStyle: const TextStyle(fontSize: 13, color: Color(0xFFB8AEA5), height: 1.5),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.all(16),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _line)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _line)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: _accent, width: 1.6)),
            ),
          ),
          const SizedBox(height: 28),

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
                  : const Text('문의 보내기',
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
