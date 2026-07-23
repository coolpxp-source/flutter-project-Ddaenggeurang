import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/transaction_item.dart';
import '../../utils/formatters.dart';
import '../../services/transaction_service.dart';
import '../expense/expense_input_screen.dart';
import '../income/income_input_screen.dart';
import '../saving/saving_input_screen.dart';
import '../../utils/app_colors.dart';

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
    final Color amountColor = isExpense ? AppColors.ink : (isSaving ? AppColors.saving : AppColors.utility);

    // 상단 타이틀 세팅
    final String screenTitle = isExpense ? '지출 상세' : (isSaving ? '저축 상세' : '수입 상세');

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.ink,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppColors.ink, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          screenTitle,
          style: const TextStyle(color: AppColors.ink, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit, color: AppColors.inkSub),
            onPressed: () async {
              Widget? targetScreen;

              // 1. item.type에 따라 어떤 화면으로 갈지 결정합니다.
              if (item.type == 'expense') {
                targetScreen = ExpenseInputScreen(editItem: item);
              } else if (item.type == 'income') {
                targetScreen = IncomeInputScreen(editItem: item);
              } else if (item.type == 'saving') {
                _showSavingStatusDialog(context, item);
                return;
              }

              // 아직 연결 안 된 화면(수입/저축)을 눌렀을 때 방어 코드
              if (targetScreen == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('해당 내역은 아직 수정 기능을 지원하지 않습니다.')),
                );
                return;
              }

              // 2. 수정 화면으로 이동!
              final isUpdated = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => targetScreen!,
                ),
              );

              // 3. 여기가 핵심! 수정을 성공하고 돌아왔을 때 (isUpdated == true)
              if (isUpdated == true && context.mounted) {
                // 이전 메인 화면(리스트)도 새로고침 되도록 상세 화면을 바로 닫아버립니다!
                Navigator.pop(context, true);
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: AppColors.danger),
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
                    style: const TextStyle(color: AppColors.inkSub, fontSize: 16),
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
            const Divider(color: AppColors.divider, thickness: 1),
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
            style: const TextStyle(color: AppColors.inkSub, fontSize: 15, fontWeight: FontWeight.w500),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(color: AppColors.ink, fontSize: 15, fontWeight: FontWeight.w600),
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

  // 저축 상태 변경 다이얼로그
  void _showSavingStatusDialog(BuildContext context, TransactionItem item) {
    String selectedStatus = 'active'; // 기본값: 진행중
    final TextEditingController amountController = TextEditingController();
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (ctx) {
        // StatefulBuilder를 써야 다이얼로그 안에서 체크박스나 화면이 실시간으로 바뀝니다.
        return StatefulBuilder(
            builder: (context, setState) {
              return AlertDialog(
                title: const Text('저축/투자 상태 변경', style: TextStyle(fontWeight: FontWeight.bold)),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('현재 상태를 선택해주세요.'),
                    const SizedBox(height: 16),

                    // 상태 선택 드롭다운
                    InputDecorator(
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: selectedStatus,
                          isExpanded: true, // 글씨가 잘리지 않게 꽉 채워줍니다
                          items: const [
                            DropdownMenuItem(value: 'active', child: Text('진행중')),
                            DropdownMenuItem(value: 'matured', child: Text('만기됨')),
                            DropdownMenuItem(value: 'cancelled', child: Text('해지함')),
                            DropdownMenuItem(value: 'sold', child: Text('매도완료')),
                          ],
                          onChanged: (value) {
                            setState(() {
                              selectedStatus = value!;
                            });
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // '진행중'이 아닐 때만 최종 수령 금액 입력칸 보여주기
                    if (selectedStatus != 'active') ...[
                      const Text('최종 수령 금액 (원금+손익)', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: amountController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [CurrencyFormatter()], // 콤마 포맷터 적용
                        decoration: const InputDecoration(
                          prefixText: '₩ ',
                          border: OutlineInputBorder(),
                          hintText: '돌려받은 금액을 입력하세요',
                        ),
                      ),
                    ],
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('취소', style: TextStyle(color: AppColors.inkSub)),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.saving),
                    onPressed: isSaving ? null : () async {
                      // 최종 금액 파싱
                      int? returnedAmount;
                      if (selectedStatus != 'active') {
                        final amountText = amountController.text.replaceAll(',', '').trim();
                        returnedAmount = int.tryParse(amountText);

                        if (returnedAmount == null || returnedAmount < 0) {
                          ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('올바른 최종 금액을 입력해주세요.')));
                          return;
                        }
                      }

                      setState(() => isSaving = true);

                      try {
                        // 1. 기존 저축 내역 업데이트 (상태 변경 및 최종금액 기록)
                        await FirebaseFirestore.instance.collection('savings').doc(item.id).update({
                          'status': selectedStatus,
                          'returnedAmount': returnedAmount,
                          'updatedAt': FieldValue.serverTimestamp(),
                        });

                        // 2. 만기/해지/매도 시 오늘 날짜로 "수입(기타수입)" 신규 내역 자동 생성!
                        if (selectedStatus != 'active' && returnedAmount != null && returnedAmount > 0) {
                          String memoText = '';
                          if (selectedStatus == 'matured') memoText = '${item.title} 만기 환급금';
                          else if (selectedStatus == 'cancelled') memoText = '${item.title} 해지 환급금';
                          else if (selectedStatus == 'sold') memoText = '${item.title} 매도 금액';

                          await FirebaseFirestore.instance.collection('incomes').add({
                            'userId': FirebaseAuth.instance.currentUser?.uid ?? '',
                            'amount': returnedAmount,
                            'incomeSource': 'etc', // 수입의 '기타 수입'으로 자동 분류
                            'date': Timestamp.now(), // 👈 현재(오늘) 시간으로 기록!
                            'memo': memoText,
                            'isDeleted': false,
                            'createdAt': FieldValue.serverTimestamp(),
                          });
                        }

                        if (ctx.mounted) {
                          Navigator.pop(ctx); // 팝업 닫기
                          Navigator.pop(context, true); // 상세화면 닫고 메인으로!
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('상태 변경 및 환급금 기록이 완료되었습니다!')));
                        }
                      } catch (e) {
                        debugPrint('상태 업데이트 오류: $e');
                        setState(() => isSaving = false);
                      }
                    },
                    child: isSaving
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('저장', style: TextStyle(color: Colors.white)),
                  ),
                ],
              );
            }
        );
      },
    );
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
            child: const Text('취소', style: TextStyle(color: AppColors.inkSub)),
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
            child: const Text('삭제', style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}