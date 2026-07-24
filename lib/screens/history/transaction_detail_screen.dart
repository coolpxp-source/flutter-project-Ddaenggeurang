import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/transaction_item.dart';
import '../../utils/formatters.dart';
import '../../services/transaction_service.dart';
import '../../widgets/common/ddaeng_modal.dart';
import '../expense/expense_input_screen.dart';
import '../income/income_input_screen.dart';
import '../saving/saving_input_screen.dart';
import '../../utils/app_colors.dart';

class TransactionDetailScreen extends StatelessWidget {
  final TransactionItem item;

  const TransactionDetailScreen({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final isExpense = item.type == 'expense';
    final isSaving = item.type == 'saving';
    final isIncome = item.type == 'income';

    final String sign = isExpense ? '-' : (isSaving ? '' : '+');
    final String amountText = '$sign${CurrencyFormatter.format(item.amount)}원';
    final Color typeColor = AppColors.forType(item.type);
    final String screenTitle = isExpense ? '지출 상세' : (isSaving ? '저축 상세' : '수입 상세');

    // 완료(만기/해지/매도)된 저축인지 여부 — 히어로 카드 톤을 죽여서 표시
    final bool isCompletedSaving =
        isSaving && item.savingStatus != null && item.savingStatus != 'active';

    final List<Color> heroGradient = isCompletedSaving
        ? [Colors.grey.shade400, Colors.grey.shade500]
        : isExpense
        ? const [Color(0xFFFFC168), Color(0xFFFF7A45), Color(0xFFFF5C7A)]
        : isSaving
        ? const [Color(0xFF2DD4BF), Color(0xFF0D9488)]
        : const [Color(0xFF34D399), Color(0xFF10B981)];

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
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

              if (item.type == 'expense') {
                targetScreen = ExpenseInputScreen(editItem: item);
              } else if (item.type == 'income') {
                targetScreen = IncomeInputScreen(editItem: item);
              } else if (item.type == 'saving') {
                _showSavingStatusModal(context, item);
                return;
              }

              if (targetScreen == null) {
                await DdaengModal.alert(
                  context,
                  title: '아직 지원하지 않아요',
                  message: '해당 내역은 아직 수정 기능을 지원하지 않습니다.',
                  type: ModalType.info,
                );
                return;
              }

              final isUpdated = await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => targetScreen!),
              );

              if (isUpdated == true && context.mounted) {
                Navigator.pop(context, true);
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: AppColors.danger),
            onPressed: () => _showDeleteModal(context),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── 금액 히어로 카드 ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: heroGradient,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: typeColor.withValues(alpha: 0.3),
                    blurRadius: 24,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.22),
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          isExpense
                              ? Icons.storefront
                              : (isSaving ? Icons.savings : Icons.account_balance_wallet),
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    item.title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    amountText,
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                  if (isCompletedSaving) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _savingStatusLabel(item.savingStatus!),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── 기본 정보 카드 ──
            _sectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionLabel('기본 정보',
                      icon: Icons.event_rounded, iconColor: typeColor, iconBg: typeColor.withValues(alpha: 0.15)),
                  const SizedBox(height: 14),
                  _buildInfoRow('일시', DateFormatter.formatDayAndWeekday(item.date)),
                  if (item.subtitle != null && item.subtitle!.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    _buildInfoRow('메모', item.subtitle!),
                  ],
                ],
              ),
            ),

            // ── 지출 전용: 감정 태그 ──
            if (isExpense && item.emotionTag != null) ...[
              const SizedBox(height: 16),
              _sectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionLabel('감정 태그',
                        icon: Icons.favorite_rounded, iconColor: AppColors.pink, iconBg: AppColors.pinkSoft),
                    const SizedBox(height: 14),
                    _buildInfoRow('태그', _translateEmotion(item.emotionTag!)),
                  ],
                ),
              ),
            ],

            // ── 저축 전용: 계좌 정보 ──
            if (isSaving && item.accountName != null) ...[
              const SizedBox(height: 16),
              _sectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionLabel('계좌 정보',
                        icon: Icons.account_balance_outlined,
                        iconColor: AppColors.saving,
                        iconBg: AppColors.savingSoft),
                    const SizedBox(height: 14),
                    _buildInfoRow('저축 계좌', item.accountName!),
                  ],
                ),
              ),
            ],

            // ── 수입 전용: 안내 카드 ──
            if (isIncome) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.incomeSoft,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, size: 18, color: AppColors.income),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '오른쪽 위 연필 아이콘을 눌러 이 수입 내역을 수정할 수 있어요.',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: AppColors.income.withValues(alpha: 0.9),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ─────────────────────── 스타일 헬퍼 (다른 입력 화면과 통일) ───────────────────────

  Widget _sectionCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppColors.cardShadow,
      ),
      child: child,
    );
  }

  Widget _sectionLabel(String text, {IconData? icon, Color? iconColor, Color? iconBg}) {
    return Row(
      children: [
        if (icon != null) ...[
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: iconBg ?? AppColors.utilitySoft,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 14, color: iconColor ?? AppColors.utility),
          ),
          const SizedBox(width: 8),
        ],
        Text(
          text,
          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: AppColors.ink),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 72,
          child: Text(
            label,
            style: const TextStyle(color: AppColors.inkSub, fontSize: 13.5, fontWeight: FontWeight.w600),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(color: AppColors.ink, fontSize: 14.5, fontWeight: FontWeight.w700),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }

  String _translateEmotion(String tag) {
    switch (tag) {
      case 'stress': return '😡 홧김에 썼어요';
      case 'impulsive': return '🥺 충동적이었어요';
      case 'happy': return '🥰 행복한 소비예요';
      default: return tag;
    }
  }

  String _savingStatusLabel(String code) {
    switch (code) {
      case 'matured': return '만기됨';
      case 'cancelled': return '해지함';
      case 'sold': return '매도완료';
      default: return '진행중';
    }
  }

  // ─────────────────────── 저축 상태 변경 모달 (DdaengModal 스타일) ───────────────────────

  void _showSavingStatusModal(BuildContext context, TransactionItem item) {
    String selectedStatus = 'active';
    final TextEditingController amountController = TextEditingController();
    bool isSaving = false;

    DdaengModal.custom(
      context,
      child: StatefulBuilder(
        builder: (ctx, setState) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppColors.savingSoft,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: const Icon(Icons.savings_outlined, size: 28, color: AppColors.saving),
                ),
                const SizedBox(height: 16),
                const Text(
                  '저축 / 투자 상태 변경',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.ink),
                ),
                const SizedBox(height: 6),
                const Text(
                  '현재 상태를 선택해주세요',
                  style: TextStyle(fontSize: 13, color: AppColors.inkSub),
                ),
                const SizedBox(height: 20),

                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7F7F9),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: selectedStatus,
                      isExpanded: true,
                      dropdownColor: Colors.white,
                      items: const [
                        DropdownMenuItem(value: 'active', child: Text('진행중')),
                        DropdownMenuItem(value: 'matured', child: Text('만기됨')),
                        DropdownMenuItem(value: 'cancelled', child: Text('해지함')),
                        DropdownMenuItem(value: 'sold', child: Text('매도완료')),
                      ],
                      onChanged: (value) {
                        setState(() => selectedStatus = value!);
                      },
                    ),
                  ),
                ),

                if (selectedStatus != 'active') ...[
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '최종 수령 금액 (원금+손익)',
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.inkSub),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [CurrencyFormatter()],
                    style: const TextStyle(fontSize: 14, color: AppColors.ink),
                    decoration: InputDecoration(
                      prefixText: '₩ ',
                      hintText: '돌려받은 금액을 입력하세요',
                      filled: true,
                      fillColor: const Color(0xFFF7F7F9),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: AppColors.saving, width: 1.6),
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 50,
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(ctx),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.inkSub,
                            side: const BorderSide(color: Color(0xFFE8ECF3), width: 1.4),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          child: const Text('취소', style: TextStyle(fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: SizedBox(
                        height: 50,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.saving,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          onPressed: isSaving
                              ? null
                              : () async {
                            int? returnedAmount;
                            if (selectedStatus != 'active') {
                              final amountText =
                              amountController.text.replaceAll(',', '').trim();
                              returnedAmount = int.tryParse(amountText);

                              if (returnedAmount == null || returnedAmount < 0) {
                                await DdaengModal.alert(
                                  ctx,
                                  title: '입력을 확인해주세요',
                                  message: '올바른 최종 금액을 입력해주세요.',
                                  type: ModalType.warning,
                                );
                                return;
                              }
                            }

                            setState(() => isSaving = true);

                            try {
                              await FirebaseFirestore.instance
                                  .collection('savings')
                                  .doc(item.id)
                                  .update({
                                'status': selectedStatus,
                                'returnedAmount': returnedAmount,
                                'updatedAt': FieldValue.serverTimestamp(),
                              });

                              if (selectedStatus != 'active' &&
                                  returnedAmount != null &&
                                  returnedAmount > 0) {
                                String memoText = '';
                                if (selectedStatus == 'matured') {
                                  memoText = '${item.title} 만기 환급금';
                                } else if (selectedStatus == 'cancelled') {
                                  memoText = '${item.title} 해지 환급금';
                                } else if (selectedStatus == 'sold') {
                                  memoText = '${item.title} 매도 금액';
                                }

                                // "기타수입" 카테고리를 이름으로 직접 조회 (하드코딩 ID 대신)
                                String etcCategoryId = '';
                                try {
                                  final etcSnap = await FirebaseFirestore.instance
                                      .collection('categories')
                                      .where('transactionType', isEqualTo: 'income')
                                      .where('parentName', isEqualTo: '비정기 수입')
                                      .where('name', isEqualTo: '기타 수입')
                                      .limit(1)
                                      .get();
                                  if (etcSnap.docs.isNotEmpty) {
                                    etcCategoryId = etcSnap.docs.first.id;
                                  }
                                  debugPrint('🔍 기타수입 카테고리ID 조회 결과: $etcCategoryId');
                                } catch (e) {
                                  debugPrint('⚠️ 기타수입 카테고리 조회 실패: $e');
                                }

                                await FirebaseFirestore.instance
                                    .collection('incomes')
                                    .add({
                                  'userId':
                                  FirebaseAuth.instance.currentUser?.uid ?? '',
                                  'amount': returnedAmount,
                                  'categoryId': etcCategoryId,
                                  'date': Timestamp.now(),
                                  'memo': memoText,
                                  'isDeleted': false,
                                  'createdAt': FieldValue.serverTimestamp(),
                                });
                              }

                              if (ctx.mounted) {
                                Navigator.pop(ctx);
                                if (context.mounted) {
                                  Navigator.pop(context, true);
                                  await DdaengModal.alert(
                                    context,
                                    title: '변경 완료',
                                    message: '상태 변경 및 환급금 기록이 완료되었습니다!',
                                    type: ModalType.success,
                                  );
                                }
                              }
                            } catch (e) {
                              debugPrint('상태 업데이트 오류: $e');
                              setState(() => isSaving = false);
                            }
                          },
                          child: isSaving
                              ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.2,
                            ),
                          )
                              : const Text('저장', style: TextStyle(fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ─────────────────────── 삭제 확인 (DdaengModal.confirm) ───────────────────────

  void _showDeleteModal(BuildContext context) async {
    final confirmed = await DdaengModal.confirm(
      context,
      title: '내역 삭제',
      message: '정말 이 내역을 삭제하시겠습니까?',
      type: ModalType.danger,
      cancelText: '취소',
      confirmText: '삭제',
    );

    if (!confirmed) return;

    await TransactionService().deleteTransaction(item.type, item.id);

    if (context.mounted) {
      Navigator.pop(context, true);
    }
  }
}