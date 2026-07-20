import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/consultation_model.dart';
import '../../services/ai_service.dart' as ai;
import '../../services/consultation_service.dart';
import '../../widgets/common/ddaeng_modal.dart';
import 'consult_share_card_screen.dart';

const _accent = Color(0xFFF5A623);
const _ink = Color(0xFF221A16);
const _inkSub = Color(0xFF8A7E77);
const _bg = Color(0xFFFAF8F6);
const _errorColor = Color(0xFFF04438);

/// 검색/필터용 판정 값 — ai.Verdict 3종 + "전체".
enum _VerdictFilter {
  all('전체', null),
  buy('사도 됨', 'buy'),
  hold('보류', 'hold'),
  conditional('조건부', 'conditional');

  final String label;
  final String? code;
  const _VerdictFilter(this.label, this.code);
}

/// 41_상담이력 — 지금까지 받은 "살까말까" AI 상담 결과를 모아 보여준다.
/// 검색어(질문/답변)와 판정 필터로 원하는 기록을 좁혀볼 수 있다.
class ConsultHistoryScreen extends StatefulWidget {
  const ConsultHistoryScreen({super.key});

  @override
  State<ConsultHistoryScreen> createState() => _ConsultHistoryScreenState();
}

class _ConsultHistoryScreenState extends State<ConsultHistoryScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  _VerdictFilter _filter = _VerdictFilter.all;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<ConsultationEntry> _applyFilter(List<ConsultationEntry> items) {
    return items.where((e) {
      if (_filter.code != null && e.verdictCode != _filter.code) return false;
      if (_query.isEmpty) return true;
      final q = _query.toLowerCase();
      return e.question.toLowerCase().contains(q) || e.answer.toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: _ink,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text('상담 이력', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: uid == null
          ? const SizedBox.shrink()
          : StreamBuilder<List<ConsultationEntry>>(
              stream: ConsultationService().watchHistory(uid),
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const Center(
                      child: CircularProgressIndicator(color: _accent, strokeWidth: 2.4));
                }
                final items = snap.data!;
                if (items.isEmpty) {
                  return const _EmptyHistory();
                }
                final filtered = _applyFilter(items);
                final rowCount = filtered.isEmpty ? 3 : filtered.length + 2;
                return ListView.separated(
                  padding: const EdgeInsets.all(20),
                  itemCount: rowCount,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, i) {
                    if (i == 0) return _InsightCard(items: items);
                    if (i == 1) {
                      return _SearchAndFilterBar(
                        controller: _searchCtrl,
                        filter: _filter,
                        onQueryChanged: (v) => setState(() => _query = v),
                        onFilterChanged: (f) => setState(() => _filter = f),
                      );
                    }
                    if (filtered.isEmpty) return const _NoMatchNotice();
                    final entryIndex = i - 2;
                    return _ConsultationCard(uid: uid, entry: filtered[entryIndex]);
                  },
                );
              },
            ),
    );
  }
}

class _SearchAndFilterBar extends StatelessWidget {
  final TextEditingController controller;
  final _VerdictFilter filter;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<_VerdictFilter> onFilterChanged;

  const _SearchAndFilterBar({
    required this.controller,
    required this.filter,
    required this.onQueryChanged,
    required this.onFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          onChanged: onQueryChanged,
          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: _ink),
          decoration: InputDecoration(
            hintText: '질문이나 답변 내용으로 검색',
            hintStyle: const TextStyle(fontSize: 13, color: Color(0xFFB0A89F)),
            prefixIcon: const Icon(Icons.search_rounded, size: 20, color: _inkSub),
            suffixIcon: controller.text.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18, color: _inkSub),
                    onPressed: () {
                      controller.clear();
                      onQueryChanged('');
                    },
                  ),
            filled: true,
            fillColor: Colors.white,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 32,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _VerdictFilter.values.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final f = _VerdictFilter.values[i];
              final selected = f == filter;
              return GestureDetector(
                onTap: () => onFilterChanged(f),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selected ? _accent : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: selected ? _accent : const Color(0xFFE8E1D8)),
                  ),
                  child: Text(f.label,
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: selected ? Colors.white : _inkSub)),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _NoMatchNotice extends StatelessWidget {
  const _NoMatchNotice();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search_off_rounded, size: 34, color: _inkSub),
            const SizedBox(height: 10),
            const Text('조건에 맞는 상담 기록이 없어요',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _inkSub)),
          ],
        ),
      ),
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.forum_outlined, size: 44, color: _inkSub),
            const SizedBox(height: 14),
            const Text('아직 상담 기록이 없어요',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _ink)),
            const SizedBox(height: 6),
            const Text('AI상담 탭에서 "이거 살까 말까" 물어보면\n여기에 기록이 쌓여요',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12.5, color: _inkSub, height: 1.5)),
          ],
        ),
      ),
    );
  }
}

/// 나의 상담 습관 — 상담이력을 집계해서(계산은 코드로) 보여주는 요약 카드.
/// LLM은 쓰지 않는다: 이 카드는 즉시 렌더돼야 하므로 은동 PC(Ollama)가
/// 꺼져 있어도 항상 뜬다.
class _InsightCard extends StatelessWidget {
  final List<ConsultationEntry> items;
  const _InsightCard({required this.items});

  @override
  Widget build(BuildContext context) {
    var buy = 0, hold = 0, conditional = 0;
    for (final e in items) {
      switch (e.verdictCode) {
        case 'buy':
          buy++;
        case 'hold':
          hold++;
        case 'conditional':
          conditional++;
      }
    }
    final total = items.length;
    final holdPercent = total == 0 ? 0 : (hold / total * 100).round();

    final String message;
    if (holdPercent >= 50) {
      message = '상담 중 $holdPercent%를 참아냈어요 — 충동구매를 잘 다스리고 있어요!';
    } else if (total > 0 && buy / total >= 0.5) {
      message = '필요한 소비는 확실하게 하는 편이네요 — 계획적인 소비 습관이에요!';
    } else {
      message = '상황에 따라 유연하게 판단하고 있어요 — 좋은 소비 습관이에요!';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: _accent.withValues(alpha: 0.1), blurRadius: 16, offset: const Offset(0, 6)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('나의 상담 습관',
              style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800, color: _ink)),
          const SizedBox(height: 4),
          Text('지금까지 $total번 상담했어요',
              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500, color: _inkSub)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                  child: _verdictStat('사도 됨', buy, const Color(0xFF12B76A))),
              const SizedBox(width: 10),
              Expanded(child: _verdictStat('보류', hold, _errorColor)),
              const SizedBox(width: 10),
              Expanded(
                  child: _verdictStat('조건부', conditional, const Color(0xFF8A6400))),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(color: _bg, borderRadius: BorderRadius.circular(12)),
            child: Text(message,
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600, color: _ink, height: 1.4)),
          ),
          if (total > 0) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => ConsultShareCardScreen(items: items))),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _accent,
                  side: const BorderSide(color: _accent, width: 1.2),
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.auto_awesome_rounded, size: 16),
                label: const Text('카드로 공유하기',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _verdictStat(String label, int count, Color color) => Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Text('$count',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: color)),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: color)),
          ],
        ),
      );
}

class _ConsultationCard extends StatelessWidget {
  final String uid;
  final ConsultationEntry entry;
  const _ConsultationCard({required this.uid, required this.entry});

  ai.Verdict? get _verdict {
    for (final v in ai.Verdict.values) {
      if (v.name == entry.verdictCode) return v;
    }
    return null;
  }

  Color _verdictColor(ai.Verdict v) {
    switch (v) {
      case ai.Verdict.buy:
        return const Color(0xFF12B76A);
      case ai.Verdict.hold:
        return _errorColor;
      case ai.Verdict.conditional:
        return const Color(0xFF8A6400);
    }
  }

  String _formatDate(DateTime d) {
    return '${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}';
  }

  Future<void> _share(BuildContext context) async {
    final verdictLabel = _verdict?.label;
    final text = '[땡그랑 AI상담]\n'
        'Q. ${entry.question}\n'
        '${verdictLabel != null ? '판정: $verdictLabel\n' : ''}'
        'A. ${entry.answer}';
    await SharePlus.instance.share(ShareParams(text: text));
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final ok = await DdaengModal.confirm(
      context,
      title: '이 상담 기록을 삭제할까요?',
      message: '삭제하면 되돌릴 수 없어요',
      type: ModalType.danger,
      confirmText: '삭제',
    );
    if (ok) {
      await ConsultationService().delete(uid: uid, consultationId: entry.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final verdict = _verdict;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: _ink.withValues(alpha: 0.045), blurRadius: 14, offset: const Offset(0, 5)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (verdict != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: _verdictColor(verdict).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(verdict.label,
                      style: TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w800, color: _verdictColor(verdict))),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(_formatDate(entry.date),
                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: _inkSub)),
              ),
              InkWell(
                onTap: () => _share(context),
                borderRadius: BorderRadius.circular(20),
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.ios_share_rounded, size: 15, color: _inkSub),
                ),
              ),
              InkWell(
                onTap: () => _confirmDelete(context),
                borderRadius: BorderRadius.circular(20),
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.close_rounded, size: 16, color: _inkSub),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(entry.question,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _ink)),
          const SizedBox(height: 6),
          Text(entry.answer,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 12.5, fontWeight: FontWeight.w500, color: _inkSub, height: 1.5)),
          const SizedBox(height: 10),
          Row(
            children: [
              const Text('이 답변이 도움됐나요?',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _inkSub)),
              const SizedBox(width: 8),
              _FeedbackIcon(
                icon: Icons.thumb_up_alt_rounded,
                active: entry.feedback == 'helpful',
                onTap: () => _setFeedback('helpful'),
              ),
              const SizedBox(width: 4),
              _FeedbackIcon(
                icon: Icons.thumb_down_alt_rounded,
                active: entry.feedback == 'unhelpful',
                onTap: () => _setFeedback('unhelpful'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 같은 버튼을 다시 누르면 평가를 취소한다. 별도 setState 없이 Firestore
  /// 스트림(watchHistory)이 업데이트를 받아 화면을 다시 그려준다.
  Future<void> _setFeedback(String value) {
    final next = entry.feedback == value ? null : value;
    return ConsultationService()
        .setFeedback(uid: uid, consultationId: entry.id, feedback: next);
  }
}

class _FeedbackIcon extends StatelessWidget {
  final IconData icon;
  final bool active;
  final VoidCallback onTap;
  const _FeedbackIcon({required this.icon, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: active ? const Color(0xFFFFF0A6) : _bg,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 13, color: active ? _accent : _inkSub),
      ),
    );
  }
}
