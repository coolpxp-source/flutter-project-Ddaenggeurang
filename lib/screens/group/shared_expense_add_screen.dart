import 'package:flutter/material.dart';
import '../../services/group_service.dart';
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

class _SharedExpenseAddScreenState extends State<SharedExpenseAddScreen> {
  final GroupService _groupService = GroupService.instance;

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _payerController = TextEditingController();
  final TextEditingController _memoController = TextEditingController();

  String _selectedCategory = '식비';
  DateTime _selectedDate = DateTime.now();

  bool _isSaving = false;

  final List<String> _categories = [
    '식비',
    '교통',
    '생활',
    '쇼핑',
    '문화',
    '기타',
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _payerController.dispose();
    _memoController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (pickedDate == null) {
      return;
    }

    setState(() {
      _selectedDate = pickedDate;
    });
  }

  Future<void> _saveExpense() async {
    final String title = _titleController.text.trim();
    final String amountText = _amountController.text.trim();
    final String payer = _payerController.text.trim();
    final String memo = _memoController.text.trim();

    if (title.isEmpty) {
      _showMessage(
        '지출 제목을 입력해주세요.',
        type: AppSnackBarType.warning,
      );
      return;
    }

    if (amountText.isEmpty) {
      _showMessage(
        '지출 제목을 입력해주세요.',
        type: AppSnackBarType.warning,
      );
      return;
    }

    final int? amount = int.tryParse(amountText);

    if (amount == null || amount <= 0) {
      _showMessage(
        '지출 제목을 입력해주세요.',
        type: AppSnackBarType.warning,
      );
      return;
    }

    if (payer.isEmpty) {
      _showMessage(
        '지출 제목을 입력해주세요.',
        type: AppSnackBarType.warning,
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      // 공동지출 Firestore 저장
      await _groupService.addSharedExpense(
        groupId: widget.groupId,
        title: title,
        amount: amount,
        paidByNickname: payer,
        category: _selectedCategory,
        date: _selectedDate,
        memo: memo,
      );

      if (!mounted) {
        return;
      }

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isSaving = false;
      });

      _showMessage(
        e.toString().replaceFirst('Exception: ', ''),
        type: AppSnackBarType.error,
      );
    }
  }

  // 사용자 안내 스낵바 표시 메서드
  void _showMessage(
      String message, {
        AppSnackBarType type = AppSnackBarType.info,
      }) {
    AppSnackBar.show(
      context,
      message: message,
      type: type,
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}.${date.month.toString().padLeft(2, '0')}.'
        '${date.day.toString().padLeft(2, '0')}';
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
    String? hint,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon),
      filled: true,
      fillColor: const Color(0xFFF9F7FC),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(
          color: Color(0xFFECE7F2),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(
          color: Color(0xFF9A7FE8),
          width: 1.5,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F6FB),
      appBar: AppBar(
        title: const Text(
          '공동 지출 추가',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '공동으로 사용한 지출을 기록해보세요.',
                style: TextStyle(
                  fontSize: 15,
                  color: Color(0xFF77717F),
                ),
              ),
              const SizedBox(height: 24),

              TextField(
                controller: _titleController,
                decoration: _inputDecoration(
                  label: '지출 제목',
                  icon: Icons.receipt_long_outlined,
                  hint: '예: 장보기',
                ),
              ),

              const SizedBox(height: 16),

              TextField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                decoration: _inputDecoration(
                  label: '금액',
                  icon: Icons.payments_outlined,
                  hint: '예: 50000',
                ).copyWith(
                  suffixText: '원',
                ),
              ),

              const SizedBox(height: 16),

              DropdownButtonFormField<String>(
                value: _selectedCategory,
                decoration: _inputDecoration(
                  label: '카테고리',
                  icon: Icons.category_outlined,
                ),
                items: _categories.map((category) {
                  return DropdownMenuItem<String>(
                    value: category,
                    child: Text(category),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value == null) {
                    return;
                  }

                  setState(() {
                    _selectedCategory = value;
                  });
                },
              ),

              const SizedBox(height: 16),

              TextField(
                controller: _payerController,
                decoration: _inputDecoration(
                  label: '결제자',
                  icon: Icons.person_outline,
                  hint: '예: 홍길동',
                ),
              ),

              const SizedBox(height: 16),

              InkWell(
                onTap: _selectDate,
                borderRadius: BorderRadius.circular(16),
                child: InputDecorator(
                  decoration: _inputDecoration(
                    label: '지출 날짜',
                    icon: Icons.calendar_month_outlined,
                  ),
                  child: Text(
                    _formatDate(_selectedDate),
                    style: const TextStyle(
                      fontSize: 16,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              TextField(
                controller: _memoController,
                maxLines: 4,
                decoration: _inputDecoration(
                  label: '메모',
                  icon: Icons.edit_note_outlined,
                  hint: '필요한 내용을 기록해주세요.',
                ),
              ),

              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveExpense,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF9A7FE8),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: _isSaving
                      ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                      : const Text(
                    '공동 지출 등록',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}