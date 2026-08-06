import 'package:flutter/material.dart';
import '../../services/group_service.dart';
import '../../utils/app_colors.dart';
import '../../utils/formatters.dart';
import '../../widgets/common/app_snack_bar.dart';

class SharedExpenseAddScreen extends StatefulWidget {
  final String groupId;

  const SharedExpenseAddScreen({
    super.key,
    required this.groupId,
  });

  @override
  State<SharedExpenseAddScreen> createState() =>
      _SharedExpenseAddScreenState();
}

class _CategoryOption {
  final String label;
  final IconData icon;
  const _CategoryOption(this.label, this.icon);
}

class _SharedExpenseAddScreenState extends State<SharedExpenseAddScreen> {
  final GroupService _groupService = GroupService.instance;

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _memoController = TextEditingController();

  String _selectedCategory = '식비';
  DateTime _selectedDate = DateTime.now();

  bool _isSaving = false;

  List<Map<String, dynamic>> _members = [];
  bool _isLoadingMembers = true;
  String? _selectedPayerNickname;

  final List<_CategoryOption> _categories = const [
    _CategoryOption('식비', Icons.restaurant_rounded),
    _CategoryOption('교통', Icons.directions_bus_rounded),
    _CategoryOption('생활', Icons.shopping_cart_rounded),
    _CategoryOption('쇼핑', Icons.shopping_bag_rounded),
    _CategoryOption('문화', Icons.movie_rounded),
    _CategoryOption('기타', Icons.more_horiz_rounded),
  ];

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _memoController.dispose();
    super.dispose();
  }

  Future<void> _loadMembers() async {
    try {
      final members = await _groupService.getGroupMembers(groupId: widget.groupId);
      if (!mounted) return;
      setState(() {
        _members = members;
        _isLoadingMembers = false;
        _selectedPayerNickname = members.isNotEmpty ? members.first['nickname'] as String : null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingMembers = false);
      _showMessage('그룹 멤버를 불러오지 못했습니다.', type: AppSnackBarType.error);
    }
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.purple,
              onPrimary: Colors.white,
              onSurface: AppColors.ink,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(foregroundColor: AppColors.purple),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked == null) return;
    setState(() => _selectedDate = picked);
  }

  Future<void> _saveExpense() async {
    final String title = _titleController.text.trim();
    final String amountText = _amountController.text.trim();
    final String memo = _memoController.text.trim();

    if (title.isEmpty) {
      _showMessage('지출 제목을 입력해주세요.', type: AppSnackBarType.warning);
      return;
    }
    if (amountText.isEmpty) {
      _showMessage('지출 금액을 입력해주세요.', type: AppSnackBarType.warning);
      return;
    }
    final int? amount = int.tryParse(amountText.replaceAll(',', ''));
    if (amount == null || amount <= 0) {
      _showMessage('올바른 금액을 입력해주세요.', type: AppSnackBarType.warning);
      return;
    }
    if (_selectedPayerNickname == null) {
      _showMessage('결제자를 선택해주세요.', type: AppSnackBarType.warning);
      return;
    }

    setState(() => _isSaving = true);
    try {
      await _groupService.addSharedExpense(
        groupId: widget.groupId,
        title: title,
        amount: amount,
        paidByNickname: _selectedPayerNickname!,
        category: _selectedCategory,
        date: _selectedDate,
        memo: memo,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      _showMessage(e.toString().replaceFirst('Exception: ', ''), type: AppSnackBarType.error);
    }
  }

  void _showMessage(String message, {AppSnackBarType type = AppSnackBarType.info}) {
    AppSnackBar.show(context, message: message, type: type);
  }

  // ─────────────────────── 스타일 헬퍼 (ExpenseInputScreen과 동일 패턴) ───────────────────────

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

  Widget _sectionLabel(String text, {IconData? icon, Widget? trailing}) {
    return Row(
      children: [
        if (icon != null) ...[
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: const Color(0xFFEDE9FE),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 14, color: AppColors.purple),
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

  InputDecoration _fieldDecoration({String? label, String? hint, String? prefixText, String? suffixText}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixText: prefixText,
      suffixText: suffixText,
      filled: true,
      fillColor: const Color(0xFFF7F7F9),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.purple, width: 1.6),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text('공동 지출 추가', style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.ink)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── 금액 입력 카드 (지출 입력 화면과 동일한 톤, 컬러만 보라 계열로) ──
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F3FF),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE0D9FF), width: 1.2),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.purple.withValues(alpha: 0.08),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.payments_outlined, size: 18, color: AppColors.purple),
                        SizedBox(width: 7),
                        Text('결제 금액',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.purple)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: const Color(0xFFEAE1FF)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _amountController,
                              enabled: !_isSaving,
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                fontSize: 30,
                                height: 1.15,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.8,
                                color: AppColors.ink,
                              ),
                              cursorColor: AppColors.purple,
                              decoration: const InputDecoration(
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
                              final int amount = int.tryParse(value.text.replaceAll(',', '').trim()) ?? 0;
                              return Text(
                                '원',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                  color: amount > 0 ? AppColors.ink : const Color(0xFFB8BFC8),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // ── 지출 제목 ──
              _sectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionLabel('지출 제목', icon: Icons.receipt_long_outlined),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _titleController,
                      enabled: !_isSaving,
                      style: const TextStyle(fontSize: 14, color: AppColors.ink),
                      decoration: _fieldDecoration(hint: '예: 장보기'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ── 카테고리 (칩 선택) ──
              _sectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionLabel('카테고리', icon: Icons.category_rounded),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _categories.map((c) {
                        final selected = _selectedCategory == c.label;
                        return ChoiceChip(
                          avatar: Icon(c.icon, size: 15, color: selected ? Colors.white : AppColors.purple),
                          label: Text(c.label),
                          selected: selected,
                          onSelected: _isSaving ? null : (_) => setState(() => _selectedCategory = c.label),
                          selectedColor: AppColors.purple,
                          backgroundColor: const Color(0xFFEDE9FE),
                          labelStyle: TextStyle(
                            color: selected ? Colors.white : AppColors.purple,
                            fontWeight: FontWeight.w700,
                            fontSize: 12.5,
                          ),
                          side: BorderSide.none,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide.none),
                          showCheckmark: false,
                          elevation: 0,
                          pressElevation: 0,
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ── 결제자 (그룹 멤버 드롭다운) ──
              _sectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionLabel('결제자', icon: Icons.person_outline),
                    const SizedBox(height: 10),
                    _isLoadingMembers
                        ? Container(
                      height: 54,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7F7F9),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.purple),
                      ),
                    )
                        : DropdownButtonFormField<String>(
                      value: _selectedPayerNickname,
                      decoration: _fieldDecoration(),
                      borderRadius: BorderRadius.circular(14),
                      dropdownColor: Colors.white,
                      icon: const Icon(Icons.expand_more_rounded, color: AppColors.purple),
                      items: _members.map((m) {
                        final nickname = m['nickname'] as String;
                        return DropdownMenuItem<String>(value: nickname, child: Text(nickname));
                      }).toList(),
                      onChanged: _isSaving
                          ? null
                          : (value) {
                        if (value == null) return;
                        setState(() => _selectedPayerNickname = value);
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
                              decoration: const BoxDecoration(color: Color(0xFFEDE9FE), shape: BoxShape.circle),
                              alignment: Alignment.center,
                              child: const Icon(Icons.event_rounded, size: 14, color: AppColors.purple),
                            ),
                            const SizedBox(width: 8),
                            Text('지출일: ${_selectedDate.toLocal().toString().split(' ')[0]}',
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.ink)),
                          ],
                        ),
                        InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: _isSaving ? null : _selectDate,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEDE9FE),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text('날짜 변경',
                                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.purple)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _memoController,
                      enabled: !_isSaving,
                      maxLines: 4,
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
                    backgroundColor: AppColors.purple,
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
                      : const Text('공동 지출 등록', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}