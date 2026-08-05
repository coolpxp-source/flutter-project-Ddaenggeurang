import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../utils/formatters.dart';
import '../../models/card_point_model.dart';
import '../../services/card_point_service.dart';
import '../../widgets/common/ddaeng_modal.dart';
import 'card_point_add_screen.dart';
import 'card_point_detail_screen.dart';

const Color _mainColor = Color(0xFF6C63FF);
const Color _mainSoftColor = Color(0xFFEDECFF);

class CardPointListScreen extends StatelessWidget {
  const CardPointListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    final service = CardPointService();

    return Scaffold(
      backgroundColor: const Color(0xFFF8F7FA),
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        backgroundColor: const Color(0xFFF8F7FA),
        surfaceTintColor: Colors.transparent,
        foregroundColor: const Color(0xFF222222),
        title: const Text('내 카드 포인트', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
      ),
      floatingActionButton: userId == null
          ? null
          : FloatingActionButton(
        backgroundColor: _mainColor,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)),
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CardPointAddScreen()),
        ),
        child: const Icon(Icons.add_rounded),
      ),
      body: userId == null
          ? const Center(child: Text('로그인이 필요해요', style: TextStyle(color: Color(0xFF999999))))
          : StreamBuilder<List<CardPointModel>>(
        stream: service.getCardPoints(userId: userId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: _mainColor));
          }
          final cards = snapshot.data ?? [];
          final totalPoint = cards.fold<int>(0, (sum, c) => sum + c.totalPoint);
          final expiringTotal = cards.fold<int>(0, (sum, c) => sum + c.expiringPoint);

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 110),
            children: [
              _SummaryCard(totalPoint: totalPoint, cardCount: cards.length, expiringTotal: expiringTotal),
              const SizedBox(height: 14),
              _SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text('내 카드 목록',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF222222))),
                        ),
                        TextButton(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const CardPointAddScreen()),
                          ),
                          style: TextButton.styleFrom(foregroundColor: _mainColor),
                          child: const Text('추가', style: TextStyle(fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ),
                    if (cards.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 30),
                        child: Center(
                          child: Column(
                            children: [
                              Container(
                                width: 64,
                                height: 64,
                                decoration: const BoxDecoration(color: _mainSoftColor, shape: BoxShape.circle),
                                child: const Icon(Icons.credit_card_rounded, size: 30, color: _mainColor),
                              ),
                              const SizedBox(height: 12),
                              const Text('등록된 카드가 없습니다.',
                                  style: TextStyle(color: Color(0xFF555555), fontSize: 13)),
                              const SizedBox(height: 14),
                              SizedBox(
                                height: 46,
                                child: FilledButton.icon(
                                  onPressed: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => const CardPointAddScreen()),
                                  ),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: _mainColor,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                  ),
                                  icon: const Icon(Icons.add_rounded, size: 18),
                                  label: const Text('카드 추가', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      ...cards.map(
                            (card) => Padding(
                          padding: const EdgeInsets.only(top: 9),
                          child: _CardPointTile(card: card),
                        ),
                      ),
                    const _LongPressHint(),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final int totalPoint;
  final int cardCount;
  final int expiringTotal;

  const _SummaryCard({required this.totalPoint, required this.cardCount, required this.expiringTotal});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF6C63FF), Color(0xFF9B93FF)],
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('보유 포인트 합계', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text('${formatAmount(totalPoint)}P',
              style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800)),
          const SizedBox(height: 20),
          Row(
            children: [
              _SummaryItem(label: '등록 카드', value: '$cardCount개'),
              const SizedBox(width: 8),
              _SummaryItem(label: '소멸예정', value: '${formatAmount(expiringTotal)}P'),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final String label;
  final String value;
  const _SummaryItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.18), borderRadius: BorderRadius.circular(14)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10)),
            const SizedBox(height: 4),
            Text(value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }
}

class _CardPointTile extends StatelessWidget {
  final CardPointModel card;
  const _CardPointTile({required this.card});

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await DdaengModal.confirm(
      context,
      title: '카드 삭제',
      message: '${card.cardName}을(를) 삭제할까요?\n포인트 내역도 함께 사라져요.',
      type: ModalType.danger,
      confirmText: '삭제',
    );
    if (!confirmed) return;

    try {
      await CardPointService().deleteCard(userId: card.userId, cardId: card.cardId);
      if (context.mounted) {
        await DdaengModal.alert(
          context,
          title: '삭제 완료',
          message: '카드를 삭제했어요.',
          type: ModalType.success,
        );
      }
    } catch (e) {
      if (context.mounted) {
        await DdaengModal.alert(
          context,
          title: '삭제할 수 없어요',
          message: e.toString().replaceFirst('Exception: ', ''),
          type: ModalType.danger,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF7F8FB),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => CardPointDetailScreen(card: card)),
        ),
        onLongPress: () => _confirmDelete(context),
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(color: _mainSoftColor, borderRadius: BorderRadius.circular(13)),
                child: const Icon(Icons.credit_card_rounded, color: _mainColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(card.cardName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Color(0xFF25272C), fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(card.companyName, style: const TextStyle(color: Color(0xFF9A9DA5), fontSize: 10)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('${formatAmount(card.totalPoint)}P', style: const TextStyle(fontWeight: FontWeight.bold)),
                  if (card.expiringPoint > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: const Color(0xFFFFE5E5), borderRadius: BorderRadius.circular(20)),
                        child: Text('${formatAmount(card.expiringPoint)}P 소멸예정',
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.redAccent)),
                      ),
                    ),
                ],
              ),
              const Icon(Icons.chevron_right_rounded, size: 20, color: Color(0xFFAAAAAA)),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final Widget child;
  const _SectionCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF0EDF0)),
        boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 14, offset: Offset(0, 5))],
      ),
      child: child,
    );
  }
}

class _LongPressHint extends StatelessWidget {
  const _LongPressHint();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F2FF),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, size: 14, color: Color(0xFF8B85FF)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              '카드를 꾹 눌러서 삭제할 수 있어요',
              style: TextStyle(fontSize: 11, color: Colors.grey[600], fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

String formatAmount(int amount) {
  return amount.toString().replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
        (match) => '${match[1]},',
  );
}