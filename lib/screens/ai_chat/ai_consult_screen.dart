import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/user_model.dart';
import '../../services/ai_service.dart' as ai;
import '../../services/consultation_service.dart';
import '../../services/user_service.dart';
import '../../widgets/common/coach_avatar.dart';
import 'consult_history_screen.dart';

// 로컬 AI 코치(은동 PC의 Ollama 서버, lib/services/ai_service.dart)에
// 실시간으로 물어보는 "살까 말까" 상담 채팅 화면.
// AppBar/BottomNav 없이 body만 그리는 위젯 — home_screen.dart의
// NavTab.aiConsult 탭 바디로 그대로 끼워 넣는다 (_HomeDashboard와 동일한 패턴).

const _accent = Color(0xFFF5A623);
const _accentSoft = Color(0xFFFFF0A6);
const _ink = Color(0xFF221A16);
const _inkSub = Color(0xFF8A7E77);
const _bg = Color(0xFFFAF8F6);
const _line = Color(0xFFF0E9E4);
const _errorColor = Color(0xFFF04438);

class AiConsultScreen extends StatefulWidget {
  const AiConsultScreen({super.key});

  @override
  State<AiConsultScreen> createState() => _AiConsultScreenState();
}

class _ChatEntry {
  final bool isUser;
  final bool isError;
  final String text;
  final ai.Verdict? verdict;
  const _ChatEntry.user(this.text)
      : isUser = true, isError = false, verdict = null;
  const _ChatEntry.coach(this.text, this.verdict)
      : isUser = false, isError = false;
  const _ChatEntry.error(this.text)
      : isUser = false, isError = true, verdict = null;
}

class _AiConsultScreenState extends State<AiConsultScreen> {
  final _service = ai.AiService();
  final _questionCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final List<_ChatEntry> _messages = [];

  UserModel? _user;
  bool _sending = false;

  // TODO: 예산 파트(성기필)·지출 파트(임예림) 완성 전까지는 더미 컨텍스트로 상담한다.
  // 실데이터 연동 시 이 5개 값만 실제 예산/지출 집계로 교체하면 됨.
  static const _mockBudgetTotal = 2000000;
  static const _mockBudgetRemain = 760000;
  static const _mockUsedPercent = 62;
  static const _mockImpulsePercent = 34;
  static const _mockDaysToPayday = 12;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  @override
  void dispose() {
    _questionCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadUser() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final u = await UserService().getUser(uid);
    if (mounted) setState(() => _user = u);
  }

  Future<void> _send() async {
    final question = _questionCtrl.text.trim();
    if (question.isEmpty || _sending) return;

    setState(() {
      _messages.add(_ChatEntry.user(question));
      _sending = true;
      _questionCtrl.clear();
    });
    _scrollToBottom();

    final tone = _user?.coachTone ?? ai.CoachTone.ddaengjwi;
    try {
      final result = await _service.consult(
        tone,
        question: question,
        budgetRemain: _mockBudgetRemain,
        budgetTotal: _mockBudgetTotal,
        usedPercent: _mockUsedPercent,
        impulsePercent: _mockImpulsePercent,
        daysToPayday: _mockDaysToPayday,
      );
      if (!mounted) return;
      setState(() => _messages.add(_ChatEntry.coach(result.comment, result.verdict)));
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        unawaited(ConsultationService().save(
          uid: uid,
          question: question,
          answer: result.comment,
          verdictCode: result.verdict?.name,
        ));
      }
    } on ai.RateLimitException catch (e) {
      if (!mounted) return;
      setState(() => _messages.add(_ChatEntry.error(e.message)));
    } on ai.AiServerException catch (e) {
      if (!mounted) return;
      setState(() => _messages.add(_ChatEntry.error(e.message)));
    } catch (_) {
      if (!mounted) return;
      setState(() => _messages
          .add(const _ChatEntry.error('알 수 없는 오류가 발생했어요. 다시 시도해주세요.')));
    } finally {
      if (mounted) setState(() => _sending = false);
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollCtrl.hasClients) return;
      _scrollCtrl.animateTo(
        _scrollCtrl.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final imagePath = (_user?.coachTone ?? ai.CoachTone.ddaengjwi).imagePath;
    return Container(
      color: _bg,
      child: Column(
        children: [
          _RemainingBanner(
            remaining: _service.consultRemaining,
            onHistoryTap: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const ConsultHistoryScreen())),
          ),
          Expanded(
            child: _messages.isEmpty
                ? _EmptyState(imagePath: imagePath)
                : ListView.builder(
              controller: _scrollCtrl,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              itemCount: _messages.length + (_sending ? 1 : 0),
              itemBuilder: (context, i) {
                if (i == _messages.length) return const _TypingBubble();
                return _MessageBubble(entry: _messages[i], imagePath: imagePath);
              },
            ),
          ),
          _InputBar(controller: _questionCtrl, sending: _sending, onSend: _send),
        ],
      ),
    );
  }
}

class _RemainingBanner extends StatelessWidget {
  final int remaining;
  final VoidCallback onHistoryTap;
  const _RemainingBanner({required this.remaining, required this.onHistoryTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      color: _accentSoft,
      child: Row(
        children: [
          Expanded(
            child: Text('오늘 남은 상담 $remaining회',
                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: _accent)),
          ),
          InkWell(
            onTap: onHistoryTap,
            borderRadius: BorderRadius.circular(20),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.history_rounded, size: 15, color: _accent),
                  SizedBox(width: 3),
                  Text('이력',
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: _accent)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String imagePath;
  const _EmptyState({required this.imagePath});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CoachAvatar(imagePath: imagePath, size: 72),
            const SizedBox(height: 14),
            const Text('살까 말까 고민되는 걸 물어보세요',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _ink)),
            const SizedBox(height: 6),
            const Text('예산이랑 최근 소비 패턴을 보고 코치가 판정해드려요',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12.5, color: _inkSub, height: 1.4)),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final _ChatEntry entry;
  final String imagePath;
  const _MessageBubble({required this.entry, required this.imagePath});

  Color? _verdictColor() {
    switch (entry.verdict) {
      case ai.Verdict.buy:
        return const Color(0xFF12B76A);
      case ai.Verdict.hold:
        return _errorColor;
      case ai.Verdict.conditional:
        return const Color(0xFF8A6400);
      case null:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (entry.isUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: const BoxDecoration(
            color: _accent,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(4),
              bottomLeft: Radius.circular(16),
              bottomRight: Radius.circular(16),
            ),
          ),
          child: Text(entry.text,
              style: const TextStyle(
                  color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600, height: 1.4)),
        ),
      );
    }

    final verdictColor = _verdictColor();
    return Align(
      alignment: Alignment.centerLeft,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
              radius: 16,
              backgroundColor: _accentSoft,
              backgroundImage: AssetImage(imagePath)),
          const SizedBox(width: 8),
          Flexible(
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: entry.isError ? const Color(0xFFFFF1F0) : Colors.white,
                border: Border.all(color: entry.isError ? _errorColor : _line),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (verdictColor != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                          color: verdictColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(20)),
                      child: Text(entry.verdict!.label,
                          style: TextStyle(
                              fontSize: 11, fontWeight: FontWeight.w800, color: verdictColor)),
                    ),
                    const SizedBox(height: 6),
                  ],
                  Text(entry.text,
                      style: TextStyle(
                          fontSize: 14,
                          height: 1.5,
                          fontWeight: FontWeight.w500,
                          color: entry.isError ? _errorColor : _ink)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    return const Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: EdgeInsets.only(left: 40, bottom: 12),
        child: SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2, color: _accent),
        ),
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;
  const _InputBar({required this.controller, required this.sending, required this.onSend});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(12, 10, 12, 10 + MediaQuery.of(context).padding.bottom),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: _line)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => onSend(),
              decoration: InputDecoration(
                hintText: '예: 15만원짜리 이어폰 사도 될까요?',
                hintStyle: const TextStyle(fontSize: 13.5, color: Color(0xFFACA49E)),
                filled: true,
                fillColor: _bg,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
              ),
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: sending ? null : onSend,
            borderRadius: BorderRadius.circular(22),
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: sending ? const Color(0xFFFFE9A8) : _accent,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}
