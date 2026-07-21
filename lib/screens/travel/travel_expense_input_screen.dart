import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/travel_expense_service.dart';

class TravelExpenseInputScreen extends StatefulWidget {
  const TravelExpenseInputScreen({
    super.key,
    required this.travelId,
  });

  final String travelId;

  @override
  State<TravelExpenseInputScreen> createState() =>
      _TravelExpenseInputScreenState();
}

class _TravelExpenseInputScreenState
    extends State<TravelExpenseInputScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _amountController =
  TextEditingController();
  final TextEditingController _placeController =
  TextEditingController();
  final TextEditingController _memoController =
  TextEditingController();

  final TravelExpenseService _expenseService =
  TravelExpenseService();

  final List<String> _categories = const [
    '식비',
    '카페',
    '교통',
    '숙박',
    '쇼핑',
    '관광',
    '문화',
    '기타',
  ];

  String _selectedCategory = '식비';
  DateTime _selectedDate = DateTime.now();
  bool _isSaving = false;

  @override
  void dispose() {
    _amountController.dispose();
    _placeController.dispose();
    _memoController.dispose();
    super.dispose();
  }

  Future<void> _selectExpenseDate() async {
    final DateTime? selectedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(
        const Duration(days: 365),
      ),
      helpText: '지출 날짜 선택',
      cancelText: '취소',
      confirmText: '선택',
    );

    if (selectedDate == null || !mounted) {
      return;
    }

    setState(() {
      _selectedDate = selectedDate;
    });
  }

  Future<void> _saveExpense() async {
    if (_isSaving) {
      return;
    }

    final bool isValid =
        _formKey.currentState?.validate() ?? false;

    if (!isValid) {
      return;
    }

    final String amountText = _amountController.text
        .replaceAll(',', '')
        .trim();

    final int? amount = int.tryParse(amountText);

    if (amount == null || amount <= 0) {
      _showMessage('올바른 금액을 입력해 주세요.');
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _isSaving = true;
    });

    try {
      await _expenseService.createExpense(
        travelId: widget.travelId,
        amount: amount,
        category: _selectedCategory,
        place: _placeController.text.trim(),
        memo: _memoController.text.trim(),
        expenseDate: _selectedDate,
      );

      if (!mounted) {
        return;
      }

      _showMessage('여행 지출이 저장되었습니다.');

      _resetForm();
    } on ArgumentError catch (error) {
      if (!mounted) {
        return;
      }

      _showMessage(
        error.message?.toString() ?? '입력값을 확인해 주세요.',
      );
    } on StateError catch (error) {
      if (!mounted) {
        return;
      }

      _showMessage(error.message);
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showMessage(
        error.toString().replaceFirst('Exception: ', ''),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  void _resetForm() {
    _formKey.currentState?.reset();

    _amountController.clear();
    _placeController.clear();
    _memoController.clear();

    setState(() {
      _selectedCategory = '식비';
      _selectedDate = DateTime.now();
    });
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  String _formatDate(DateTime date) {
    final String month =
    date.month.toString().padLeft(2, '0');
    final String day =
    date.day.toString().padLeft(2, '0');

    return '${date.year}년 $month월 $day일';
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
    String? hintText,
    String? suffixText,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hintText,
      suffixText: suffixText,
      prefixIcon: Icon(icon),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: Colors.grey.shade300,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: Theme.of(context).colorScheme.primary,
          width: 1.5,
        ),
      ),
      filled: true,
      fillColor: Colors.white,
    );
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme =
        Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text(
          '여행 지출 입력',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: colorScheme.primary,
                        child: Icon(
                          Icons.flight_takeoff_rounded,
                          color: colorScheme.onPrimary,
                        ),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment:
                          CrossAxisAlignment.start,
                          children: [
                            Text(
                              '여행 모드 진행 중',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              '사용한 여행 경비를 기록해 주세요.',
                              style: TextStyle(
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  '지출 정보',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _amountController,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.next,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  decoration: _inputDecoration(
                    label: '지출 금액',
                    hintText: '예: 15000',
                    suffixText: '원',
                    icon: Icons.payments_outlined,
                  ),
                  validator: (value) {
                    final String amountText =
                        value?.trim() ?? '';

                    if (amountText.isEmpty) {
                      return '지출 금액을 입력해 주세요.';
                    }

                    final int? amount =
                    int.tryParse(amountText);

                    if (amount == null || amount <= 0) {
                      return '0원보다 큰 금액을 입력해 주세요.';
                    }

                    return null;
                  },
                ),
                const SizedBox(height: 16),

                DropdownButtonFormField<String>(
                  initialValue: _selectedCategory,
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
                  onChanged: _isSaving
                      ? null
                      : (value) {
                    if (value == null) {
                      return;
                    }

                    setState(() {
                      _selectedCategory = value;
                    });
                  },
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _placeController,
                  textInputAction: TextInputAction.next,
                  maxLength: 50,
                  decoration: _inputDecoration(
                    label: '사용처',
                    hintText: '예: 식당, 카페, 관광지',
                    icon: Icons.storefront_outlined,
                  ),
                ),
                const SizedBox(height: 4),

                TextFormField(
                  controller: _memoController,
                  keyboardType: TextInputType.multiline,
                  textInputAction: TextInputAction.newline,
                  minLines: 3,
                  maxLines: 5,
                  maxLength: 200,
                  decoration: _inputDecoration(
                    label: '메모',
                    hintText: '지출 내용을 간단히 입력해 주세요.',
                    icon: Icons.edit_note_outlined,
                  ),
                ),
                const SizedBox(height: 4),

                InkWell(
                  onTap: _isSaving
                      ? null
                      : _selectExpenseDate,
                  borderRadius: BorderRadius.circular(12),
                  child: InputDecorator(
                    decoration: _inputDecoration(
                      label: '지출 날짜',
                      icon: Icons.calendar_month_outlined,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            _formatDate(_selectedDate),
                            style: const TextStyle(
                              fontSize: 16,
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.arrow_drop_down,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 28),

                SizedBox(
                  height: 54,
                  child: FilledButton.icon(
                    onPressed:
                    _isSaving ? null : _saveExpense,
                    icon: _isSaving
                        ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                      ),
                    )
                        : const Icon(Icons.save_outlined),
                    label: Text(
                      _isSaving ? '저장 중...' : '지출 저장',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius:
                        BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}