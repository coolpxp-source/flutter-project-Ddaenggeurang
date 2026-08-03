import 'package:flutter/material.dart';
import '../../utils/app_colors.dart';
import '../../utils/formatters.dart';
import '../../models/card_point_model.dart';
import '../../models/card_point_history_model.dart';
import '../../services/card_point_service.dart';
import 'card_point_history_add_screen.dart';

class CardPointDetailScreen extends StatelessWidget {
  final CardPointModel card;
  const CardPointDetailScreen({super.key, required this.card});

  @override
  Widget build(BuildContext context) {
    final service = CardPointService();
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text(card.cardName,
            style: const TextStyle(color: AppColors.ink, fontWeight: FontWeight.w800, fontSize: 16)),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.ink,
        elevation: 0,
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CardPointHistoryAddScreen(userId: card.userId, cardId: card.cardId),
          ),
        ),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(20, 8, 20, 4),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.bg,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(card.companyName, style: const TextStyle(fontSize: 12.5, color: AppColors.inkSub)),
                const SizedBox(height: 6),
                Text('${CurrencyFormatter.format(card.totalPoint)}P',
                    style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.ink)),
                if (card.expiringPoint > 0) ...[
                  const SizedBox(height: 6),
                  Text('${CurrencyFormatter.format(card.expiringPoint)}P 소멸예정',
                      style: const TextStyle(fontSize: 12, color: Colors.redAccent, fontWeight: FontWeight.w600)),
                ],
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<List<CardPointHistoryModel>>(
              stream: service.getCardPointHistory(userId: card.userId, cardId: card.cardId),
              builder: (context, snapshot) {
                final history = snapshot.data ?? [];
                if (history.isEmpty) {
                  return const Center(
                    child: Text('내역이 없어요', style: TextStyle(color: AppColors.inkSub, fontSize: 13.5)),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
                  itemCount: history.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF0F0F0)),
                  itemBuilder: (context, i) {
                    final h = history[i];
                    final isEarn = h.type == 'earn';
                    return InkWell(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CardPointHistoryAddScreen(
                            userId: card.userId,
                            cardId: card.cardId,
                            existing: h,
                          ),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: isEarn ? AppColors.incomeSoft : const Color(0xFFFFE5E5),
                                shape: BoxShape.circle,
                              ),
                              alignment: Alignment.center,
                              child: Icon(
                                isEarn ? Icons.add : Icons.remove,
                                size: 18,
                                color: isEarn ? AppColors.income : Colors.redAccent,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(h.merchant,
                                      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.ink)),
                                  const SizedBox(height: 2),
                                  Text('${h.date.month}/${h.date.day}',
                                      style: const TextStyle(fontSize: 11.5, color: AppColors.inkSub)),
                                ],
                              ),
                            ),
                            Text(
                              '${isEarn ? '+' : '-'}${CurrencyFormatter.format(h.point)}P',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: isEarn ? AppColors.income : Colors.redAccent,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}