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

    // ── 지출 전용: 할부/정기결제 등 부가 정보 ──
    final List<Widget> expenseExtraRows = [];
    if (isExpense) {
      if (item.isInstallment) {
        expenseExtraRows.add(_buildInfoRow(
          '할부',
          item.installmentTotalMonths != null ? '총 ${item.installmentTotalMonths}개월 할부' : '할부 결제 진행 중',
        ));
      }
      if (item.isRecurring) {
        expenseExtraRows.add(_buildInfoRow('정기결제', '매달 자동으로 결제되는 항목'));
      }
    }
    final Widget? expenseExtraCard = _rowsCard(
      title: '부가 정보',
      icon: Icons.label_outline_rounded,
      iconColor: typeColor,
      iconBg: typeColor.withValues(alpha: 0.15),
      rows: expenseExtraRows,
    );

    // ── 저축 전용: 계좌/반복/환급금액을 한 카드로 통합 ──
    final List<Widget> savingDetailRows = [];
    if (isSaving) {
      if (item.accountName != null && item.accountName!.isNotEmpty) {
        savingDetailRows.add(_buildInfoRow('저축 계좌', item.accountName!));
      }
      if (item.isRecurring) {
        savingDetailRows.add(_buildInfoRow('반복 여부', '매달 자동으로 적립/투자'));
      }
      if (isCompletedSaving && item.returnedAmount != null) {
        savingDetailRows.add(_buildInfoRow('환급 금액', '${CurrencyFormatter.format(item.returnedAmount!)}원'));
      }
    }
    final Widget? savingDetailCard = _rowsCard(
      title: '저축 상세',
      icon: Icons.account_balance_outlined,
      iconColor: AppColors.saving,
      iconBg: AppColors.savingSoft,
      rows: savingDetailRows,
    );

    // ── 저축 전용: 투자 상세 (증권사/종목명/수량) ──
    final List<Widget> investmentRows = [];
    if (isSaving && item.investmentDetail != null) {
      final inv = item.investmentDetail!;
      investmentRows.add(_buildInfoRow('증권사', inv.brokerage));
      investmentRows.add(_buildInfoRow('종목명', inv.assetName));
      if (inv.quantity != null) {
        investmentRows.add(_buildInfoRow('매수 수량', '${inv.quantity}'));
      }
    }
    final Widget? investmentCard = _rowsCard(
      title: '투자 상세',
      icon: Icons.show_chart_rounded,
      iconColor: AppColors.saving,
      iconBg: AppColors.savingSoft,
      rows: investmentRows,
    );

    // ── 수입 전용: 정기 수입 여부 ──
    final List<Widget> incomeExtraRows = [];
    if (isIncome && item.isRecurring) {
      incomeExtraRows.add(_buildInfoRow(
        '정기 수입',
        item.recurringPayDay != null ? '매달 ${item.recurringPayDay}일 자동 기록' : '매달 자동으로 기록되는 수입',
      ));
    }
    final Widget? incomeExtraCard = _rowsCard(
      title: '부가 정보',
      icon: Icons.label_outline_rounded,
      iconColor: AppColors.income,
      iconBg: AppColors.incomeSoft,
      rows: incomeExtraRows,
    );

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
                _handleSavingEdit(context, item);
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
                  if (item.parentCategory != null && item.parentCategory!.isNotEmpty) ...[
                    _buildInfoRow('카테고리', '${item.parentCategory} · ${item.title}'),
                    const SizedBox(height: 14),
                  ],
                  _buildInfoRow('일시', DateFormatter.formatDayAndWeekday(item.date)),
                  if (isExpense && item.nature != null) ...[
                    const SizedBox(height: 14),
                    _buildInfoRow('지출 성격', _natureLabel(item.nature)),
                  ],
                  if (item.subtitle != null && item.subtitle!.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    _buildInfoRow('메모', item.subtitle!),
                  ],
                ],
              ),
            ),

            // ── 지출 전용: 할부/정기결제 부가 정보 ──
            if (expenseExtraCard != null) ...[
              const SizedBox(height: 16),
              expenseExtraCard,
            ],

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

            // ── 저축 전용: 계좌/반복/환급금액 ──
            if (savingDetailCard != null) ...[
              const SizedBox(height: 16),
              savingDetailCard,
            ],

            // ── 저축 전용: 투자 상세 ──
            if (investmentCard != null) ...[
              const SizedBox(height: 16),
              investmentCard,
            ],

            // ── 수입 전용: 정기 수입 부가 정보 ──
            if (incomeExtraCard != null) ...[
              const SizedBox(height: 16),
              incomeExtraCard,
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

  // rows가 비어있으면 카드 자체를 렌더링하지 않음 (선택적 부가 정보 카드용)
  Widget? _rowsCard({
    required String title,
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required List<Widget> rows,
  }) {
    if (rows.isEmpty) return null;
    return _sectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel(title, icon: icon, iconColor: iconColor, iconBg: iconBg),
          const SizedBox(height: 14),
          for (int i = 0; i < rows.length; i++) ...[
            rows[i],
            if (i != rows.length - 1) const SizedBox(height: 14),
          ],
        ],
      ),
    );
  }

  String _natureLabel(String? code) {
    switch (code) {
      case 'fixed':
        return '고정비';
      case 'variable':
        return '변동비';
      case 'other':
        return '기타';
      default:
        return '-';
    }
  }

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
                                final bool recorded = await _recordReturnIncome(
                                  ctx,
                                  savingId: item.id,
                                  title: item.title,
                                  status: selectedStatus,
                                  returnedAmount: returnedAmount,
                                );

                                if (!recorded && ctx.mounted) {
                                  await DdaengModal.alert(
                                    ctx,
                                    title: '수입 기록을 건너뛰었어요',
                                    message:
                                    '카테고리를 선택하지 않아 환급금 수입 내역은 저장되지 않았어요.\n'
                                        '저축/투자 상태 변경은 정상 반영됐어요.\n'
                                        '내역을 다시 눌러 수입도 기록할 수 있어요.',
                                    type: ModalType.warning,
                                  );
                                }
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

  // ─────────────────────── 수입 카테고리 폴백 피커 ───────────────────────
  // "기타 수입" 카테고리를 자동으로 못 찾았을 때, 유저가 직접 수입 카테고리를
  // 고르게 하는 간단한 대분류/소분류 선택 모달. 취소 시 null 반환.
  Future<String?> _pickIncomeCategoryFallback(BuildContext context) async {
    final String userId = FirebaseAuth.instance.currentUser?.uid ?? '';
    List<Map<String, dynamic>> categories = [];

    try {
      final db = FirebaseFirestore.instance;
      final defaultSnap =
      await db.collection('categories').where('transactionType', isEqualTo: 'income').get();
      final customSnap =
      await db.collection('customCategories').where('userId', isEqualTo: userId).get();

      List<String> hiddenIds = [];
      final userDoc = await db.collection('users').doc(userId).get();
      if (userDoc.exists && userDoc.data()!.containsKey('hiddenCategories')) {
        hiddenIds = List<String>.from(userDoc.data()!['hiddenCategories']);
      }

      for (var doc in defaultSnap.docs) {
        if (!hiddenIds.contains(doc.id)) categories.add({'id': doc.id, ...doc.data()});
      }
      for (var doc in customSnap.docs) {
        final data = doc.data();
        if (data['transactionType'] == 'income' && data['isHidden'] != true) {
          categories.add({'id': doc.id, ...data});
        }
      }
    } catch (e) {
      debugPrint('⚠️ 폴백 카테고리 로드 실패: $e');
    }

    if (categories.isEmpty || !context.mounted) return null;

    String? selectedParent;
    String? selectedId;

    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            final parents =
            categories.map((c) => (c['parentName'] ?? c['parent'] ?? '미분류').toString()).toSet().toList();
            final children = selectedParent == null
                ? <Map<String, dynamic>>[]
                : categories
                .where((c) => (c['parentName'] ?? c['parent'] ?? '미분류') == selectedParent)
                .toList();

            return Padding(
              padding: EdgeInsets.fromLTRB(
                24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '기타 수입 카테고리를 찾지 못했어요',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.ink),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    '이 환급금을 어떤 수입 카테고리로 기록할지 선택해주세요.',
                    style: TextStyle(fontSize: 12.5, color: AppColors.inkSub),
                  ),
                  const SizedBox(height: 18),
                  DropdownButtonFormField<String>(
                    value: selectedParent,
                    hint: const Text('대분류 선택'),
                    isExpanded: true,
                    items: parents
                        .map((p) => DropdownMenuItem<String>(value: p, child: Text(p)))
                        .toList(),
                    onChanged: (v) => setState(() {
                      selectedParent = v;
                      selectedId = null;
                    }),
                  ),
                  if (selectedParent != null) ...[
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: selectedId,
                      hint: const Text('소분류 선택'),
                      isExpanded: true,
                      items: children
                          .map((c) => DropdownMenuItem<String>(
                        value: c['id']?.toString(),
                        child: Text(c['name']?.toString() ?? '이름 없음'),
                      ))
                          .toList(),
                      onChanged: (v) => setState(() => selectedId = v),
                    ),
                  ],
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(ctx, null),
                          child: const Text('취소'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.saving),
                          onPressed: selectedId == null ? null : () => Navigator.pop(ctx, selectedId),
                          child: const Text('선택 완료', style: TextStyle(color: Colors.white)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ─────────────────────── 환급금 수입 기록 헬퍼 ───────────────────────
// 카테고리 자동조회(기본→커스텀) → 실패 시 피커 → 그래도 실패하면 false 반환.
// 성공 시 incomes 문서 생성 + savings.returnIncomeRecorded = true 로 마킹.
  Future<bool> _recordReturnIncome(
      BuildContext ctx, {
        required String savingId,
        required String title,
        required String status,
        required int returnedAmount,
      }) async {
    String memoText = '';
    if (status == 'matured') {
      memoText = '$title 만기 환급금';
    } else if (status == 'cancelled') {
      memoText = '$title 해지 환급금';
    } else if (status == 'sold') {
      memoText = '$title 매도 금액';
    }

    String? etcCategoryId;
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
      } else {
        final customSnap = await FirebaseFirestore.instance
            .collection('customCategories')
            .where('userId', isEqualTo: FirebaseAuth.instance.currentUser?.uid ?? '')
            .where('transactionType', isEqualTo: 'income')
            .where('parentName', isEqualTo: '비정기 수입')
            .where('name', isEqualTo: '기타 수입')
            .limit(1)
            .get();
        if (customSnap.docs.isNotEmpty) {
          etcCategoryId = customSnap.docs.first.id;
        }
      }
    } catch (e) {
      debugPrint('⚠️ 기타수입 카테고리 조회 실패: $e');
    }

    if (etcCategoryId == null && ctx.mounted) {
      etcCategoryId = await _pickIncomeCategoryFallback(ctx);
    }

    if (etcCategoryId == null) return false;

    await FirebaseFirestore.instance.collection('incomes').add({
      'userId': FirebaseAuth.instance.currentUser?.uid ?? '',
      'amount': returnedAmount,
      'categoryId': etcCategoryId,
      'date': Timestamp.now(),
      'memo': memoText,
      'isDeleted': false,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await FirebaseFirestore.instance
        .collection('savings')
        .doc(savingId)
        .update({'returnIncomeRecorded': true});

    return true;
  }

  // ─────────────────────── 저축 편집 진입 핸들러 ───────────────────────
  // 이미 상태변경은 됐는데 수입 기록이 안 남아있는 건인지 최신 문서로 확인 후,
  // 맞으면 먼저 "지금 수입으로 기록할지" 물어보고, 아니면 기존 상태변경 모달로.
  Future<void> _handleSavingEdit(BuildContext context, TransactionItem item) async {
    Map<String, dynamic>? data;
    try {
      final doc = await FirebaseFirestore.instance.collection('savings').doc(item.id).get();
      data = doc.data();
    } catch (e) {
      debugPrint('⚠️ 저축 문서 조회 실패: $e');
    }

    final String? status = data?['status'] as String?;
    final num? returnedAmountNum = data?['returnedAmount'] as num?;
    final bool alreadyRecorded = data?['returnIncomeRecorded'] == true;

    final bool needsIncomePrompt = status != null &&
        status != 'active' &&
        returnedAmountNum != null &&
        returnedAmountNum > 0 &&
        !alreadyRecorded;

    if (needsIncomePrompt && context.mounted) {
      final wantsToRecord = await DdaengModal.confirm(
        context,
        title: '수입 기록이 없어요',
        message: '이 저축 항목은 상태 변경만 되어있고\n환급금 수입 기록은 아직 없어요.\n지금 수입으로 기록하시겠어요?',
        type: ModalType.warning,
        cancelText: '나중에',
        confirmText: '기록하기',
      );

      if (wantsToRecord && context.mounted) {
        final bool recorded = await _recordReturnIncome(
          context,
          savingId: item.id,
          title: item.title,
          status: status,
          returnedAmount: returnedAmountNum.toInt(),
        );

        if (context.mounted) {
          await DdaengModal.alert(
            context,
            title: recorded ? '기록 완료' : '수입 기록을 건너뛰었어요',
            message: recorded
                ? '환급금 수입 기록이 완료되었어요!'
                : '카테고리를 선택하지 않아 환급금 수입 내역은 저장되지 않았어요.',
            type: recorded ? ModalType.success : ModalType.warning,
          );
          if (recorded) Navigator.pop(context, true);
        }
        return;
      }
    }

    if (context.mounted) {
      _showSavingStatusModal(context, item);
    }
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