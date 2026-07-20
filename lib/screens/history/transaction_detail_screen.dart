import 'package:flutter/material.dart';
import '../../models/transaction_item.dart';
import '../../utils/formatters.dart';
import '../../services/transaction_service.dart';

class TransactionDetailScreen extends StatelessWidget {
  final TransactionItem item;

  const TransactionDetailScreen({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    // 타입별 분기 처리
    final isExpense = item.type == 'expense';
    final isSaving = item.type == 'saving';

    // 금액 기호 및 색상 세팅
    final String sign = isExpense ? '-' : (isSaving ? '' : '+');
    final String amountText = '$sign${CurrencyFormatter.format(item.amount)}원';
    final Color amountColor = isExpense ? Colors.black87 : (isSaving ? Colors.teal[600]! : Colors.blueAccent);

    // 상단 타이틀 세팅
    final String screenTitle = isExpense ? '지출 상세' : (isSaving ? '저축 상세' : '수입 상세');

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          screenTitle,
          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.grey),
            onPressed: () async {
              // 1. 내역 추가(수정) 화면으로 이동하면서 현재 item 데이터를 넘겨줍니다.
              // final isUpdated = await Navigator.push(
              //   context,
              //   MaterialPageRoute(
              //     builder: (context) => AddTransactionScreen(editItem: item),
              //   ),
              // );
              //
              // // 2. 수정을 성공하고 돌아왔을 때 (isUpdated == true)
              // if (isUpdated == true && context.mounted) {
              //   // 이전 메인 화면(리스트)도 새로고침 되도록 상세 화면을 닫아줍니다.
              //   Navigator.pop(context, true);
              // }
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
            onPressed: () {
              _showDeleteDialog(context);
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. 카테고리명 & 금액 영역
            Center(
              child: Column(
                children: [
                  Text(
                    item.title,
                    style: TextStyle(color: Colors.grey[600], fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    amountText,
                    style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: amountColor),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
            const Divider(color: Color(0xFFEEEEEE), thickness: 1),
            const SizedBox(height: 24),

            // 2. 공통 정보 영역 (날짜, 메모)
            _buildInfoRow('일시', DateFormatter.formatDayAndWeekday(item.date)),

            // 메모가 있을 때만 렌더링
            if (item.subtitle != null && item.subtitle!.isNotEmpty) ...[
              const SizedBox(height: 24),
              _buildInfoRow('메모', item.subtitle!),
            ],

            // 3. 타입별 특수 정보 영역 (감정 태그, 계좌명)
            if (isExpense && item.emotionTag != null) ...[
              const SizedBox(height: 24),
              _buildInfoRow('감정 태그', _translateEmotion(item.emotionTag!)), // 영어 태그를 한글로 변환
            ],

            if (isSaving && item.accountName != null) ...[
              const SizedBox(height: 24),
              _buildInfoRow('저축 계좌', item.accountName!),
            ],
          ],
        ),
      ),
    );
  }

  // 텍스트를 좌우로 정렬해주는 UI 위젯
  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: const TextStyle(color: Colors.grey, fontSize: 15, fontWeight: FontWeight.w500),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(color: Colors.black87, fontSize: 15, fontWeight: FontWeight.w600),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }

  // 감정 태그 변환기 (필요에 따라 수정하세요)
  String _translateEmotion(String tag) {
    switch (tag) {
      case 'stress': return '😡 홧김에 썼어요';
      case 'impulsive': return '🥺 충동적이었어요';
      case 'happy': return '🥰 행복한 소비예요';
      default: return tag;
    }
  }
  // 삭제 확인 다이얼로그 띄우기
  void _showDeleteDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('내역 삭제', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('정말 이 내역을 삭제하시겠습니까?'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx), // 취소 시 다이얼로그만 닫기
            child: const Text('취소', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx); // 1. 먼저 다이얼로그를 닫고

              // 2. 파이어베이스 삭제(업데이트) 함수 실행
              await TransactionService().deleteTransaction(item.type, item.id);

              if (context.mounted) {
                // 3. 삭제가 완료되면 상세 화면도 닫고(pop) 메인 화면으로 돌아가기
                Navigator.pop(context);
              }
            },
            child: const Text('삭제', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}