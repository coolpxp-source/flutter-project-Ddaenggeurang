import 'dart:async';
import 'package:add_2_calendar/add_2_calendar.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/user_model.dart';
import '../../services/ai_service.dart' as ai;
import '../../services/budget_vs_expense_service.dart';
import '../../services/consultation_service.dart';
import '../../services/emotion_summary_service.dart';
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
  final String? question; // coach 답변에만 채워짐 — 캘린더 등록 시 일정 제목으로 쓴다.
  const _ChatEntry.user(this.text)
      : isUser = true, isError = false, verdict = null, question = null;
  const _ChatEntry.coach(this.text, this.verdict, {this.question})
      : isUser = false, isError = false;
  const _ChatEntry.error(this.text)
      : isUser = false, isError = true, verdict = null, question = null;
}

class _AiConsultScreenState extends State<AiConsultScreen> {
  final _service = ai.AiService();
  final _budgetService = BudgetVsExpenseService();
  final _emotionService = EmotionSummaryService();
  final _questionCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final List<_ChatEntry> _messages = [];

  UserModel? _user;
  bool _sending = false;

  // 예산(성기필)·감정태그(임예림) 실데이터 로드 전까지 화면에 뿌려줄 폴백 값.
  // 로그인 사용자의 이번 달 예산/지출 문서가 아직 없을 때도 상담이 끊기지 않도록 유지한다.
  static const _fallbackBudgetTotal = 2000000;
  static const _fallbackBudgetRemain = 760000;
  static const _fallbackUsedPercent = 62;
  static const _fallbackImpulsePercent = 34;

  int _budgetTotal = _fallbackBudgetTotal;
  int _budgetRemain = _fallbackBudgetRemain;
  int _usedPercent = _fallbackUsedPercent;
  int _impulsePercent = _fallbackImpulsePercent;

  // 예산 컨텍스트 카드 표시 여부 제어용.
  // hasBudgetData가 true일 때만 위 실데이터(혹은 폴백)를 화면에 그대로 노출한다 —
  // 예산을 아직 설정 안 한 사용자에게 남의 폴백 숫자를 진짜처럼 보여주지 않기 위함.
  bool _budgetContextLoaded = false;
  bool _hasBudgetData = false;

  /// 급여일 필드가 아직 사용자 모델에 없어 실제 페이데이 계산은 불가능하다.
  /// 대신 이번 달 마지막 날까지 남은 일수를 근사치로 사용한다.
  int get _daysToPayday {
    final now = DateTime.now();
    final nextMonthStart = DateTime(now.year, now.month + 1, 1);
    return nextMonthStart.difference(DateTime(now.year, now.month, now.day)).inDays;
  }

  @override
  void initState() {
    super.initState();
    _loadUser();
    _loadBudgetContext();
  }

  Future<void> _loadBudgetContext() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final now = DateTime.now();
    final monthKey = '${now.year}-${now.month.toString().padLeft(2, '0')}';

    bool hasBudget = false;

    try {
      final budget = await _budgetService
          .watchBudgetVsExpense(userId: uid, monthKey: monthKey)
          .first;
      if (mounted && budget.totalBudget > 0) {
        hasBudget = true;
        setState(() {
          _budgetTotal = budget.totalBudget;
          _budgetRemain = budget.remainingAmount;
          _usedPercent = (budget.usageRate * 100).round();
        });
      }
    } catch (_) {
      // 이번 달 예산 문서가 없거나 조회 실패 — 폴백 값 유지
    }

    try {
      final emotions = await _emotionService.getEmotionSummary(
        userId: uid,
        year: now.year,
        month: now.month,
      );
      final impulsive =
          emotions.where((e) => e.emotionKey == 'impulsive').toList();
      if (mounted && impulsive.isNotEmpty) {
        setState(() => _impulsePercent = impulsive.first.percentage.round());
      }
    } catch (_) {
      // 이번 달 지출 데이터가 없거나 조회 실패 — 폴백 값 유지
    }

    if (mounted) {
      setState(() {
        _budgetContextLoaded = true;
        _hasBudgetData = hasBudget;
      });
    }
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
        budgetRemain: _budgetRemain,
        budgetTotal: _budgetTotal,
        usedPercent: _usedPercent,
        impulsePercent: _impulsePercent,
        daysToPayday: _daysToPayday,
      );
      if (!mounted) return;
      setState(() =>
          _messages.add(_ChatEntry.coach(result.comment, result.verdict, question: question)));
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

  /// 빈 상태에 뜨는 예시 질문 칩을 탭했을 때 — 바로 전송하지 않고 입력창에
  /// 채워만 줘서, 사용자가 금액/상황을 바꿔서 보낼 수 있게 한다.
  void _pickSuggestion(String text) {
    _questionCtrl.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
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
          _BudgetContextCard(
            loaded: _budgetContextLoaded,
            hasData: _hasBudgetData,
            budgetRemain: _budgetRemain,
            usedPercent: _usedPercent,
            impulsePercent: _impulsePercent,
            daysToPayday: _daysToPayday,
          ),
          Expanded(
            child: _messages.isEmpty
                ? _EmptyState(imagePath: imagePath, onSuggestionTap: _pickSuggestion)
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

class _BudgetContextCard extends StatelessWidget {
  final bool loaded;
  final bool hasData;
  final int budgetRemain;
  final int usedPercent;
  final int impulsePercent;
  final int daysToPayday;

  const _BudgetContextCard({
    required this.loaded,
    required this.hasData,
    required this.budgetRemain,
    required this.usedPercent,
    required this.impulsePercent,
    required this.daysToPayday,
  });

  Color get _progressColor {
    if (usedPercent >= 100) return _errorColor;
    if (usedPercent >= 70) return _accent;
    return const Color(0xFF12B76A);
  }

  String _formatWon(int amount) {
    final digits = amount.abs().toString();
    final buf = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buf.write(',');
      buf.write(digits[i]);
    }
    return '${amount < 0 ? '-' : ''}$buf원';
  }

  @override
  Widget build(BuildContext context) {
    if (!loaded) {
      return const SizedBox.shrink();
    }

    if (!hasData) {
      return Container(
        margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _line),
        ),
        child: const Row(
          children: [
            Icon(Icons.info_outline_rounded, size: 16, color: _inkSub),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                '이번 달 예산을 등록하면 코치가 더 정확하게 판정해줘요',
                style: TextStyle(fontSize: 12, color: _inkSub, height: 1.3),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _line),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('이번 달 남은 예산',
                  style: TextStyle(
                      fontSize: 11.5, fontWeight: FontWeight.w700, color: _inkSub)),
              Text('$usedPercent% 사용',
                  style: TextStyle(
                      fontSize: 11.5, fontWeight: FontWeight.w800, color: _progressColor)),
            ],
          ),
          const SizedBox(height: 4),
          Text(_formatWon(budgetRemain),
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: budgetRemain < 0 ? _errorColor : _ink)),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LinearProgressIndicator(
              value: (usedPercent / 100).clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: _bg,
              valueColor: AlwaysStoppedAnimation<Color>(_progressColor),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _StatChip(
                icon: Icons.local_fire_department_rounded,
                label: '충동소비 $impulsePercent%',
                color: const Color(0xFFF04438),
              ),
              const SizedBox(width: 8),
              _StatChip(
                icon: Icons.event_rounded,
                label: '이번 달 D-$daysToPayday',
                color: _accent,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _StatChip({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }
}

/// 빈 상태에서 보여줄 예시 질문 — 뭘 물어봐야 할지 모르는 사용자를 위한
/// 시작점. 탭하면 입력창에 그대로 채워지고, 전송은 사용자가 직접 한다.
/// 아이콘/색을 질문 내용에 맞춰 다르게 줘서 4개가 다 똑같아 보이지 않게 한다.
class _SuggestedQuestion {
  final String text;
  final IconData icon;
  final Color color;
  const _SuggestedQuestion(this.text, this.icon, this.color);
}

const _suggestedQuestions = <_SuggestedQuestion>[
  _SuggestedQuestion('5만원짜리 옷 사도 될까요?', Icons.shopping_bag_rounded, Color(0xFFFF6F91)),
  _SuggestedQuestion(
      '친구랑 저녁 약속인데 얼마나 써도 될까요?', Icons.restaurant_rounded, Color(0xFF4F7DF3)),
  _SuggestedQuestion('이번 달 예산 안에서 여유 있나요?', Icons.savings_rounded, Color(0xFF00C2A8)),
  _SuggestedQuestion(
      '스트레스 받아서 홧김에 지르고 싶은데 어때요?', Icons.local_fire_department_rounded, _accent),
];

class _EmptyState extends StatelessWidget {
  final String imagePath;
  final ValueChanged<String> onSuggestionTap;
  const _EmptyState({required this.imagePath, required this.onSuggestionTap});

  @override
  Widget build(BuildContext context) {
    // Center에 담아 화면 한가운데로 몰아두면 콘텐츠가 짧아서 위아래로 큰
    // 빈 공간이 생겨 구도가 붕 뜬다. 대신 위쪽에 붙여 소개문+질문 목록이
    // 하나의 흐름으로 이어지도록 한다.
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
      child: Column(
        children: [
          CoachAvatar(imagePath: imagePath, size: 64),
          const SizedBox(height: 12),
          const Text('살까 말까 고민되는 걸 물어보세요',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _ink)),
          const SizedBox(height: 6),
          const Text('예산이랑 최근 소비 패턴을 보고 코치가 판정해드려요',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, color: _inkSub, height: 1.4)),
          const SizedBox(height: 28),
          Align(
            alignment: Alignment.centerLeft,
            child: Text('이런 질문은 어때요?',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: _inkSub)),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                    color: _ink.withValues(alpha: 0.05), blurRadius: 16, offset: const Offset(0, 6)),
              ],
            ),
            child: Column(
              children: [
                for (final (i, q) in _suggestedQuestions.indexed) ...[
                  if (i > 0) const Divider(height: 1, indent: 14, endIndent: 14, color: _line),
                  _SuggestionRow(question: q, onTap: () => onSuggestionTap(q.text)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SuggestionRow extends StatelessWidget {
  final _SuggestedQuestion question;
  final VoidCallback onTap;
  const _SuggestionRow({required this.question, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                  color: question.color.withValues(alpha: 0.14), shape: BoxShape.circle),
              alignment: Alignment.center,
              child: Icon(question.icon, size: 15, color: question.color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(question.text,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _ink)),
            ),
            const Icon(Icons.north_east_rounded, size: 14, color: _inkSub),
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

  /// "사도 됨" 판정을 기기 캘린더에 할 일로 등록한다 — 지출 입력 화면과는
  /// 완전히 별개로, 기기 캘린더 앱에 인텐트만 넘기는 방식이라 별도 권한이 필요 없다.
  Future<void> _addToCalendar(BuildContext context) async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day, now.hour + 1);
    final event = Event(
      title: '🛍️ ${entry.question}',
      description: entry.text,
      startDate: start,
      endDate: start.add(const Duration(hours: 1)),
    );
    final added = await Add2Calendar.addEvent2Cal(event);
    if (context.mounted && !added) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('캘린더 앱을 열지 못했어요')));
    }
  }

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
                  if (entry.verdict == ai.Verdict.buy && entry.question != null) ...[
                    const SizedBox(height: 10),
                    InkWell(
                      onTap: () => _addToCalendar(context),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF12B76A).withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.event_available_rounded,
                                size: 14, color: Color(0xFF12B76A)),
                            SizedBox(width: 6),
                            Text('캘린더에 등록하기',
                                style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF12B76A))),
                          ],
                        ),
                      ),
                    ),
                  ],
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
