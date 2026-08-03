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
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(card.cardName, style: const TextStyle(color: AppColors.ink, fontWeight: FontWeight.w800)),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.ink,
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CardPointHistoryAddScreen(
              userId: card.userId,
              cardId: card.cardId,
            ),
          ),
        ),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: StreamBuilder<List<CardPointHistoryModel>>(
        stream: service.getCardPointHistory(userId: card.userId, cardId: card.cardId),
        builder: (context, snapshot) {
          final history = snapshot.data ?? [];
          if (history.isEmpty) {
            return const Center(child: Text('내역이 없어요', style: TextStyle(color: AppColors.inkSub)));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: history.length,
            itemBuilder: (context, i) {
              final h = history[i];
              final isEarn = h.type == 'earn';
              return ListTile(
                title: Text(h.merchant),
                subtitle: Text('${h.date.month}/${h.date.day}'),
                trailing: Text(
                  '${isEarn ? '+' : ''}${CurrencyFormatter.format(h.point)}P',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: isEarn ? AppColors.income : Colors.redAccent,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}