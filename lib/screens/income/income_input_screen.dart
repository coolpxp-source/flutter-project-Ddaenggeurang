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
import '../../widgets/common/add_subcategory_dialog.dart';
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
  bool _categoryMatchFailed = false;

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
      _fetchOriginalIncome(item.id);
    }

    _amountController.addListener(() {
      final text = _amountController.text.replaceAll(',', '');
      setState(() => _currentAmount = int.tryParse(text) ?? 0);
    });
  }

  String? _originalRecurringPaymentId;
  String? _lastRecurringPaymentId;

  Future<void> _fetchOriginalIncome(String docId) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('incomes').doc(docId).get();
      if (!doc.exists || !mounted) return;

      final original = IncomeModel.fromFirestore(doc);
      final String? lastId =
          original.lastRecurringIncomeTemplateId ?? original.recurringIncomeTemplateId;

      int? restoredPayDay = original.recurringPayDay;

      // 꺼져있는 상태(recurringIncomeTemplateId == null)라도 lastId가 있으면
      // 그 템플릿 문서에서 payDay를 직접 읽어와 되살릴 값으로 미리 채워둔다.
      if (original.recurringIncomeTemplateId == null && lastId != null) {
        final templateDoc = await FirebaseFirestore.instance
            .collection('recurringIncomeTemplates')
            .doc(lastId)
            .get();
        if (templateDoc.exists) {
          restoredPayDay = (templateDoc.data()?['payDay'] as num?)?.toInt();
        }
      }

      if (!mounted) return;
      setState(() {
        _originalRecurringPaymentId = original.recurringIncomeTemplateId;
        _lastRecurringPaymentId = lastId;
        _isRecurring = _originalRecurringPaymentId != null;
        if (restoredPayDay != null) {
          _payDay = restoredPayDay!;
        }
      });
    } catch (e) {
      debugPrint('원본 수입 내역 로드 실패: $e');
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _memoController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    final String? userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      setState(() => _isLoadingCategories = false);
      return;
    }
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
          final matches = _incomeCategories.where((c) => c['id'] == widget.editItem!.categoryId).toList();
          if (matches.isNotEmpty) {
            final matched = matches.first;
            _selectedCategoryId = matched['id'];
            _selectedCategoryName = matched['name'];
            _selectedParentCategory = matched['parentName']?.toString() ?? matched['parent']?.toString() ?? '미분류';
          } else {
            // 매칭되는 카테고리가 없으면(삭제·이름변경 등) 엉뚱한 카테고리로
            // 조용히 대체하지 않고, 사용자가 직접 다시 선택하도록 비워둠
            _categoryMatchFailed = true;
          }
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

    try {
      final String userId = currentUser.uid;

      String? recurringTemplateId = _originalRecurringPaymentId;
      String? lastRecurringTemplateId = _lastRecurringPaymentId;

      if (_isRecurring) {
        if (recurringTemplateId != null) {
          await _incomeService.updateRecurringTemplate(recurringTemplateId, {
            'amount': _currentAmount,
            'categoryId': _selectedCategoryId!,
            'payDay': _payDay,
            'memo': _memoController.text.trim(),
          });
        } else if (lastRecurringTemplateId != null) {
          // 🔁 되살리기 — startDate는 건드리지 않아 원래 시작일 그대로 유지,
          // payDay는 위에서 이미 복구해둔 값을 그대로 다시 저장
          await _incomeService.updateRecurringTemplate(lastRecurringTemplateId, {
            'isDeleted': false,
            'deletedAt': null,
            'isActive': true,
            'amount': _currentAmount,
            'categoryId': _selectedCategoryId!,
            'payDay': _payDay,
            'memo': _memoController.text.trim(),
          });
          recurringTemplateId = lastRecurringTemplateId;
        } else {
          recurringTemplateId = await _incomeService.addRecurringTemplate(
            RecurringIncomeTemplate(
              recurringIncomeTemplateId: '',
              userId: userId,
              categoryId: _selectedCategoryId!,
              amount: _currentAmount,
              payDay: _payDay,
              startDate: _selectedDate,
              memo: _memoController.text.trim(),
            ),
          );
        }
        lastRecurringTemplateId = recurringTemplateId;
      } else if (recurringTemplateId != null) {
        await _incomeService.deleteRecurringTemplate(recurringTemplateId);
        recurringTemplateId = null;
      }

      final newIncome = IncomeModel(
        incomeId: widget.editItem != null ? widget.editItem!.id : '',
        userId: userId,
        amount: _currentAmount,
        categoryId: _selectedCategoryId!,
        date: _selectedDate,
        memo: _memoController.text,
        recurringIncomeTemplateId: recurringTemplateId,
        lastRecurringIncomeTemplateId: lastRecurringTemplateId,
        recurringPayDay: _isRecurring ? _payDay : null,
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

  Widget _sectionLabel(String text, {IconData? icon, Color? iconColor, Color? iconBg, Widget? trailing}) {
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

    // 💡 핵심: 대분류가 '정기'로 시작할 때만 정기수입으로 간주 ('비정기 수입'은 제외)
    final bool isRegularIncome = _selectedParentCategory != null && _selectedParentCategory!.startsWith('정기');

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
                  if (_categoryMatchFailed) ...[
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF4E5),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        '기존 카테고리를 찾을 수 없어요. 대분류/소분류를 다시 선택해주세요.',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFFB45309)),
                      ),
                    ),
                  ],
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
                        _categoryMatchFailed = false;

                        // 💡 대분류가 정기수입이 아니면 스위치 끄기
                        if (newParent == null || !newParent.startsWith('정기')) {
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
                                transactionType: 'income',
                                parentName: _selectedParentCategory!,
                              );
                              if (newId != null) {
                                await _loadCategories();
                                if (mounted) {
                                  setState(() {
                                    _selectedCategoryId = newId;
                                    final matched = _incomeCategories.where((c) => c['id'] == newId);
                                    _selectedCategoryName = matched.isNotEmpty ? matched.first['name'] : null;
                                  });
                                }
                              }
                            },
                          ),
                        ),
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