import 'package:flutter/material.dart';

import '../../models/subscription_model.dart';
import '../../services/subscription_service.dart';
import 'subscription_add_screen.dart';
import 'subscription_edit_screen.dart';

class SubscriptionListScreen extends StatelessWidget {
  // 현재 로그인한 사용자 UID
  final String userId;

  const SubscriptionListScreen({
    super.key,
    required this.userId,
  });

  @override
  Widget build(BuildContext context) {
    // Firestore 구독 조회·수정·삭제 기능을 담당하는 서비스
    final SubscriptionService subscriptionService =
    SubscriptionService();

    return Scaffold(
      // 상단 앱바
      appBar: AppBar(
        title: const Text(
          '구독 관리',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),

      // Firestore의 구독 데이터를 실시간으로 조회
      body: StreamBuilder<List<SubscriptionModel>>(
        stream: subscriptionService.getSubscriptions(userId),
        builder: (context, snapshot) {
          // Firestore 데이터를 처음 불러오는 중
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          // Firestore 조회 중 오류가 발생한 경우
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  '구독 목록을 불러오지 못했습니다.\n${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          // Firestore에서 받아온 구독 목록
          final List<SubscriptionModel> subscriptions =
              snapshot.data ?? [];

          // 등록된 구독이 하나도 없을 때
          if (subscriptions.isEmpty) {
            return const Center(
              child: Text(
                '등록된 구독이 없습니다.',
                style: TextStyle(
                  fontSize: 16,
                  color: Color(0xFF667085),
                ),
              ),
            );
          }

          // 사용 중인 구독만 합산하여 총 구독료 계산
          final int totalAmount = subscriptions
              .where((item) => item.isActive)
              .fold(
            0,
                (sum, item) => sum + item.amount,
          );

          return Column(
            children: [
              // 이번 달 총 구독료 카드
              Container(
                width: double.infinity,
                margin: const EdgeInsets.all(20),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFFF2F6FF),
                  borderRadius: BorderRadius.circular(16),
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
                      '${_formatAmount(totalAmount)}원',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2F6BFF),
                      ),
                    ),
                  ],
                ),
              ),

              // 구독 목록
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(
                    20,
                    0,
                    20,
                    100,
                  ),
                  itemCount: subscriptions.length,
                  separatorBuilder: (_, __) {
                    return const SizedBox(height: 12);
                  },
                  itemBuilder: (context, index) {
                    // 현재 순서의 구독 데이터
                    final SubscriptionModel item =
                    subscriptions[index];

                    return Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: const BorderSide(
                          color: Color(0xFFE4E7EC),
                        ),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.fromLTRB(
                          16,
                          10,
                          4,
                          10,
                        ),

                        // 왼쪽 구독 아이콘
                        leading: CircleAvatar(
                          backgroundColor: item.isActive
                              ? const Color(0xFFF2F6FF)
                              : const Color(0xFFF2F4F7),
                          child: Icon(
                            Icons.subscriptions_outlined,
                            color: item.isActive
                                ? const Color(0xFF2F6BFF)
                                : const Color(0xFF98A2B3),
                          ),
                        ),

                        // 구독 서비스명
                        title: Text(
                          item.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: item.isActive
                                ? const Color(0xFF101828)
                                : const Color(0xFF98A2B3),
                          ),
                        ),

                        // 결제일과 구독 상태
                        subtitle: Text(
                          item.isActive
                              ? '매월 ${item.paymentDay}일 결제'
                              : '구독 중지 · 매월 ${item.paymentDay}일',
                          style: TextStyle(
                            color: item.isActive
                                ? const Color(0xFF667085)
                                : const Color(0xFF98A2B3),
                          ),
                        ),

                        // 오른쪽 금액 + 수정 + 삭제 버튼
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // 월 구독 금액
                            Text(
                              '${_formatAmount(item.amount)}원',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: item.isActive
                                    ? const Color(0xFF101828)
                                    : const Color(0xFF98A2B3),
                              ),
                            ),

                            // 수정 버튼
                            IconButton(
                              tooltip: '구독 수정',
                              visualDensity: VisualDensity.compact,
                              icon: const Icon(
                                Icons.edit_outlined,
                                color: Color(0xFF2F6BFF),
                              ),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        SubscriptionEditScreen(
                                          userId: userId,
                                          subscription: item,
                                        ),
                                  ),
                                );
                              },
                            ),

                            // 삭제 버튼
                            IconButton(
                              tooltip: '구독 삭제',
                              visualDensity: VisualDensity.compact,
                              icon: const Icon(
                                Icons.delete_outline,
                                color: Colors.red,
                              ),
                              onPressed: () async {
                                await _deleteSubscription(
                                  context: context,
                                  subscriptionService:
                                  subscriptionService,
                                  item: item,
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),

      // 구독 추가 화면으로 이동하는 버튼
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SubscriptionAddScreen(
                userId: userId,
              ),
            ),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('구독 추가'),
      ),
    );
  }

  /// 구독 삭제 확인창을 표시하고 Firestore 문서를 삭제하는 함수
  Future<void> _deleteSubscription({
    required BuildContext context,
    required SubscriptionService subscriptionService,
    required SubscriptionModel item,
  }) async {
    // 삭제 여부를 사용자에게 확인
    final bool? result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('구독 삭제'),
          content: Text(
            '${item.name} 구독을 삭제하시겠습니까?',
          ),
          actions: [
            // 삭제 취소
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('취소'),
            ),

            // 삭제 진행
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              child: const Text('삭제'),
            ),
          ],
        );
      },
    );

    // 취소했거나 팝업 바깥을 눌렀으면 종료
    if (result != true) {
      return;
    }

    try {
      // Firestore에서 선택한 구독 문서 삭제
      await subscriptionService.deleteSubscription(
        userId: userId,
        subscriptionId: item.id,
      );

      if (!context.mounted) {
        return;
      }

      // 삭제 성공 메시지
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('구독이 삭제되었습니다.'),
        ),
      );
    } catch (e) {
      if (!context.mounted) {
        return;
      }

      // 삭제 실패 메시지
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '삭제 중 오류가 발생했습니다.\n$e',
          ),
        ),
      );
    }
  }

  /// 숫자에 천 단위 쉼표를 추가
  ///
  /// 17000 → 17,000
  /// 1000000 → 1,000,000
  static String _formatAmount(int amount) {
    return amount.toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
          (match) => '${match[1]},',
    );
  }
}