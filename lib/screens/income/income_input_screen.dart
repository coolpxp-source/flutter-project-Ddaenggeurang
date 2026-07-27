import 'package:flutter/material.dart';
import '../../utils/app_colors.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../utils/formatters.dart';
import '../../models/income_model.dart';
import '../../services/income_service.dart';
import '../../models/transaction_item.dart';
import '../../widgets/common/ddaeng_modal.dart';
import '../../widgets/common/amount_calculator_sheet.dart';
import '../../utils/korean_amount.dart';

/// expense_input_screen.dart와 통일한 팔레트.

class IncomeInputScreen extends StatefulWidget {
  final TransactionItem? editItem;
  const IncomeInputScreen({super.key, this.editItem});

  @override
  State<IncomeInputScreen> createState() => _IncomeInputScreenState();
}

class _IncomeInputScreenState extends State<IncomeInputScreen> {
  final TextEditingController _amountController = TextEditingController(text: '0');
  final TextEditingController _memoController = TextEditingController();
  final IncomeService _incomeService = IncomeService();

  DateTime _selectedDate = DateTime.now();

  List<Map<String, dynamic>> _incomeCategories = [];
  bool _isLoadingCategories = true;

  String? _selectedParentCategory;
  String? _selectedCategoryId;
  String? _selectedCategoryName;

  bool _isRecurring = false;
  int _payDay = 1;
  int _currentAmount = 0;

  @override
  void initState() {
    super.initState();
    _loadCategories();

    if (widget.editItem != null) {
      final item = widget.editItem!;
      _amountController.text = item.amount.toString();
      _selectedDate = item.date;
      if (item.subtitle != null) _memoController.text = item.subtitle!;
      _currentAmount = item.amount;
    }

    _amountController.addListener(() {
      final text = _amountController.text.replaceAll(',', '');
      setState(() => _currentAmount = int.tryParse(text) ?? 0);
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    _memoController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    final String userId = FirebaseAuth.instance.currentUser?.uid ?? 'test_user_id';
    try {
      final db = FirebaseFirestore.instance;
      final defaultSnap = await db.collection('categories').where('transactionType', isEqualTo: 'income').get();
      // 💡 복합 색인 에러 방지용 메모리 필터링
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
        if (data['transactionType'] == 'income' && data['isHidden'] != true) {
          loaded.add({'id': doc.id, ...data});
        }
      }

      setState(() {
        _incomeCategories = loaded;
        _isLoadingCategories = false;

        if (widget.editItem != null && _incomeCategories.isNotEmpty) {
          final matched = _incomeCategories.firstWhere(
                (c) => c['name'] == widget.editItem!.title,
            orElse: () => _incomeCategories.first,
          );
          _selectedCategoryId = matched['id'];
          _selectedCategoryName = matched['name'];
          _selectedParentCategory = matched['parentName']?.toString() ?? matched['parent']?.toString() ?? '미분류';
        }
      });
    } catch (e) {
      debugPrint('카테고리 로드 에러: $e');
      setState(() => _isLoadingCategories = false);
    }
  }

  Future<void> _saveIncome() async {
    if (_currentAmount <= 0) {
      await DdaengModal.alert(context, title: '입력을 확인해주세요', message: '수입 금액을 입력해주세요!', type: ModalType.warning);
      return;
    }
    if (_selectedCategoryId == null) {
      await DdaengModal.alert(context, title: '입력을 확인해주세요', message: '소분류 카테고리를 선택해주세요!', type: ModalType.warning);
      return;
    }

    try {
      final String userId = FirebaseAuth.instance.currentUser?.uid ?? 'test_user_id';
      final String? recurringTemplateId = _isRecurring ? 'temp_recurring_income_id' : null;

      final newIncome = IncomeModel(
        incomeId: widget.editItem != null ? widget.editItem!.id : '',
        userId: userId,
        amount: _currentAmount,
        categoryId: _selectedCategoryId!,
        date: _selectedDate,
        memo: _memoController.text,
        recurringIncomeTemplateId: recurringTemplateId,
      );

      if (widget.editItem == null) {
        await _incomeService.addIncome(newIncome);
      } else {
        await _incomeService.updateIncome(widget.editItem!.id, newIncome.toFirestore());
      }

      if (!mounted) return;
      await DdaengModal.alert(context, title: '저장 완료', message: '수입 내역이 저장되었습니다!', type: ModalType.success);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      debugPrint('🔥 저장 에러: $e');
      if (!mounted) return;
      await DdaengModal.alert(context, title: '저장에 실패했어요', message: '$e', type: ModalType.danger);
    }
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

  Widget _sectionLabel(String text, {IconData? icon, Color? iconColor, Color? iconBg}) {
    return Row(
      children: [
        if (icon != null) ...[
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: iconBg ?? AppColors.incomeSoft,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 14, color: iconColor ?? AppColors.income),
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

  InputDecoration _fieldDecoration({String? label, String? hint, String? prefixText}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixText: prefixText,
      filled: true,
      fillColor: const Color(0xFFF7F7F9),
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
        borderSide: const BorderSide(color: AppColors.income, width: 1.6),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double estimatedGross = _currentAmount / 0.967;

    final List<String> parentCategories = _incomeCategories
        .map((category) => (category['parentName'] ?? category['parent'] ?? '미분류').toString())
        .toSet()
        .toList();

    final List<Map<String, dynamic>> childCategories = _selectedParentCategory == null
        ? []
        : _incomeCategories.where((category) {
      final parent = category['parentName'] ?? category['parent'] ?? '미분류';
      return parent == _selectedParentCategory;
    }).toList();

    // 💡 핵심: 대분류 이름에 '정기' 문자가 포함되어 있으면 정기수입으로 간주
    final bool isRegularIncome = _selectedParentCategory != null && _selectedParentCategory!.contains('정기');

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text('수입 기록', style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.ink)),
        actions: [
          IconButton(
            icon: const Icon(Icons.calculate_outlined),
            tooltip: '금액 계산기',
            onPressed: () async {
              final result = await showAmountCalculatorSheet(
                context,
                initialAmount: _currentAmount,
              );
              if (result != null) {
                _amountController.text = comma(result);
              }
            },
          ),
        ],
      ),
      body: _isLoadingCategories
          ? const Center(child: CircularProgressIndicator(color: AppColors.income))
          : SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── 실수령액 히어로 카드 ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF34D399), Color(0xFF10B981)],
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF10B981).withValues(alpha: 0.3),
                    blurRadius: 24,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '실수령액 (세후 금액)',
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
                  if (_currentAmount > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          koreanAmountText(_currentAmount),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.white.withValues(alpha: 0.85),
                          ),
                        ),
                      ),
                    ),
                  if (_currentAmount > 0)
                    Text(
                      koreanAmount(_currentAmount),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  if (_selectedCategoryName == '프리랜서' && _currentAmount > 0) ...[
                    const SizedBox(height: 10),
                    Text(
                      '약 ${NumberFormat('#,###').format(estimatedGross)}원 (세전 추정)',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: Colors.white.withValues(alpha: 0.95),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── 대분류 / 소분류 ──
            _sectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionLabel('대분류',
                      icon: Icons.folder_outlined, iconColor: AppColors.utility, iconBg: AppColors.utilitySoft),
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
                    onChanged: parentCategories.isEmpty ? null : (newParent) {
                      setState(() {
                        _selectedParentCategory = newParent;
                        _selectedCategoryId = null;
                        _selectedCategoryName = null;

                        // 💡 대분류가 정기수입이 아니면 스위치 끄기
                        if (newParent == null || !newParent.contains('정기')) {
                          _isRecurring = false;
                        }
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
                        _sectionLabel('소분류',
                            icon: Icons.subdirectory_arrow_right_rounded, iconColor: AppColors.utility, iconBg: AppColors.utilitySoft),
                        const SizedBox(height: 10),
                        DropdownButtonFormField<String>(
                          value: childCategories.any((category) => category['id'] == _selectedCategoryId) ? _selectedCategoryId : null,
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
                          onChanged: childCategories.isEmpty ? null : (newId) {
                            setState(() {
                              _selectedCategoryId = newId;
                              _selectedCategoryName = childCategories.firstWhere((c) => c['id'] == newId)['name'];
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // 💡 대분류가 '정기수입'일 때만 부가 기능 표시!
            if (isRegularIncome) ...[
              const SizedBox(height: 16),
              _sectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionLabel('부가 기능 연결 (옵션)',
                        icon: Icons.settings_suggest_outlined,
                        iconColor: const Color(0xFF6C5CE7),
                        iconBg: const Color(0xFFEDE9FE)),
                    const SizedBox(height: 4),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('매달 자동으로 기록하기',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.ink)),
                      subtitle: const Text('매월 설정한 날짜에 자동으로 내역이 생성됩니다.',
                          style: TextStyle(fontSize: 12, color: AppColors.inkSub)),
                      value: _isRecurring,
                      activeColor: AppColors.income,
                      inactiveThumbColor: Colors.white,
                      inactiveTrackColor: const Color(0xFFE5E8EB),
                      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
                      onChanged: (bool value) => setState(() => _isRecurring = value),
                    ),
                    if (_isRecurring)
                      Row(
                        children: [
                          const Text('매월 입금일:', style: TextStyle(fontSize: 13, color: AppColors.inkSub)),
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: Color(0xFFF7F7F9),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: DropdownButton<int>(
                              value: _payDay,
                              underline: const SizedBox.shrink(),
                              dropdownColor: Colors.white,
                              items: List.generate(31, (index) => index + 1).map((int day) {
                                return DropdownMenuItem<int>(value: day, child: Text('$day일'));
                              }).toList(),
                              onChanged: (int? newDay) {
                                if (newDay != null) setState(() => _payDay = newDay);
                              },
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ],
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
                          Text('입금일: ${_selectedDate.toLocal().toString().split(' ')[0]}',
                              style: const TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.ink)),
                        ],
                      ),
                      InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () async {
                          final DateTime? picked = await showDatePicker(
                            context: context,
                            initialDate: _selectedDate,
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                            builder: (context, child) {
                              return Theme(
                                data: Theme.of(context).copyWith(
                                  colorScheme: const ColorScheme.light(
                                    primary: AppColors.income,
                                    onPrimary: Colors.white,
                                    onSurface: AppColors.ink,
                                  ),
                                  textButtonTheme: TextButtonThemeData(
                                    style: TextButton.styleFrom(foregroundColor: AppColors.income),
                                  ),
                                ),
                                child: child!,
                              );
                            },
                          );
                          if (picked != null) setState(() => _selectedDate = picked);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppColors.utilitySoft,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text('날짜 변경',
                              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.utility)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _memoController,
                    style: const TextStyle(fontSize: 14, color: AppColors.ink),
                    decoration: _fieldDecoration(label: '메모 (선택)'),
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
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: _saveIncome,
                child: const Text('저장하기', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}