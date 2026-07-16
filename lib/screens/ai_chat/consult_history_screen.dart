import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/consultation_model.dart';
import '../../services/ai_service.dart' as ai;
import '../../services/consultation_service.dart';
import '../../widgets/common/ddaeng_modal.dart';

const _accent = Color(0xFFF5A623);
const _ink = Color(0xFF221A16);
const _inkSub = Color(0xFF8A7E77);
const _bg = Color(0xFFFAF8F6);
const _line = Color(0xFFF0E9E4);
const _errorColor = Color(0xFFF04438);

/// 41_상담이력 — 지금까지 받은 "살까말까" AI 상담 결과를 모아 보여준다.
class ConsultHistoryScreen extends StatelessWidget {
  const ConsultHistoryScreen({super.key});

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
                return ListView.separated(
                  padding: const EdgeInsets.all(20),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, i) =>
                      _ConsultationCard(uid: uid, entry: items[i]),
                );
              },
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
        border: Border.all(color: _line),
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
        ],
      ),
    );
  }
}
