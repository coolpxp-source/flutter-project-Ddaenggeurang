import 'package:flutter/material.dart';
import '../../utils/app_colors.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../utils/formatters.dart';
import '../../models/saving_model.dart';
import '../../services/saving_service.dart';

/// expense/income_input_screen.dart와 통일한 팔레트.

class SavingInputScreen extends StatefulWidget {
  const SavingInputScreen({super.key});

  @override
  State<SavingInputScreen> createState() => _SavingInputScreenState();
}

class _SavingInputScreenState extends State<SavingInputScreen> {
  final TextEditingController _amountController = TextEditingController(text: '0');
  final TextEditingController _accountNameController = TextEditingController();
  final TextEditingController _memoController = TextEditingController();

  final TextEditingController _brokerageController = TextEditingController();
  final TextEditingController _assetNameController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();

  final SavingService _savingService = SavingService();

  DateTime _selectedDate = DateTime.now();

  List<Map<String, dynamic>> _savingCategories = [];
  bool _isLoadingCategories = true;

  String? _selectedParentCategory;
  String? _selectedCategoryId;
  String? _selectedCategoryName;

  int _currentAmount = 0;

  @override
  void initState() {
    super.initState();
    _loadCategories();

    _amountController.addListener(() {
      final text = _amountController.text.replaceAll(',', '');
      setState(() => _currentAmount = int.tryParse(text) ?? 0);
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    _accountNameController.dispose();
    _memoController.dispose();
    _brokerageController.dispose();
    _assetNameController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    final String userId = FirebaseAuth.instance.currentUser?.uid ?? 'test_user_id';
    try {
      final db = FirebaseFirestore.instance;
      final defaultSnap = await db.collection('categories').where('transactionType', isEqualTo: 'saving').get();
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
        if (data['transactionType'] == 'saving' && data['isHidden'] != true) {
          loaded.add({'id': doc.id, ...data});
        }
      }

      setState(() {
        _savingCategories = loaded;
        _isLoadingCategories = false;
      });
    } catch (e) {
      debugPrint('카테고리 로드 에러: $e');
      setState(() => _isLoadingCategories = false);
    }
  }

  Future<void> _saveSaving() async {
    if (_currentAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('저축/투자 금액을 입력해주세요!')));
      return;
    }
    if (_selectedCategoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('소분류 카테고리를 선택해주세요!')));
      return;
    }

    if (_selectedCategoryName == '투자' || _selectedCategoryName == '주식') {
      if (_brokerageController.text.isEmpty || _assetNameController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('증권사명과 종목명을 모두 입력해주세요!')));
        return;
      }
    }

    try {
      final String userId = FirebaseAuth.instance.currentUser?.uid ?? 'test_user_id';

      InvestmentDetail? investmentDetail;
      if (_selectedCategoryName == '투자' || _selectedCategoryName == '주식') {
        investmentDetail = InvestmentDetail(
          brokerage: _brokerageController.text,
          assetName: _assetNameController.text,
          quantity: num.tryParse(_quantityController.text),
        );
      }

      final newSaving = SavingModel(
        savingId: '',
        userId: userId,
        date: _selectedDate,
        categoryId: _selectedCategoryId!,
        accountName: _accountNameController.text.isNotEmpty ? _accountNameController.text : null,
        amount: _currentAmount,
        memo: _memoController.text.isEmpty ? null : _memoController.text,
        investmentDetail: investmentDetail,
      );

      await _savingService.addSaving(newSaving);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('성공적으로 기록되었습니다!')));
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('🔥 저장 에러: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('저장 실패: $e')));
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
        border: Border.all(color: AppColors.cardBorder, width: 1.2),
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
        borderSide: const BorderSide(color: AppColors.utility, width: 1.6),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<String> parentCategories = _savingCategories
        .map((category) => (category['parentName'] ?? category['parent'] ?? '미분류').toString())
        .toSet()
        .toList();

    final List<Map<String, dynamic>> childCategories = _selectedParentCategory == null
        ? []
        : _savingCategories.where((category) {
      final parent = category['parentName'] ?? category['parent'] ?? '미분류';
      return parent == _selectedParentCategory;
    }).toList();

    final bool isInvestment = _selectedCategoryName == '투자' || _selectedCategoryName == '주식';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text('저축 / 투자 기록', style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.ink)),
      ),
      body: _isLoadingCategories
          ? const Center(child: CircularProgressIndicator(color: AppColors.utility))
          : SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── 이체/매수 금액 히어로 카드 ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF6C93FF), Color(0xFF4F7DF3)],
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.utility.withValues(alpha: 0.3),
                    blurRadius: 24,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '이체 / 매수 금액',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _amountController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [CurrencyFormatter()],
                    style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                    cursorColor: Colors.white,
                    decoration: const InputDecoration(
                      prefixText: '₩ ',
                      prefixStyle: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── 대분류 / 소분류 ──
            _sectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionLabel('대분류', icon: Icons.folder_outlined),
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
                      });
                    },
                  ),
                  const SizedBox(height: 20),
                  _sectionLabel('소분류', icon: Icons.subdirectory_arrow_right_rounded),
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
                    onChanged: _selectedParentCategory == null || childCategories.isEmpty ? null : (newId) {
                      setState(() {
                        _selectedCategoryId = newId;
                        _selectedCategoryName = childCategories.firstWhere((c) => c['id'] == newId)['name'];
                      });
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── 계좌 정보 ──
            _sectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionLabel('계좌 정보', icon: Icons.account_balance_outlined),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _accountNameController,
                    style: const TextStyle(fontSize: 14, color: AppColors.ink),
                    decoration: _fieldDecoration(
                      label: '계좌명 (선택)',
                      hint: '예: 국민은행 청년희망적금',
                    ),
                  ),
                ],
              ),
            ),

            if (isInvestment) ...[
              const SizedBox(height: 16),
              _sectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionLabel('투자 상세 정보',
                        icon: Icons.show_chart_rounded, iconColor: AppColors.saving, iconBg: AppColors.savingSoft),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _brokerageController,
                            style: const TextStyle(fontSize: 14, color: AppColors.ink),
                            decoration: _fieldDecoration(
                              label: '증권사명 (필수)',
                              hint: '예: 토스증권',
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _quantityController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            style: const TextStyle(fontSize: 14, color: AppColors.ink),
                            decoration: _fieldDecoration(
                              label: '매수 수량 (선택)',
                              hint: '예: 2.5',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _assetNameController,
                      style: const TextStyle(fontSize: 14, color: AppColors.ink),
                      decoration: _fieldDecoration(
                        label: '종목명 (필수)',
                        hint: '예: S&P500 ETF',
                      ),
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
                          Text('기록일: ${_selectedDate.toLocal().toString().split(' ')[0]}',
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
                                    primary: AppColors.utility,
                                    onPrimary: Colors.white,
                                    onSurface: AppColors.ink,
                                  ),
                                  textButtonTheme: TextButtonThemeData(
                                    style: TextButton.styleFrom(foregroundColor: AppColors.utility),
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
                onPressed: _saveSaving,
                child: const Text('저장하기', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}