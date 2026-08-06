import 'package:flutter/material.dart';
import '../../utils/formatters.dart';
import '../../models/card_point_model.dart';
import '../../models/card_point_history_model.dart';
import '../../services/card_point_service.dart';
import 'card_point_history_add_screen.dart';

const Color _mainColor = Color(0xFF6C63FF);
const Color _mainSoftColor = Color(0xFFEDECFF);
const Color _mainBorderSoftColor = Color(0xFFDAD7FF);

class CardPointDetailScreen extends StatelessWidget {
  final CardPointModel card;
  const CardPointDetailScreen({super.key, required this.card});

  @override
  Widget build(BuildContext context) {
    final service = CardPointService();
    return Scaffold(
      backgroundColor: const Color(0xFFF8F7FA),
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        backgroundColor: const Color(0xFFF8F7FA),
        surfaceTintColor: Colors.transparent,
        foregroundColor: const Color(0xFF222222),
        title: Text(card.cardName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: _mainColor,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)),
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CardPointHistoryAddScreen(userId: card.userId, cardId: card.cardId),
          ),
        ),
        child: const Icon(Icons.add_rounded),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 110),
        children: [
          Container(
            width: double.infinity,
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
                Text(card.companyName,
                    style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Text('${formatAmount(card.totalPoint)}P',
                    style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800)),
                if (card.expiringPoint > 0) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text('${formatAmount(card.expiringPoint)}P 소멸예정',
                        style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w700)),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
          _SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.receipt_long_rounded, color: _mainColor, size: 18),
                    SizedBox(width: 8),
                    Text('포인트 내역',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF222222))),
                  ],
                ),
                const SizedBox(height: 14),
                StreamBuilder<List<CardPointHistoryModel>>(
                  stream: service.getCardPointHistory(userId: card.userId, cardId: card.cardId),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 30),
                        child: Center(child: CircularProgressIndicator(color: _mainColor)),
                      );
                    }
                    final history = snapshot.data ?? [];
                    if (history.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 30),
                        child: Center(
                          child: Column(
                            children: [
                              Container(
                                width: 64,
                                height: 64,
                                decoration: const BoxDecoration(color: _mainSoftColor, shape: BoxShape.circle),
                                child: const Icon(Icons.receipt_long_rounded, size: 28, color: _mainColor),
                              ),
                              const SizedBox(height: 12),
                              const Text('내역이 없어요', style: TextStyle(color: Color(0xFF555555), fontSize: 13)),
                            ],
                          ),
                        ),
                      );
                    }
                    return Column(
                      children: history.map((h) => _HistoryTile(card: card, history: h)).toList(),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  final CardPointModel card;
  final CardPointHistoryModel history;
  const _HistoryTile({required this.card, required this.history});

  @override
  Widget build(BuildContext context) {
    final isEarn = history.type == 'earn';
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Material(
        color: const Color(0xFFF7F8FB),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CardPointHistoryAddScreen(
                userId: card.userId,
                cardId: card.cardId,
                existing: history,
              ),
            ),
          ),
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: isEarn ? _mainSoftColor : const Color(0xFFFFE5E5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    isEarn ? Icons.add_rounded : Icons.remove_rounded,
                    size: 18,
                    color: isEarn ? _mainColor : Colors.redAccent,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(history.merchant,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: Color(0xFF25272C))),
                      const SizedBox(height: 3),
                      Text('${history.date.month}/${history.date.day}',
                          style: const TextStyle(fontSize: 11.5, color: Color(0xFF9A9DA5))),
                    ],
                  ),
                ),
                Text(
                  '${isEarn ? '+' : '-'}${formatAmount(history.point)}P',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: isEarn ? _mainColor : Colors.redAccent,
                  ),
                ),
                const SizedBox(width: 3),
                const Icon(Icons.chevron_right_rounded, size: 18, color: Color(0xFFAAAAAA)),
              ],
            ),
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

String formatAmount(int amount) {
  return amount.toString().replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
        (match) => '${match[1]},',
  );
}