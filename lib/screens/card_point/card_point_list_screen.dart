import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../utils/app_colors.dart';
import '../../utils/formatters.dart';
import '../../models/card_point_model.dart';
import '../../services/card_point_service.dart';
import '../../widgets/common/ddaeng_modal.dart';
import 'card_point_add_screen.dart';
import 'card_point_detail_screen.dart';

class CardPointListScreen extends StatelessWidget {
  const CardPointListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    final service = CardPointService();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text('내 카드 포인트',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.ink)),
        centerTitle: true,
      ),
      floatingActionButton: userId == null
          ? null
          : FloatingActionButton(
        backgroundColor: AppColors.ink,
        elevation: 0,
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
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: AppColors.bg,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: const Icon(Icons.credit_card_outlined, size: 28, color: AppColors.inkSub),
                  ),
                  const SizedBox(height: 16),
                  const Text('등록된 카드가 없어요',
                      style: TextStyle(color: AppColors.inkSub, fontSize: 13.5)),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const CardPointAddScreen()),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.ink,
                      side: const BorderSide(color: Color(0xFFE8ECF3), width: 1.4),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('카드 추가하기',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                  ),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
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

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await DdaengModal.confirm(
      context,
      title: '카드 삭제',
      message: '${card.cardName}을(를) 삭제할까요?\n포인트 내역도 함께 사라져요.',
      type: ModalType.danger,
      confirmText: '삭제',
    );

    if (confirmed) {
      await CardPointService().deleteCard(userId: card.userId, cardId: card.cardId);
      if (context.mounted) {
        await DdaengModal.alert(
          context,
          title: '삭제 완료',
          message: '카드를 삭제했어요.',
          type: ModalType.success,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => CardPointDetailScreen(card: card)),
      ),
      onLongPress: () => _confirmDelete(context),
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
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFE5E5),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('${CurrencyFormatter.format(card.expiringPoint)}P 소멸예정',
                        style: const TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w700, color: Colors.redAccent)),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text('${CurrencyFormatter.format(card.totalPoint)}P',
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.ink)),
          ],
        ),
      ),
    );
  }
}