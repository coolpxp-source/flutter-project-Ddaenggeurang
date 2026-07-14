import 'package:flutter/material.dart';

import '../../models/subscription_model.dart';
import '../../services/subscription_service.dart';
import 'subscription_add_screen.dart';
import 'subscription_edit_screen.dart';

class SubscriptionListScreen extends StatelessWidget {
  final String userId;

  const SubscriptionListScreen({
    super.key,
    required this.userId,
  });

  @override
  Widget build(BuildContext context) {
    final SubscriptionService subscriptionService =
    SubscriptionService();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),

      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: const Text(
          '구독 관리',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),

      body: StreamBuilder<List<SubscriptionModel>>(
        stream: subscriptionService.getSubscriptions(userId),
        builder: (context, snapshot) {
          // Firestore 구독 목록 조회 중
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          // Firestore 조회 실패
          if (snapshot.hasError) {
            return _SubscriptionErrorView(
              message: '${snapshot.error}',
            );
          }

          final List<SubscriptionModel> subscriptions =
              snapshot.data ?? [];

          // 활성 구독료 합계
          final int activeTotalAmount = subscriptions
              .where((subscription) => subscription.isActive)
              .fold<int>(
            0,
                (sum, subscription) => sum + subscription.amount,
          );

          // 활성 구독 개수
          final int activeCount = subscriptions
              .where((subscription) => subscription.isActive)
              .length;

          // 등록된 구독이 없는 경우
          if (subscriptions.isEmpty) {
            return _EmptySubscriptionView(
              onAddPressed: () {
                _openAddScreen(context);
              },
            );
          }

          return Column(
            children: [
              // 상단 월 구독료 요약 카드
              _SubscriptionSummaryCard(
                totalAmount: activeTotalAmount,
                activeCount: activeCount,
              ),

              // 구독 목록
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(
                    20,
                    0,
                    20,
                    110,
                  ),
                  itemCount: subscriptions.length,
                  separatorBuilder: (context, index) {
                    return const SizedBox(height: 12);
                  },
                  itemBuilder: (context, index) {
                    final SubscriptionModel subscription =
                    subscriptions[index];

                    return _SubscriptionCard(
                      subscription: subscription,

                      // 연필 아이콘을 누르면 수정 화면 이동
                      onEdit: () {
                        _openEditScreen(
                          context,
                          subscription,
                        );
                      },

                      // 휴지통 아이콘을 누르면 삭제 확인
                      onDelete: () {
                        _confirmDelete(
                          context: context,
                          subscriptionService:
                          subscriptionService,
                          subscription: subscription,
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),

      // 구독 추가 화면 이동 버튼
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          _openAddScreen(context);
        },
        icon: const Icon(Icons.add),
        label: const Text(
          '구독 추가',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  /// 구독 추가 화면으로 이동
  void _openAddScreen(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SubscriptionAddScreen(
          userId: userId,
        ),
      ),
    );
  }

  /// 구독 수정 화면으로 이동
  void _openEditScreen(
      BuildContext context,
      SubscriptionModel subscription,
      ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SubscriptionEditScreen(
          userId: userId,
          subscription: subscription,
        ),
      ),
    );
  }

  /// 구독 삭제 확인창
  Future<void> _confirmDelete({
    required BuildContext context,
    required SubscriptionService subscriptionService,
    required SubscriptionModel subscription,
  }) async {
    final bool? shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            '구독 삭제',
            style: TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            '${subscription.name} 구독을 삭제하시겠습니까?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('취소'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: const Text('삭제'),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true) {
      return;
    }

    try {
      await subscriptionService.deleteSubscription(
        userId: userId,
        subscriptionId: subscription.id,
      );

      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('구독이 삭제되었습니다.'),
        ),
      );
    } catch (e) {
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '구독 삭제 중 오류가 발생했습니다.\n$e',
          ),
        ),
      );
    }
  }

  /// 천 단위 쉼표 적용
  static String formatAmount(int amount) {
    return amount.toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
          (match) => '${match[1]},',
    );
  }
}

/// 상단 월 구독료 요약 카드
class _SubscriptionSummaryCard extends StatelessWidget {
  final int totalAmount;
  final int activeCount;

  const _SubscriptionSummaryCard({
    required this.totalAmount,
    required this.activeCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(
        20,
        20,
        20,
        16,
      ),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F6FF),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFD9E5FF),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '이번 달 총 구독료',
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF667085),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${SubscriptionListScreen.formatAmount(totalAmount)}원',
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2F6BFF),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '활성 구독 $activeCount개',
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF667085),
            ),
          ),
        ],
      ),
    );
  }
}

/// 개별 구독 카드
class _SubscriptionCard extends StatelessWidget {
  final SubscriptionModel subscription;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _SubscriptionCard({
    required this.subscription,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.white,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(
          color: Color(0xFFE4E7EC),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          16,
          14,
          8,
          14,
        ),
        child: Row(
          children: [
            // 구독 아이콘
            CircleAvatar(
              radius: 22,
              backgroundColor: subscription.isActive
                  ? const Color(0xFFF2F6FF)
                  : const Color(0xFFF2F4F7),
              child: Icon(
                Icons.subscriptions_outlined,
                color: subscription.isActive
                    ? const Color(0xFF2F6BFF)
                    : const Color(0xFF98A2B3),
              ),
            ),
            const SizedBox(width: 14),

            // 서비스명과 결제일
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          subscription.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: subscription.isActive
                                ? const Color(0xFF101828)
                                : const Color(0xFF98A2B3),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _SubscriptionStatusBadge(
                        isActive: subscription.isActive,
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '매월 ${subscription.paymentDay}일 결제',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF667085),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '${SubscriptionListScreen.formatAmount(subscription.amount)}원',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: subscription.isActive
                          ? const Color(0xFF101828)
                          : const Color(0xFF98A2B3),
                    ),
                  ),
                ],
              ),
            ),

            // 수정 버튼
            IconButton(
              tooltip: '수정',
              onPressed: onEdit,
              icon: const Icon(
                Icons.edit_outlined,
                color: Color(0xFF2F6BFF),
              ),
            ),

            // 삭제 버튼
            IconButton(
              tooltip: '삭제',
              onPressed: onDelete,
              icon: const Icon(
                Icons.delete_outline,
                color: Colors.red,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 구독 이용 상태 표시
class _SubscriptionStatusBadge extends StatelessWidget {
  final bool isActive;

  const _SubscriptionStatusBadge({
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: isActive
            ? const Color(0xFFECFDF3)
            : const Color(0xFFF2F4F7),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        isActive ? '이용 중' : '중지',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: isActive
              ? const Color(0xFF027A48)
              : const Color(0xFF667085),
        ),
      ),
    );
  }
}

/// 등록된 구독이 없을 때 표시
class _EmptySubscriptionView extends StatelessWidget {
  final VoidCallback onAddPressed;

  const _EmptySubscriptionView({
    required this.onAddPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircleAvatar(
              radius: 36,
              backgroundColor: Color(0xFFF2F6FF),
              child: Icon(
                Icons.subscriptions_outlined,
                size: 34,
                color: Color(0xFF2F6BFF),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              '등록된 구독이 없습니다.',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '매달 결제되는 구독 서비스를 등록해 보세요.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF667085),
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onAddPressed,
              icon: const Icon(Icons.add),
              label: const Text('구독 추가'),
            ),
          ],
        ),
      ),
    );
  }
}

/// 구독 목록 조회 오류 화면
class _SubscriptionErrorView extends StatelessWidget {
  final String message;

  const _SubscriptionErrorView({
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              size: 48,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            const Text(
              '구독 목록을 불러오지 못했습니다.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF667085),
              ),
            ),
          ],
        ),
      ),
    );
  }
}