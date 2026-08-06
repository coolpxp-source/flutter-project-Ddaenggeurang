import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../models/recurring_payment_model.dart';
import '../../services/recurring_payment_service.dart';
import '../../utils/app_colors.dart';
import '../../models/expense_model.dart';
import '../../services/expense_service.dart';
import '../../utils/formatters.dart';
import '../../models/transaction_item.dart';
import '../../widgets/common/ddaeng_modal.dart';
import '../../widgets/common/amount_calculator_sheet.dart';
import '../../widgets/common/add_subcategory_dialog.dart';
import '../../utils/korean_amount.dart';

/// 홈 화면(_C)과 통일한 팔레트.

class ExpenseInputScreen extends StatefulWidget {
  final TransactionItem? editItem;
  const ExpenseInputScreen({super.key, this.editItem});

  @override
  State<ExpenseInputScreen> createState() => _ExpenseInputScreenState();
}

class _ExpenseInputScreenState extends State<ExpenseInputScreen> {
  final _expenseService = ExpenseService();
  // 입력 전에는 실제 값을 비워 둡니다.
  // 화면에는 hintText로 0원을 보여 주므로, 처음부터 '영원' 자막이 뜨지 않습니다.
  final _amountController = TextEditingController();
  final _memoController = TextEditingController();
  DateTime _selectedDate = DateTime.now();

  bool _isLoadingCategories = true;
  bool _isSaving = false;
  List<Map<String, dynamic>> _allCategories = [];

  ExpenseNature _selectedNature = ExpenseNature.variable;
  String? _selectedParentCategory;
  String? _selectedCategoryId;

  final List<String> _emotionTags = ['충동적', '스트레스', '사회적', '계획적'];
  String? _selectedEmotion;

  bool _isInstallment = false;
  int _installmentMonths = 3;
  // 할부(isInstallment)와 동일한 성격의 단순 플래그. 별도 구독 컬렉션과는
  // 연결하지 않는다 — "구독관리"는 넷플릭스/멤버십 같은 진짜 구독 서비스
  // 전용이고, 여기 "정기결제"는 그냥 "매달 반복되는 지출"이라는 표시일 뿐.
  bool _isRecurring = false;

  @override
  void initState() {
    super.initState();

    if (widget.editItem != null) {
      final item = widget.editItem!;
      // 수정 화면에서도 기존 금액을 천 단위 쉼표 형식으로 표시합니다.
      _amountController.text = comma(item.amount);
      _selectedDate = item.date;
      if (item.subtitle != null) _memoController.text = item.subtitle!;
      _selectedEmotion = item.emotionTag;
    }

    // 금액이 변경될 때마다 한글 금액 표시도 갱신합니다.
    _amountController.addListener(_refreshAmount);

    _loadCategoriesFromDB().then((_) {
      if (widget.editItem != null) {
        _fetchOriginalExpense(widget.editItem!.id);
      }
    });
  }

  void _refreshAmount() {
    if (mounted) {
      setState(() {});
    }
  }

  String? _originalRecurringPaymentId;
  String? _lastRecurringPaymentId;
  String? _originalInstallmentPlanId;

  Future<void> _fetchOriginalExpense(String docId) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('expenses').doc(docId).get();
      if (doc.exists && mounted) {
        final originalExpense = ExpenseModel.fromFirestore(doc);
        setState(() {
          _selectedNature = originalExpense.nature;
          _selectedCategoryId = originalExpense.categoryId;
          try {
            final matchedCategory = _allCategories.firstWhere((cat) => cat['id'] == originalExpense.categoryId);
            _selectedParentCategory = matchedCategory['parentName']?.toString() ?? matchedCategory['parent']?.toString();
          } catch (e) {
            debugPrint('카테고리 매칭 실패: $e');
          }
          _isInstallment = originalExpense.installmentPlanId != null;
          if (_isInstallment && originalExpense.installmentTotalMonths != null) {
            _installmentMonths = originalExpense.installmentTotalMonths!;
          }
          _originalRecurringPaymentId = originalExpense.recurringPaymentId;
          _lastRecurringPaymentId = originalExpense.lastRecurringPaymentId ?? originalExpense.recurringPaymentId;
          _isRecurring = _originalRecurringPaymentId != null;
          _originalInstallmentPlanId = originalExpense.installmentPlanId;
        });
      }
    } catch (e) {
      debugPrint('원본 지출 내역 로드 실패: $e');
    }
  }

  // 💡 복합 색인 에러 방지를 위해 메모리 필터링 방식으로 개선
  Future<void> _loadCategoriesFromDB() async {
    final String userId = FirebaseAuth.instance.currentUser?.uid ?? '';
    try {
      final db = FirebaseFirestore.instance;
      final defaultSnap = await db.collection('categories').where('transactionType', isEqualTo: 'expense').get();
      // 에러의 주범이었던 where 체이닝 제거 -> 클라이언트(앱)에서 필터링
      final customSnap = await db.collection('customCategories').where('userId', isEqualTo: userId).get();

      List<String> hiddenIds = [];
      final userDoc = await db.collection('users').doc(userId).get();
      if (userDoc.exists && userDoc.data()!.containsKey('hiddenCategories')) {
        hiddenIds = List<String>.from(userDoc.data()!['hiddenCategories']);
      }

      List<Map<String, dynamic>> loaded = [];
      for (var doc in defaultSnap.docs) {
        if (!hiddenIds.contains(doc.id)) loaded.add({'id': doc.id, ...doc.data()});
      }
      for (var doc in customSnap.docs) {
        final data = doc.data();
        // 앱에서 직접 expense 타입만 골라냅니다.
        if (data['transactionType'] == 'expense' && data['isHidden'] != true) {
          loaded.add({'id': doc.id, ...data});
        }
      }

      if (!mounted) return;
      setState(() {
        _allCategories = loaded;
        _isLoadingCategories = false;
      });
    } catch (error) {
      debugPrint('카테고리 로드 오류: $error');
      if (!mounted) return;
      setState(() => _isLoadingCategories = false);
    }
  }

  void _onNatureChanged(ExpenseNature newNature) {
    setState(() {
      _selectedNature = newNature;
      _selectedParentCategory = null;
      _selectedCategoryId = null;

      if (newNature != ExpenseNature.variable) _selectedEmotion = null;
    });
  }

  Future<void> _saveExpense() async {
    if (_isSaving) return;
    if (_amountController.text.trim().isEmpty || _selectedCategoryId == null) {
      await DdaengModal.alert(
        context,
        title: '입력 내용을 확인해 주세요',
        message: '금액과 소분류 카테고리를 모두 선택해 주세요.',
        type: ModalType.warning,
      );
      return;
    }
    if (_selectedNature == ExpenseNature.variable && _selectedEmotion == null) {
      await DdaengModal.alert(
        context,
        title: '감정 태그를 선택해 주세요',
        message: '변동비 지출에는 감정 태그가 필요합니다.',
        type: ModalType.warning,
      );
    }

    final User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      await DdaengModal.alert(
        context,
        title: '로그인이 필요해요',
        message: '로그인 후 다시 시도해 주세요.',
        type: ModalType.warning,
      );
      return;
    }

    // 공용 함수가 쉼표가 포함된 입력값을 안전하게 숫자로 변환합니다.
    final int amount = parseAmount(_amountController.text);
    if (amount <= 0) {
      await DdaengModal.alert(
        context,
        title: '금액을 확인해 주세요',
        message: '0원보다 큰 지출 금액을 입력해 주세요.',
        type: ModalType.warning,
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final String userId = currentUser.uid;

      String? recurringPaymentId = _originalRecurringPaymentId;
      String? lastRecurringPaymentId = _lastRecurringPaymentId;
      final recurringService = RecurringPaymentService();

      if (_isRecurring) {
        if (recurringPaymentId != null) {
          // 이미 활성 상태 — 최신 정보만 갱신
          await recurringService.updateRecurringPayment(recurringPaymentId, {
            'name': _memoController.text.trim().isNotEmpty ? _memoController.text.trim() : '정기결제',
            'amount': amount,
            'categoryId': _selectedCategoryId!,
          });
        } else if (lastRecurringPaymentId != null) {
          // 되살리기 — nextBillingDate는 건드리지 않아 기존 청구일 그대로 유지
          await recurringService.updateRecurringPayment(lastRecurringPaymentId, {
            'isDeleted': false,
            'deletedAt': null,
            'name': _memoController.text.trim().isNotEmpty ? _memoController.text.trim() : '정기결제',
            'amount': amount,
            'categoryId': _selectedCategoryId!,
          });
          recurringPaymentId = lastRecurringPaymentId;
        } else {
          // 완전 신규 생성
          final nextBillingDate = DateTime(_selectedDate.year, _selectedDate.month + 1, _selectedDate.day);
          recurringPaymentId = await recurringService.addRecurringPayment(
            RecurringPaymentModel(
              recurringPaymentId: '',
              userId: userId,
              name: _memoController.text.trim().isNotEmpty ? _memoController.text.trim() : '정기결제',
              amount: amount,
              billingCycle: BillingCycle.monthly,
              nextBillingDate: nextBillingDate,
              categoryId: _selectedCategoryId!,
            ),
          );
        }
        lastRecurringPaymentId = recurringPaymentId;
      } else if (recurringPaymentId != null) {
        await recurringService.deleteRecurringPayment(recurringPaymentId);
        recurringPaymentId = null;
      }

      // 할부 계획 ID 계산 — 이 지출 자기 자신의 문서 ID를 재사용해서
      // 최소한 서로 다른 할부 구매끼리는 절대 겹치지 않도록 한다.
      // (TODO: installmentPlans 전용 컬렉션 도입은 별도 확장 과제로 남겨둠 — 지금은 회차/총액 조회 UI가 없어 불필요)
      String? installmentPlanId = _isInstallment ? _originalInstallmentPlanId : null;

      if (widget.editItem == null) {
        // 신규 저장 — expenseId를 아직 몰라서 할부인 경우 저장 후 한 번 더 갱신한다.
        final newExpense = ExpenseModel(
          expenseId: '',
          userId: userId,
          amount: amount,
          categoryId: _selectedCategoryId!,
          date: _selectedDate,
          memo: _memoController.text.trim(),
          nature: _selectedNature,
          emotionTag: _selectedNature == ExpenseNature.variable ? _selectedEmotion : null,
          installmentPlanId: null,
          installmentInstallmentNo: _isInstallment ? 1 : null,
          installmentTotalMonths: _isInstallment ? _installmentMonths : null,
          recurringPaymentId: recurringPaymentId,
          lastRecurringPaymentId: lastRecurringPaymentId,
        );

        final newExpenseId = await _expenseService.addExpense(newExpense);

        if (_isInstallment && installmentPlanId == null) {
          installmentPlanId = newExpenseId;
          await _expenseService.updateExpense(newExpenseId, {
            'installmentPlanId': installmentPlanId,
          });
        }
      } else {
        final String? installmentPlanId = _isInstallment
            ? (_originalInstallmentPlanId ?? widget.editItem!.id)
            : null;

        final updatedExpense = ExpenseModel(
          expenseId: widget.editItem!.id,
          userId: userId,
          amount: amount,
          categoryId: _selectedCategoryId!,
          date: _selectedDate,
          memo: _memoController.text.trim(),
          nature: _selectedNature,
          emotionTag: _selectedNature == ExpenseNature.variable ? _selectedEmotion : null,
          installmentPlanId: installmentPlanId,
          installmentInstallmentNo: _isInstallment ? 1 : null,
          installmentTotalMonths: _isInstallment ? _installmentMonths : null,
          recurringPaymentId: recurringPaymentId,
          lastRecurringPaymentId: lastRecurringPaymentId,
        );

        await _expenseService.updateExpense(widget.editItem!.id, updatedExpense.toFirestore());
      }

      if (!mounted) return;
      await DdaengModal.alert(
        context,
        title: widget.editItem == null
            ? '지출 내역을 저장했어요'
            : '지출 내역을 수정했어요',
        type: ModalType.success,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (error) {
      debugPrint('지출 저장 오류: $error');
      if (!mounted) return;
      await DdaengModal.alert(
        context,
        title: '지출 내역을 저장하지 못했어요',
        message: '$error',
        type: ModalType.danger,
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  void dispose() {
    _amountController.removeListener(_refreshAmount);
    _amountController.dispose();
    _memoController.dispose();
    super.dispose();
  }

  // ─────────────────────── 스타일 헬퍼 ───────────────────────

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

  Widget _sectionLabel(String text, {IconData? icon, Color? iconColor, Color? iconBg, Widget? trailing}) {
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
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: AppColors.ink),
          ),
        ),
        if (trailing != null) trailing,
      ],
    );
  }

  InputDecoration _fieldDecoration({String? label, String? hint, String? prefixText}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixText: prefixText,
      filled: true,
      fillColor: Color(0xFFF7F7F9),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.expense, width: 1.6),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final natureFilteredCategories = _allCategories.where((category) {
      // 💡 커스텀 카테고리도 성격(nature)에 맞게 잘 뜨도록 보강
      String dbNature = (category['nature'] ?? 'variable').toString().toLowerCase();
      if (dbNature.isEmpty || dbNature == 'null') dbNature = 'variable';
      return dbNature.contains(_selectedNature.name.toLowerCase());
    }).toList();

    final List<String> parentCategories = natureFilteredCategories
        .map((category) => (category['parentName'] ?? category['parent'] ?? '미분류').toString())
        .toSet()
        .toList();

    final List<Map<String, dynamic>> childCategories = _selectedParentCategory == null
        ? []
        : natureFilteredCategories.where((category) {
      final parent = category['parentName'] ?? category['parent'] ?? '미분류';
      return parent == _selectedParentCategory;
    }).toList();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text(
          widget.editItem == null ? '지출 기록' : '지출 수정',
          style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.ink),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.calculate_outlined),
            tooltip: '금액 계산기',
            onPressed: () async {
              final result = await showAmountCalculatorSheet(
                context,
                initialAmount: parseAmount(_amountController.text),
              );
              if (result != null) {
                _amountController.text = comma(result);
              }
            },
          ),
        ],
      ),
      body: _isLoadingCategories
          ? const Center(child: CircularProgressIndicator(color: AppColors.expense))
          : SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── 결제 금액 입력 카드 ──
            //
            // 기존의 강한 그라데이션 카드 대신,
            // 실제 입력창처럼 보이는 밝은 배경 + 테두리 방식으로 변경했습니다.
            //
            // 동작:
            // 1. 입력 전에는 0원만 표시
            // 2. 숫자 입력 시 천 단위 쉼표 자동 적용
            // 3. 1원 이상 입력했을 때만 아래에 한글 금액 자막 표시
            // 4. 입력값을 모두 지우면 자막도 다시 사라짐
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7F2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: const Color(0xFFFFD7C7),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF8A65).withValues(alpha: 0.08),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 입력 카드 제목
                  const Row(
                    children: [
                      Icon(
                        Icons.payments_outlined,
                        size: 18,
                        color: AppColors.expenseDeep,
                      ),
                      SizedBox(width: 7),
                      Text(
                        '결제 금액',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: AppColors.expenseDeep,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // 실제 금액 입력 영역
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(
                        color: const Color(0xFFFFE2D6),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _amountController,
                            enabled: !_isSaving,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              // 입력과 동시에 천 단위 쉼표를 표시합니다.
                              CurrencyFormatter(),
                            ],
                            textAlign: TextAlign.right,
                            style: const TextStyle(
                              fontSize: 30,
                              height: 1.15,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.8,
                              color: AppColors.ink,
                            ),
                            cursorColor: AppColors.expense,
                            decoration: const InputDecoration(
                              // 실제 컨트롤러 값은 비어 있지만
                              // 화면에는 0이 보이도록 처리합니다.
                              hintText: '0',
                              hintStyle: TextStyle(
                                fontSize: 30,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFFB8BFC8),
                              ),
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              disabledBorder: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ),
                        const SizedBox(width: 5),
                        ValueListenableBuilder<TextEditingValue>(
                          valueListenable: _amountController,
                          builder: (context, value, _) {
                            final int amount = int.tryParse(
                              value.text.replaceAll(',', '').trim(),
                            ) ??
                                0;

                            return Text(
                              '원',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                color: amount > 0
                                    ? AppColors.ink
                                    : const Color(0xFFB8BFC8),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),

                  // 숫자가 입력됐을 때만 한글 금액 자막을 표시합니다.
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _amountController,
                    builder: (context, value, _) {
                      final int amount = int.tryParse(
                        value.text.replaceAll(',', '').trim(),
                      ) ??
                          0;

                      if (amount <= 0) {
                        return const SizedBox.shrink();
                      }

                      final String label = koreanAmountText(amount);
                      final String spokenAmount = koreanAmount(amount);

                      if (label.isEmpty) {
                        return const SizedBox.shrink();
                      }

                      return AnimatedSwitcher(
                        duration: const Duration(milliseconds: 180),
                        switchInCurve: Curves.easeOut,
                        switchOutCurve: Curves.easeIn,
                        child: Padding(
                          key: ValueKey<int>(amount),
                          padding: const EdgeInsets.only(top: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Align(
                                alignment: Alignment.centerRight,
                                child: Text(
                                  label,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.expenseDeep,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                spokenAmount,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.expenseDeep,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── 지출 성격 ──
            _sectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionLabel('지출 성격',
                      icon: Icons.category_rounded,
                      iconColor: AppColors.expenseDeep,
                      iconBg: AppColors.expense.withValues(alpha: 0.15)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _natureChip('고정비', ExpenseNature.fixed),
                      _natureChip('변동비', ExpenseNature.variable),
                      _natureChip('기타 (경조사 등)', ExpenseNature.other),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── 대분류 / 소분류 ──
            _sectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionLabel('대분류',
                      icon: Icons.folder_outlined,
                      iconColor: AppColors.utility,
                      iconBg: AppColors.utilitySoft),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: parentCategories.contains(_selectedParentCategory) ? _selectedParentCategory : null,
                    hint: const Text('대분류 선택', style: TextStyle(color: AppColors.inkSub)),
                    decoration: _fieldDecoration(),
                    borderRadius: BorderRadius.circular(14),
                    dropdownColor: Colors.white,
                    items: parentCategories.map((parentName) {
                      return DropdownMenuItem<String>(value: parentName, child: Text(parentName));
                    }).toList(),
                    onChanged: _isSaving || parentCategories.isEmpty
                        ? null
                        : (newParent) {
                      setState(() {
                        _selectedParentCategory = newParent;
                        _selectedCategoryId = null;
                      });
                    },
                  ),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 280),
                    curve: Curves.easeOutCubic,
                    alignment: Alignment.topCenter,
                    child: _selectedParentCategory == null
                        ? const SizedBox.shrink()
                        : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 20),
                        _sectionLabel(
                          '소분류',
                          icon: Icons.subdirectory_arrow_right_rounded,
                          iconColor: AppColors.utility,
                          iconBg: AppColors.utilitySoft,
                          trailing: IconButton(
                            visualDensity: VisualDensity.compact,
                            icon: const Icon(Icons.add_circle_outline, size: 20, color: AppColors.utility),
                            tooltip: '소분류 추가',
                            onPressed: () async {
                              final newId = await showAddSubCategoryDialog(
                                context,
                                transactionType: 'expense',
                                parentName: _selectedParentCategory!,
                                nature: _selectedNature.name,
                              );
                              if (newId != null) {
                                await _loadCategoriesFromDB();
                                if (mounted) setState(() => _selectedCategoryId = newId);
                              }
                            },
                          ),
                        ),
                        const SizedBox(height: 10),
                        DropdownButtonFormField<String>(
                          value: childCategories.any((category) => category['id'] == _selectedCategoryId)
                              ? _selectedCategoryId
                              : null,
                          hint: const Text('소분류 선택', style: TextStyle(color: AppColors.inkSub)),
                          decoration: _fieldDecoration(),
                          borderRadius: BorderRadius.circular(14),
                          dropdownColor: Colors.white,
                          items: childCategories.map((categoryData) {
                            return DropdownMenuItem<String>(
                              value: categoryData['id']?.toString(),
                              child: Text(categoryData['name']?.toString() ?? '이름 없음'),
                            );
                          }).toList(),
                          onChanged: _isSaving || childCategories.isEmpty
                              ? null
                              : (newId) {
                            setState(() => _selectedCategoryId = newId);
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            if (_selectedNature == ExpenseNature.variable) ...[
              const SizedBox(height: 16),
              _sectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionLabel('감정 태그',
                        icon: Icons.favorite_rounded,
                        iconColor: AppColors.pink,
                        iconBg: AppColors.pinkSoft),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _emotionTags.map((tag) {
                        final selected = _selectedEmotion == tag;
                        return ChoiceChip(
                          label: Text(tag),
                          selected: selected,
                          onSelected: _isSaving
                              ? null
                              : (isSelected) {
                            setState(() => _selectedEmotion = isSelected ? tag : null);
                          },
                          selectedColor: AppColors.pink,
                          backgroundColor: AppColors.pinkSoft,
                          labelStyle: TextStyle(
                            color: selected ? Colors.white : AppColors.pink,
                            fontWeight: FontWeight.w700,
                            fontSize: 12.5,
                          ),
                          side: BorderSide.none,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: BorderSide.none,
                          ),
                          showCheckmark: false,
                          elevation: 0,
                          pressElevation: 0,
                          shadowColor: Colors.transparent,
                          surfaceTintColor: Colors.transparent,
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 16),

            // ── 부가 기능 연결 ──
            _sectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionLabel('부가 기능 연결 (옵션)',
                      icon: Icons.settings_suggest_outlined,
                      iconColor: AppColors.purple, // _C에 purple이 없으면 아래 참고
                      iconBg: const Color(0xFFEDE9FE)),
                  const SizedBox(height: 4),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('할부 결제인가요?',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.ink)),
                    subtitle: const Text('무이자 균등금액으로 분할 기록됩니다.',
                        style: TextStyle(fontSize: 12, color: AppColors.inkSub)),
                    value: _isInstallment,
                    activeColor: AppColors.expense,
                    inactiveThumbColor: Colors.white,
                    inactiveTrackColor: const Color(0xFFE5E8EB),
                    trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
                    onChanged: _isSaving
                        ? null
                        : (value) {
                      setState(() {
                        _isInstallment = value;
                        if (value) _isRecurring = false;
                      });
                    },
                  ),
                  if (_isInstallment) ...[
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF4E5),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.info_outline, size: 15, color: Color(0xFFB45309)),
                          SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '위 "결제 금액"에는 카드사 총 결제금액(할부 원금)을 입력해주세요.\n월 납입액이 아니에요! 월 납입액은 아래에서 자동으로 계산돼요.',
                              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFFB45309)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          const Text('할부 개월 수:',
                              style: TextStyle(fontSize: 13, color: AppColors.inkSub)),
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: DropdownButton<int>(
                              value: _installmentMonths,
                              underline: const SizedBox.shrink(),
                              dropdownColor: Colors.white,
                              items: const [2, 3, 4, 5, 6, 10, 12, 24].map((value) {
                                return DropdownMenuItem<int>(value: value, child: Text('$value개월'));
                              }).toList(),
                              onChanged: _isSaving
                                  ? null
                                  : (newValue) {
                                if (newValue != null) setState(() => _installmentMonths = newValue);
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    ValueListenableBuilder<TextEditingValue>(
                      valueListenable: _amountController,
                      builder: (context, value, _) {
                        final int totalAmount = parseAmount(value.text);
                        if (totalAmount <= 0) return const SizedBox.shrink();
                        final int monthlyAmount = (totalAmount / _installmentMonths).round();
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            '총 ${comma(totalAmount)}원 ÷ $_installmentMonths개월 = 월 ${comma(monthlyAmount)}원',
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.expenseDeep,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                  const Divider(height: 20, color: Color(0xFFF0EDF5)),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('매월 반복되는 정기결제/구독인가요?',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.ink)),
                    subtitle: const Text('다음 달부터 자동으로 내역이 생성됩니다.',
                        style: TextStyle(fontSize: 12, color: AppColors.inkSub)),
                    value: _isRecurring,
                    activeColor: AppColors.expense,
                    inactiveThumbColor: Colors.white,
                    inactiveTrackColor: const Color(0xFFE5E8EB),
                    trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
                    onChanged: _isSaving
                        ? null
                        : (value) {
                      setState(() {
                        _isRecurring = value;
                        if (value) _isInstallment = false;
                      });
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── 날짜 / 메모 ──
            _sectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 26,
                            height: 26,
                            decoration: BoxDecoration(
                              color: AppColors.utilitySoft,
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: const Icon(Icons.event_rounded, size: 14, color: AppColors.utility),
                          ),
                          const SizedBox(width: 8),
                          Text('결제일: ${_selectedDate.toLocal().toString().split(' ')[0]}',
                              style: const TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.ink)),
                        ],
                      ),
                      InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: _isSaving
                            ? null
                            : () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _selectedDate,
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                            builder: (context, child) {
                              return Theme(
                                data: Theme.of(context).copyWith(
                                  colorScheme: const ColorScheme.light(
                                    primary: AppColors.expense,        // 선택된 날짜 배경, 상단 헤더
                                    onPrimary: Colors.white,  // 선택된 날짜 글씨
                                    onSurface: AppColors.ink,        // 기본 날짜 글씨
                                  ),
                                  textButtonTheme: TextButtonThemeData(
                                    style: TextButton.styleFrom(
                                      foregroundColor: AppColors.expenseDeep, // Cancel/OK 버튼 글씨
                                    ),
                                  ),
                                ),
                                child: child!,
                              );
                            },
                          );
                          if (picked != null && mounted) setState(() => _selectedDate = picked);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppColors.utilitySoft,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text('날짜 변경',
                              style: TextStyle(
                                  fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.utility)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _memoController,
                    enabled: !_isSaving,
                    style: const TextStyle(fontSize: 14, color: AppColors.ink),
                    decoration: _fieldDecoration(hint: '메모 (선택)'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // ── 저장 버튼 ──
            SizedBox(
              height: 56,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.ink,
                  disabledBackgroundColor: const Color(0xFFE5E8EB),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: _isSaving ? null : _saveExpense,
                child: _isSaving
                    ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                )
                    : const Text('저장하기', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _natureChip(String label, ExpenseNature nature) {
    final selected = _selectedNature == nature;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: _isSaving ? null : (_) => _onNatureChanged(nature),
      selectedColor: AppColors.expense,
      backgroundColor: AppColors.bg,
      labelStyle: TextStyle(
        color: selected ? Colors.white : AppColors.expenseDeep,
        fontWeight: FontWeight.w700,
        fontSize: 12.5,
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
}
