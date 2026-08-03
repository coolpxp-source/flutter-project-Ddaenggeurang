import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../utils/app_colors.dart';
import '../../utils/formatters.dart'; // ← 추가
import '../../models/card_point_model.dart';
import '../../services/card_point_service.dart';
import 'card_point_add_screen.dart';
import 'card_point_detail_screen.dart';

class CardPointListScreen extends StatelessWidget {
  const CardPointListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    final service = CardPointService();

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text('내 카드 포인트',
            style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.ink)),
        centerTitle: true,
      ),
      floatingActionButton: userId == null
          ? null
          : FloatingActionButton(
        backgroundColor: AppColors.ink,
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CardPointAddScreen()),
        ),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: userId == null
          ? const Center(child: Text('로그인이 필요해요', style: TextStyle(color: AppColors.inkSub)))
          : StreamBuilder<List<CardPointModel>>(
        stream: service.getCardPoints(userId: userId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppColors.expense));
          }
          final cards = snapshot.data ?? [];
          if (cards.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('등록된 카드가 없어요', style: TextStyle(color: AppColors.inkSub)),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const CardPointAddScreen()),
                    ),
                    icon: const Icon(Icons.add),
                    label: const Text('카드 추가하기'),
                  ),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: cards.length,
            itemBuilder: (context, index) => _CardPointCard(card: cards[index]),
          );
        },
      ),
    );
  }
}

class _CardPointCard extends StatelessWidget {
  final CardPointModel card;
  const _CardPointCard({required this.card});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => CardPointDetailScreen(card: card)),
      ),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: AppColors.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(card.companyName,
                          style: const TextStyle(fontSize: 12.5, color: AppColors.inkSub)),
                      const SizedBox(height: 3),
                      Text(card.cardName,
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.ink)),
                    ],
                  ),
                ),
                if (card.expiringPoint > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFE5E5),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('${CurrencyFormatter.format(card.expiringPoint)}P 소멸예정', // ← 수정
                        style: const TextStyle(fontSize: 11, color: Colors.redAccent)),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Text('${CurrencyFormatter.format(card.totalPoint)}P', // ← 수정
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.ink)),
          ],
        ),
      ),
    );
  }
}