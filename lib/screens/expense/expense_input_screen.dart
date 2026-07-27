import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
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
  final _amountController = TextEditingController(text: '0');
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
  bool _isRecurring = false;
  bool _isTravel = false;

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
          _isRecurring = originalExpense.recurringPaymentId != null;
          _isTravel = originalExpense.travelId != null;
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
      if (newNature == ExpenseNature.fixed) _isTravel = false;
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
      final newExpense = ExpenseModel(
        expenseId: widget.editItem != null ? widget.editItem!.id : '',
        userId: userId,
        amount: amount,
        categoryId: _selectedCategoryId!,
        date: _selectedDate,
        memo: _memoController.text.trim(),
        nature: _selectedNature,
        emotionTag: _selectedNature == ExpenseNature.variable ? _selectedEmotion : null,
        installmentPlanId: _isInstallment ? 'temp_install_id' : null,
        installmentInstallmentNo: _isInstallment ? 1 : null,
        installmentTotalMonths: _isInstallment ? _installmentMonths : null,
        recurringPaymentId: _isRecurring ? 'temp_recur_id' : null,
        travelId: _isTravel ? 'temp_travel_id' : null,
      );

      if (widget.editItem == null) {
        await _expenseService.addExpense(newExpense);
      } else {
        await _expenseService.updateExpense(widget.editItem!.id, newExpense.toFirestore());
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
            // ── 결제 금액 히어로 카드 ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFFFC168), Color(0xFFFF7A45), Color(0xFFFF5C7A)],
                  stops: [0.0, 0.55, 1.0],
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF6A66).withValues(alpha: 0.35),
                    blurRadius: 24,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '결제 금액',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      IntrinsicWidth(
                        child: TextField(
                          controller: _amountController,
                          enabled: !_isSaving,
                          keyboardType: TextInputType.number,
                          inputFormatters: [CurrencyFormatter()],
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                          cursorColor: Colors.white,
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '원',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                  ),
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _amountController,
                    builder: (context, value, _) {
                      final amount =
                          int.tryParse(value.text.replaceAll(',', '')) ?? 0;
                      final label = koreanAmountText(amount);
                      if (label.isEmpty) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            label,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Colors.white.withValues(alpha: 0.85),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 6),
                  // 숫자로 입력한 금액을 한글로 함께 보여 줍니다.
                  Text(
                    koreanAmount(
                      parseAmount(_amountController.text),
                    ),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
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
                  if (_isInstallment)
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
                  const Divider(height: 20, color: Color(0xFFF0EDF5)),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('매월 반복되는 정기결제/구독인가요?',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.ink)),
                    subtitle: _isTravel
                        ? const Text('여행 지출은 정기결제로 설정할 수 없습니다.',
                        style: TextStyle(fontSize: 12, color: AppColors.expenseNegative))
                        : const Text('다음 달부터 자동으로 내역이 생성됩니다.',
                        style: TextStyle(fontSize: 12, color: AppColors.inkSub)),
                    value: _isRecurring,
                    activeColor: AppColors.expense,
                    inactiveThumbColor: Colors.white,
                    inactiveTrackColor: const Color(0xFFE5E8EB),
                    trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
                    onChanged: _isSaving || _isTravel
                        ? null
                        : (value) {
                      setState(() {
                        _isRecurring = value;
                        if (value) _isInstallment = false;
                      });
                    },
                  ),
                  const Divider(height: 20, color: Color(0xFFF0EDF5)),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('현재 진행 중인 여행 지출인가요?',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.ink)),
                    subtitle: _isRecurring
                        ? const Text('정기결제는 여행 지출로 설정할 수 없습니다.',
                        style: TextStyle(fontSize: 12, color: AppColors.expenseNegative))
                        : (_selectedNature == ExpenseNature.fixed
                        ? const Text('고정비는 여행 지출로 태깅할 수 없습니다.',
                        style: TextStyle(fontSize: 12, color: AppColors.expenseNegative))
                        : const Text('진행 중인 여행 예산에 포함됩니다.',
                        style: TextStyle(fontSize: 12, color: AppColors.inkSub))),
                    value: _isTravel,
                    activeColor: AppColors.expense,
                    inactiveThumbColor: Colors.white,
                    inactiveTrackColor: const Color(0xFFE5E8EB),
                    trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
                    onChanged: _isSaving || _isRecurring || _selectedNature == ExpenseNature.fixed
                        ? null
                        : (value) {
                      setState(() {
                        _isTravel = value;
                        if (value) _isRecurring = false;
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