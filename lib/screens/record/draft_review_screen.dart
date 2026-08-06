import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../utils/app_colors.dart';
import '../../models/transaction_type.dart';
import '../../models/expense_model.dart';
import '../../models/income_model.dart';
import '../../models/saving_model.dart';
import '../../models/emotion_tag_model.dart';
import '../../models/recurring_payment_model.dart';
import '../../models/card_point_model.dart';
import '../../models/card_point_history_model.dart';
import '../../services/expense_service.dart';
import '../../services/income_service.dart';
import '../../services/saving_service.dart';
import '../../services/recurring_payment_service.dart';
import '../../services/card_point_service.dart';
import '../../widgets/common/ddaeng_modal.dart';
import '../../utils/formatters.dart' show comma;
import 'parsed_record_draft.dart';
import 'category_matcher.dart';
import 'point_detector.dart';

/// 파싱된 항목들을 확인 · 수정 · 선택해서 일괄 저장하는 공통 화면.
///
/// 직접 입력(BulkRecordScreen) / 영수증 촬영(ReceiptUploadScreen) /
/// 문자내역 붙여넣기(SmsPasteScreen) 세 곳 모두 파싱이 끝나면 이 화면으로
/// push해서 재사용합니다. (텍스트를 어떻게 모았는지는 여기서 신경 쓰지 않음)
class DraftReviewScreen extends StatefulWidget {
  final List<ParsedRecordDraft> initialDrafts;
  final AllCategoryOptions categories;

  /// 원본 텍스트(영수증 OCR/문자/직접입력)에서 미리 감지해둔 포인트 내역.
  /// 비어있으면 저장 시 포인트 관련 확인을 아예 건너뛴다.
  final List<DetectedPoint> detectedPoints;

  const DraftReviewScreen({
    super.key,
    required this.initialDrafts,
    required this.categories,
    this.detectedPoints = const [],
  });

  @override
  State<DraftReviewScreen> createState() => _DraftReviewScreenState();
}

class _DraftReviewScreenState extends State<DraftReviewScreen> {
  final _expenseService = ExpenseService();
  final _incomeService = IncomeService();
  final _savingService = SavingService();
  final _recurringPaymentService = RecurringPaymentService();
  final _cardPointService = CardPointService();

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

    // 포인트가 감지된 경우, 실제 저장에 들어가기 전에 먼저 물어본다.
    // (거절하거나 카드가 없어서 못 골라도 아래 일반 저장 흐름은 그대로 진행)
    await _maybeOfferPointSave(userId);
    if (!mounted) return;

    setState(() => _isSaving = true);

    try {
      for (final draft in selected) {
        switch (draft.type) {
          case TransactionType.expense:
            String? recurringPaymentId;
            // 정기결제로 등록하는 경우, 지출을 만들기 전에 정기결제 원본을 먼저 만들어
            // expense.recurringPaymentId로 연결한다.
            if (draft.isRecurring) {
              final cycle = draft.billingCycle == 'yearly'
                  ? BillingCycle.yearly
                  : BillingCycle.monthly;
              final nextBillingDate = cycle == BillingCycle.yearly
                  ? DateTime(draft.date.year + 1, draft.date.month, draft.date.day)
                  : DateTime(draft.date.year, draft.date.month + 1, draft.date.day);
              recurringPaymentId = await _recurringPaymentService.addRecurringPayment(
                RecurringPaymentModel(
                  recurringPaymentId: '',
                  userId: userId,
                  name: draft.memo.isNotEmpty ? draft.memo : draft.categoryName,
                  amount: draft.amount,
                  billingCycle: cycle,
                  nextBillingDate: nextBillingDate,
                  categoryId: draft.categoryId ?? 'uncategorized',
                ),
              );
            }
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
              recurringPaymentId: recurringPaymentId,
            ));
            break;
          case TransactionType.income:
            String? recurringIncomeTemplateId;
            int? recurringPayDay;
            // 정기수입으로 등록하는 경우, 반복등록 템플릿을 먼저 만들어
            // income.recurringIncomeTemplateId로 연결한다.
            if (draft.isRecurring) {
              recurringPayDay = draft.recurringPayDay ?? draft.date.day;
              recurringIncomeTemplateId = await _incomeService.addRecurringTemplate(
                RecurringIncomeTemplate(
                  recurringIncomeTemplateId: '',
                  userId: userId,
                  categoryId: draft.categoryId ?? 'uncategorized',
                  amount: draft.amount,
                  payDay: recurringPayDay,
                  startDate: draft.date,
                  memo: draft.memo,
                ),
              );
            }
            await _incomeService.addIncome(IncomeModel(
              incomeId: '',
              userId: userId,
              amount: draft.amount,
              categoryId: draft.categoryId ?? 'uncategorized',
              date: draft.date,
              memo: draft.memo,
              recurringIncomeTemplateId: recurringIncomeTemplateId,
              recurringPayDay: draft.isRecurring ? recurringPayDay : null,
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

  /// 감지된 포인트가 있으면 "카드 포인트로도 저장할까요?" 확인 모달을 띄우고,
  /// 저장을 선택하면 카드를 고르게 한 뒤 각 포인트를 CardPointHistory로 저장한다.
  /// 감지된 포인트가 없거나, 사용자가 거절하거나, 카드가 없어서 못 고르면
  /// 조용히 넘어간다(지출/수입/저축 저장 자체는 이 함수와 무관하게 계속됨).
  Future<void> _maybeOfferPointSave(String userId) async {
    if (widget.detectedPoints.isEmpty) return;

    final String summary = widget.detectedPoints.map((p) {
      final String label = p.type == 'earn' ? '적립' : '사용';
      return '${comma(p.amount)}P $label';
    }).join(', ');

    final bool confirmed = await DdaengModal.confirm(
      context,
      title: '포인트 내역이 있어요',
      message: '이번 내역에서 포인트 정보를 찾았어요 ($summary).\n카드 포인트에도 저장할까요?',
      type: ModalType.info,
      confirmText: '저장',
    );
    if (!confirmed || !mounted) return;

    final CardPointModel? card = await _pickCard(userId);
    if (card == null || !mounted) return;

    final String merchant = _drafts.isNotEmpty
        ? (_drafts.first.memo.isNotEmpty ? _drafts.first.memo : _drafts.first.categoryName)
        : '영수증';
    final DateTime date = _drafts.isNotEmpty ? _drafts.first.date : DateTime.now();

    for (final DetectedPoint point in widget.detectedPoints) {
      await _cardPointService.addHistory(
        userId: userId,
        cardId: card.cardId,
        history: CardPointHistoryModel(
          historyId: '',
          date: date,
          merchant: merchant,
          point: point.amount,
          type: point.type,
        ),
      );
    }
  }

  /// 사용자가 직접 적립/사용할 카드를 고르게 하는 바텀시트.
  /// 등록된 카드가 없으면 안내만 하고 null을 반환한다.
  Future<CardPointModel?> _pickCard(String userId) async {
    final List<CardPointModel> cards =
    await _cardPointService.getCardPoints(userId: userId).first;
    if (!mounted) return null;

    if (cards.isEmpty) {
      await DdaengModal.alert(context,
          title: '등록된 카드가 없어요',
          message: '카드 포인트 화면에서 카드를 먼저 등록해주세요.',
          type: ModalType.info);
      return null;
    }

    return showModalBottomSheet<CardPointModel>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('어느 카드에 적립할까요?',
                    style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800, color: AppColors.ink)),
                const SizedBox(height: 14),
                ...cards.map((c) => InkWell(
                  onTap: () => Navigator.pop(sheetContext, c),
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.bg,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(c.companyName,
                                  style: const TextStyle(fontSize: 11.5, color: AppColors.inkSub)),
                              const SizedBox(height: 2),
                              Text(c.cardName,
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.ink)),
                            ],
                          ),
                        ),
                        Text('${comma(c.totalPoint)}P',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.ink)),
                      ],
                    ),
                  ),
                )),
              ],
            ),
          ),
        );
      },
    );
  }

  final Map<ParsedRecordDraft, TextEditingController> _accountNameControllers = {};

  TextEditingController _accountNameController(ParsedRecordDraft draft) {
    return _accountNameControllers.putIfAbsent(
      draft,
          () => TextEditingController(text: draft.accountName ?? ''),
    );
  }

  final Map<ParsedRecordDraft, TextEditingController> _memoControllers = {};

  TextEditingController _memoController(ParsedRecordDraft draft) {
    return _memoControllers.putIfAbsent(
      draft,
          () => TextEditingController(text: draft.memo),
    );
  }

  @override
  void dispose() {
    for (final c in _accountNameControllers.values) {
      c.dispose();
    }
    for (final c in _memoControllers.values) {
      c.dispose();
    }
    super.dispose();
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
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: AppColors.cardShadow,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _openEditModal(draft),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            child: Row(
              children: [
                Checkbox(
                  value: draft.isSelected,
                  activeColor: AppColors.expense,
                  onChanged: (v) => setState(() => draft.isSelected = v ?? true),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
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
                          if (draft.isRecurring) ...[
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.utility.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text('정기',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.utility)),
                            ),
                          ],
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(draft.memo.isNotEmpty ? draft.memo : draft.categoryName,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 13.5, color: AppColors.ink)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.bg,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: typeColor.withValues(alpha: 0.3), width: 1),
                            ),
                            child: Text(draft.categoryName,
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: typeColor)),
                          ),
                          const SizedBox(width: 6),
                          Text(_formatDate(draft.date),
                              style: const TextStyle(fontSize: 11.5, color: AppColors.inkSub)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text('${comma(draft.amount)}원',
                    style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: AppColors.ink)),
                const SizedBox(width: 2),
                Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.inkSub.withValues(alpha: 0.5)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openEditModal(ParsedRecordDraft draft) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (modalContext) {
        return StatefulBuilder(
          builder: (modalContext, modalSetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(modalContext).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE5E8EB),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Text('${comma(draft.amount)}원',
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.ink)),
                    const SizedBox(height: 2),
                    Text(_formatDate(draft.date),
                        style: const TextStyle(fontSize: 12, color: AppColors.inkSub)),
                    const SizedBox(height: 18),

                    const Text('메모',
                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: AppColors.ink)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _memoController(draft),
                      style: const TextStyle(fontSize: 13.5, color: AppColors.ink),
                      decoration: InputDecoration(
                        hintText: '메모를 입력하세요',
                        filled: true,
                        fillColor: AppColors.bg,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onChanged: (v) => draft.memo = v,
                    ),
                    const SizedBox(height: 18),

                    _buildDraftEditor(draft, modalSetState),

                    const SizedBox(height: 22),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(modalContext),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.ink,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: const Text('완료', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).then((_) {
      // 모달 닫힌 뒤 리스트 행의 memo/categoryName 표시를 갱신
      if (mounted) setState(() {});
    });
  }

  Widget _buildDraftEditor(ParsedRecordDraft draft, StateSetter setLocalState) {
    switch (draft.type) {
      case TransactionType.expense:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('지출 성격', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: AppColors.ink)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6, runSpacing: 6,
              children: ExpenseNature.values.map((n) {
                final selected = draft.nature == n;
                return _draftChip(
                  label: n.label, selected: selected, color: AppColors.expense,
                  onSelected: () => setLocalState(() => draft.nature = n),
                );
              }).toList(),
            ),
            if (draft.nature == ExpenseNature.variable) ...[
              const SizedBox(height: 14),
              const Text('감정태그', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: AppColors.ink)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6, runSpacing: 6,
                children: EmotionTag.values.map((tag) {
                  final selected = draft.emotionTag == tag.code;
                  return _draftChip(
                    label: '${tag.emoji} ${tag.label}',
                    selected: selected,
                    color: AppColors.expense,
                    onSelected: () => setLocalState(() => draft.emotionTag = tag.code),
                  );
                }).toList(),
              ),
            ],
            const SizedBox(height: 14),
            _recurringToggleRow(
              label: '정기결제로 등록',
              value: draft.isRecurring,
              color: AppColors.expense,
              onChanged: (v) => setLocalState(() {
                draft.isRecurring = v;
                if (v) draft.billingCycle ??= 'monthly';
              }),
            ),
            if (draft.isRecurring) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6, runSpacing: 6,
                children: [
                  _draftChip(
                    label: '매달',
                    selected: draft.billingCycle != 'yearly',
                    color: AppColors.expense,
                    onSelected: () => setLocalState(() => draft.billingCycle = 'monthly'),
                  ),
                  _draftChip(
                    label: '매년',
                    selected: draft.billingCycle == 'yearly',
                    color: AppColors.expense,
                    onSelected: () => setLocalState(() => draft.billingCycle = 'yearly'),
                  ),
                ],
              ),
            ],
          ],
        );
      case TransactionType.income:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('카테고리', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: AppColors.ink)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6, runSpacing: 6,
              children: widget.categories.income.map((opt) {
                final selected = draft.categoryId == opt.id;
                return _draftChip(
                  label: opt.name, selected: selected, color: AppColors.income,
                  onSelected: () => setLocalState(() {
                    draft.categoryId = opt.id;
                    draft.categoryName = opt.name;
                  }),
                );
              }).toList(),
            ),
            const SizedBox(height: 14),
            _recurringToggleRow(
              label: '정기수입으로 등록',
              value: draft.isRecurring,
              color: AppColors.income,
              onChanged: (v) => setLocalState(() {
                draft.isRecurring = v;
                if (v) draft.recurringPayDay ??= draft.date.day;
              }),
            ),
            if (draft.isRecurring) ...[
              const SizedBox(height: 10),
              const Text('매달 입금일', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: AppColors.ink)),
              const SizedBox(height: 6),
              TextField(
                controller: TextEditingController(text: '${draft.recurringPayDay ?? draft.date.day}')
                  ..selection = TextSelection.collapsed(
                    offset: '${draft.recurringPayDay ?? draft.date.day}'.length,
                  ),
                keyboardType: TextInputType.number,
                style: const TextStyle(fontSize: 13, color: AppColors.ink),
                decoration: InputDecoration(
                  hintText: '예: 25 (25일)',
                  isDense: true,
                  filled: true,
                  fillColor: AppColors.bg,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (v) {
                  final day = int.tryParse(v);
                  if (day != null && day >= 1 && day <= 31) {
                    draft.recurringPayDay = day;
                  }
                },
              ),
            ],
          ],
        );
      case TransactionType.saving:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('계좌명', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: AppColors.ink)),
            const SizedBox(height: 6),
            TextField(
              controller: _accountNameController(draft),
              style: const TextStyle(fontSize: 13, color: AppColors.ink),
              decoration: InputDecoration(
                hintText: '예: 국민은행 청년희망적금',
                isDense: true,
                filled: true,
                fillColor: AppColors.bg,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (v) => draft.accountName = v.trim().isEmpty ? null : v.trim(),
            ),
            const SizedBox(height: 14),
            const Text('카테고리', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: AppColors.ink)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6, runSpacing: 6,
              children: widget.categories.saving.map((opt) {
                final selected = draft.categoryId == opt.id;
                return _draftChip(
                  label: opt.name, selected: selected, color: AppColors.saving,
                  onSelected: () => setLocalState(() {
                    draft.categoryId = opt.id;
                    draft.categoryName = opt.name;
                  }),
                );
              }).toList(),
            ),
          ],
        );
    }
  }

  Widget _recurringToggleRow({
    required String label,
    required bool value,
    required Color color,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(label,
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: AppColors.ink)),
        ),
        Switch(
          value: value,
          activeColor: color,
          onChanged: onChanged,
        ),
      ],
    );
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