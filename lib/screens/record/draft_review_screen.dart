import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../utils/app_colors.dart';
import '../../models/category_model.dart' show TransactionType;
import '../../models/expense_model.dart';
import '../../models/income_model.dart';
import '../../models/saving_model.dart';
import '../../services/expense_service.dart';
import '../../services/income_service.dart';
import '../../services/saving_service.dart';
import '../../widgets/common/ddaeng_modal.dart';
import 'parsed_record_draft.dart';

/// 파싱된 항목들을 확인 · 수정 · 선택해서 일괄 저장하는 공통 화면.
///
/// 직접 입력(BulkRecordScreen) / 영수증 촬영(ReceiptUploadScreen) /
/// 문자내역 붙여넣기(SmsPasteScreen) 세 곳 모두 파싱이 끝나면 이 화면으로
/// push해서 재사용합니다. (텍스트를 어떻게 모았는지는 여기서 신경 쓰지 않음)
class DraftReviewScreen extends StatefulWidget {
  final List<ParsedRecordDraft> initialDrafts;

  const DraftReviewScreen({super.key, required this.initialDrafts});

  @override
  State<DraftReviewScreen> createState() => _DraftReviewScreenState();
}

class _DraftReviewScreenState extends State<DraftReviewScreen> {
  final _expenseService = ExpenseService();
  final _incomeService = IncomeService();
  final _savingService = SavingService();

  late List<ParsedRecordDraft> _drafts;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _drafts = widget.initialDrafts;
  }

  int get _selectedCount => _drafts.where((d) => d.isSelected).length;

  Future<void> _saveAll() async {
    final User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      await DdaengModal.alert(context,
          title: '로그인이 필요해요', message: '로그인된 사용자가 없습니다.', type: ModalType.warning);
      return;
    }

    final selected = _drafts.where((d) => d.isSelected).toList();
    if (selected.isEmpty) return;

    final String userId = currentUser.uid;
    setState(() => _isSaving = true);

    try {
      for (final draft in selected) {
        switch (draft.type) {
          case TransactionType.expense:
            await _expenseService.addExpense(ExpenseModel(
              expenseId: '',
              userId: userId,
              amount: draft.amount,
              date: draft.date,
              categoryId: draft.categoryId ?? 'uncategorized',
              nature: draft.nature ?? ExpenseNature.variable,
              emotionTag: draft.emotionTag,
              memo: draft.memo,
              isQuickInput: true,
            ));
            break;
          case TransactionType.income:
            await _incomeService.addIncome(IncomeModel(
              incomeId: '',
              userId: userId,
              amount: draft.amount,
              categoryId: draft.categoryId ?? 'uncategorized',
              date: draft.date,
              memo: draft.memo,
            ));
            break;
          case TransactionType.saving:
            await _savingService.addSaving(SavingModel(
              savingId: '',
              userId: userId,
              date: draft.date,
              categoryId: draft.categoryId ?? 'deposit',
              accountName: draft.accountName,
              amount: draft.amount,
              memo: draft.memo,
            ));
            break;
        }
      }

      if (!mounted) return;
      await DdaengModal.alert(context,
          title: '저장 완료', message: '$_selectedCount개 항목을 저장했어요.', type: ModalType.success);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      debugPrint('🔥 일괄 저장 에러: $e');
      if (mounted) {
        await DdaengModal.alert(context, title: '저장에 실패했어요', message: '$e', type: ModalType.danger);
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ─────────────────────── 스타일 헬퍼 ───────────────────────

  Widget _sectionLabel(String text, {IconData? icon, Color? iconColor, Color? iconBg}) {
    return Row(
      children: [
        if (icon != null) ...[
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: iconBg ?? AppColors.expense.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 14, color: iconColor ?? AppColors.expenseDeep),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text('내용 확인',
            style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.ink)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_drafts.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 60),
                child: Center(
                  child: Text('인식된 항목이 없어요', style: TextStyle(color: AppColors.inkSub)),
                ),
              )
            else ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('인식된 항목 ${_drafts.length}개',
                      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: AppColors.ink)),
                  const Text('틀린 부분은 눌러서 수정',
                      style: TextStyle(fontSize: 11.5, color: AppColors.inkSub)),
                ],
              ),
              const SizedBox(height: 10),
              ..._drafts.map((d) => _buildDraftRow(d)),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: (_selectedCount == 0 || _isSaving) ? null : _saveAll,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.ink,
                    disabledBackgroundColor: const Color(0xFFE5E8EB),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                      : Text('$_selectedCount개 항목 전체 저장',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDraftRow(ParsedRecordDraft draft) {
    final typeColor = switch (draft.type) {
      TransactionType.expense => AppColors.expense,
      TransactionType.income => AppColors.income,
      TransactionType.saving => AppColors.saving,
    };
    final typeLabel = switch (draft.type) {
      TransactionType.expense => '지출',
      TransactionType.income => '수입',
      TransactionType.saving => '저축',
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: AppColors.cardShadow,
      ),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.fromLTRB(8, 0, 8, 14),
        collapsedIconColor: AppColors.inkSub,
        iconColor: AppColors.expenseDeep,
        leading: Checkbox(
          value: draft.isSelected,
          activeColor: AppColors.expense,
          onChanged: (v) => setState(() => draft.isSelected = v ?? true),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: typeColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(typeLabel,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: typeColor)),
            ),
            const SizedBox(width: 8),
            Expanded(
                child: Text('${draft.memo} · ${draft.categoryName}',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13.5, color: AppColors.ink))),
          ],
        ),
        subtitle: Text(_formatDate(draft.date),
            style: const TextStyle(fontSize: 11.5, color: AppColors.inkSub)),
        trailing: Text('${draft.amount}원',
            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: AppColors.ink)),
        children: [_buildDraftEditor(draft)],
      ),
    );
  }

  Widget _buildDraftEditor(ParsedRecordDraft draft) {
    switch (draft.type) {
      case TransactionType.expense:
        return Wrap(
          spacing: 6,
          runSpacing: 6,
          children: ExpenseNature.values.map((n) {
            final selected = draft.nature == n;
            return _draftChip(
              label: n.label,
              selected: selected,
              color: AppColors.expense,
              onSelected: () => setState(() => draft.nature = n),
            );
          }).toList(),
        );
      case TransactionType.income:
        const incomeOptions = [
          ('salary', '월급'),
          ('freelance', '프리랜서'),
          ('allowance', '용돈'),
          ('etc', '기타'),
        ];
        return Wrap(
          spacing: 6,
          runSpacing: 6,
          children: incomeOptions.map((o) {
            final selected = draft.categoryId == o.$1;
            return _draftChip(
              label: o.$2,
              selected: selected,
              color: AppColors.income,
              onSelected: () => setState(() => draft.categoryId = o.$1),
            );
          }).toList(),
        );
      case TransactionType.saving:
        const savingOptions = [
          ('housing_subscription', '청약'),
          ('installment_saving', '적금'),
          ('deposit', '예금'),
          ('parking_account', '파킹통장'),
          ('investment', '투자'),
        ];
        return Wrap(
          spacing: 6,
          runSpacing: 6,
          children: savingOptions.map((o) {
            final selected = draft.categoryId == o.$1;
            return _draftChip(
              label: o.$2,
              selected: selected,
              color: AppColors.saving,
              onSelected: () => setState(() => draft.categoryId = o.$1),
            );
          }).toList(),
        );
    }
  }

  Widget _draftChip({
    required String label,
    required bool selected,
    required Color color,
    required VoidCallback onSelected,
  }) {
    return ChoiceChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      selected: selected,
      onSelected: (_) => onSelected(),
      selectedColor: color,
      backgroundColor: color.withValues(alpha: 0.1),
      labelStyle: TextStyle(
        color: selected ? Colors.white : color,
        fontWeight: FontWeight.w700,
      ),
      side: BorderSide.none,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide.none,
      ),
      showCheckmark: false,
      elevation: 0,
      pressElevation: 0,
    );
  }

  String _formatDate(DateTime date) {
    final today = DateTime.now();
    if (date.year == today.year && date.month == today.month && date.day == today.day) {
      return '오늘';
    }
    return '${date.month}/${date.day}';
  }
}