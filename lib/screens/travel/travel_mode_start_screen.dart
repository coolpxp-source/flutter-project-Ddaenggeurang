import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/travel_model.dart';
import '../../services/travel_service.dart';

class TravelModeStartScreen extends StatefulWidget {
  const TravelModeStartScreen({
    super.key,
  });

  @override
  State<TravelModeStartScreen> createState() =>
      _TravelModeStartScreenState();
}

class _TravelModeStartScreenState extends State<TravelModeStartScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _titleController =
  TextEditingController();

  final TextEditingController _budgetController =
  TextEditingController();

  final TravelService _travelService = TravelService();

  DateTime? _startDate;
  DateTime? _endDate;

  bool _isSaving = false;

  @override
  void dispose() {
    _titleController.dispose();
    _budgetController.dispose();
    super.dispose();
  }

  Future<void> _selectStartDate() async {
    final DateTime now = DateTime.now();

    final DateTime? selectedDate = await showDatePicker(
      context: context,
      initialDate: _startDate ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
      helpText: '여행 시작일 선택',
      cancelText: '취소',
      confirmText: '선택',
    );

    if (selectedDate == null) {
      return;
    }

    setState(() {
      _startDate = _dateOnly(selectedDate);

      if (_endDate != null &&
          _endDate!.isBefore(_startDate!)) {
        _endDate = null;
      }
    });
  }

  Future<void> _selectEndDate() async {
    if (_startDate == null) {
      _showMessage('여행 시작일을 먼저 선택해 주세요.');
      return;
    }

    final DateTime? selectedDate = await showDatePicker(
      context: context,
      initialDate: _endDate ?? _startDate!,
      firstDate: _startDate!,
      lastDate: DateTime(_startDate!.year + 5),
      helpText: '여행 종료일 선택',
      cancelText: '취소',
      confirmText: '선택',
    );

    if (selectedDate == null) {
      return;
    }

    setState(() {
      _endDate = _dateOnly(selectedDate);
    });
  }

  Future<void> _saveTravel() async {
    FocusScope.of(context).unfocus();

    if (_isSaving) {
      return;
    }

    final bool isFormValid =
        _formKey.currentState?.validate() ?? false;

    if (!isFormValid) {
      return;
    }

    if (_startDate == null) {
      _showMessage('여행 시작일을 선택해 주세요.');
      return;
    }

    if (_endDate == null) {
      _showMessage('여행 종료일을 선택해 주세요.');
      return;
    }

    if (_endDate!.isBefore(_startDate!)) {
      _showMessage('종료일은 시작일보다 빠를 수 없습니다.');
      return;
    }

    final User? user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      _showMessage('로그인이 필요합니다.');
      return;
    }

    final int? budgetAmount = _parseBudget(
      _budgetController.text,
    );

    setState(() {
      _isSaving = true;
    });

    try {
      final TravelModel travel = TravelModel(
        travelId: '',
        userId: user.uid,
        title: _titleController.text.trim(),
        startDate: _startDate!,
        endDate: _endDate!,
        budgetAmount: budgetAmount,
        isActive: true,
        isDeleted: false,
      );

      final String travelId =
      await _travelService.addTravel(travel);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('여행 모드가 시작되었습니다.'),
          ),
        );

      /*
      다음 여행 지출 입력 화면을 만든 뒤 아래처럼 연결하면 됨.

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) {
            return TravelExpenseInputScreen(
              travelId: travelId,
            );
          },
        ),
      );
      */

      Navigator.pop(context, travelId);
    } on FirebaseException catch (error) {
      if (!mounted) {
        return;
      }

      _showMessage(
        error.message ?? '여행 정보를 저장하지 못했습니다.',
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showMessage('여행 시작 중 오류가 발생했습니다.');
      debugPrint('여행 생성 오류: $error');
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  DateTime _dateOnly(DateTime value) {
    return DateTime(
      value.year,
      value.month,
      value.day,
    );
  }

  int? _parseBudget(String value) {
    final String normalized =
    value.replaceAll(',', '').trim();

    if (normalized.isEmpty) {
      return null;
    }

    return int.tryParse(normalized);
  }

  String _formatDate(DateTime? date) {
    if (date == null) {
      return '날짜 선택';
    }

    final String month =
    date.month.toString().padLeft(2, '0');

    final String day =
    date.day.toString().padLeft(2, '0');

    return '${date.year}.$month.$day';
  }

  String _formatMoney(int amount) {
    final String value = amount.toString();
    final StringBuffer result = StringBuffer();

    for (int index = 0; index < value.length; index++) {
      if (index > 0 &&
          (value.length - index) % 3 == 0) {
        result.write(',');
      }

      result.write(value[index]);
    }

    return result.toString();
  }

  int get _travelDays {
    if (_startDate == null || _endDate == null) {
      return 0;
    }

    return _endDate!.difference(_startDate!).inDays + 1;
  }

  int? get _dailyBudget {
    final int? budget = _parseBudget(
      _budgetController.text,
    );

    if (budget == null ||
        budget <= 0 ||
        _travelDays <= 0) {
      return null;
    }

    return budget ~/ _travelDays;
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F7FA),
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        backgroundColor: const Color(0xFFF8F7FA),
        surfaceTintColor: Colors.transparent,
        foregroundColor: const Color(0xFF222222),
        title: const Text(
          '여행 모드 시작',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            keyboardDismissBehavior:
            ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(
              20,
              16,
              20,
              32,
            ),
            children: [
              _buildHeaderCard(),
              const SizedBox(height: 26),
              _buildSectionTitle('여행 이름'),
              const SizedBox(height: 10),
              _buildTitleField(),
              const SizedBox(height: 24),
              _buildSectionTitle('여행 기간'),
              const SizedBox(height: 10),
              _buildDateFields(),
              if (_travelDays > 0) ...[
                const SizedBox(height: 10),
                Text(
                  '총 $_travelDays일 여행',
                  style: const TextStyle(
                    color: Color(0xFFE66C8E),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              const SizedBox(height: 24),
              _buildSectionTitle(
                '여행 예산',
                description: '예산은 입력하지 않아도 됩니다.',
              ),
              const SizedBox(height: 10),
              _buildBudgetField(),
              const SizedBox(height: 20),
              _buildSummaryCard(),
              const SizedBox(height: 30),
              _buildStartButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 22,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEDF2),
        borderRadius: BorderRadius.circular(22),
      ),
      child: const Column(
        children: [
          Text(
            '✈️',
            style: TextStyle(
              fontSize: 42,
            ),
          ),
          SizedBox(height: 12),
          Text(
            '여행 기간을 설정해 주세요',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF222222),
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 8),
          Text(
            '설정한 기간에 등록되는 변동 지출은\n여행 지출로 자동 분류됩니다.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF777777),
              fontSize: 12,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(
      String title, {
        String? description,
      }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFF333333),
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
        if (description != null) ...[
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              description,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: Color(0xFF999999),
                fontSize: 11,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildTitleField() {
    return TextFormField(
      controller: _titleController,
      textInputAction: TextInputAction.next,
      maxLength: 30,
      decoration: _inputDecoration(
        hintText: '예: 제주도 여름 여행',
        prefixIcon: Icons.luggage_rounded,
      ).copyWith(
        counterText: '',
      ),
      validator: (String? value) {
        final String title = value?.trim() ?? '';

        if (title.isEmpty) {
          return '여행 이름을 입력해 주세요.';
        }

        if (title.length > 30) {
          return '여행 이름은 30자 이하로 입력해 주세요.';
        }

        return null;
      },
    );
  }

  Widget _buildDateFields() {
    return Row(
      children: [
        Expanded(
          child: _buildDateButton(
            label: '시작일',
            selectedDate: _startDate,
            onTap: _selectStartDate,
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(
            horizontal: 8,
          ),
          child: Icon(
            Icons.arrow_forward_rounded,
            size: 18,
            color: Color(0xFFAAAAAA),
          ),
        ),
        Expanded(
          child: _buildDateButton(
            label: '종료일',
            selectedDate: _endDate,
            onTap: _selectEndDate,
          ),
        ),
      ],
    );
  }

  Widget _buildDateButton({
    required String label,
    required DateTime? selectedDate,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsets.symmetric(
            horizontal: 13,
            vertical: 14,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFFE6E3E7),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF999999),
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(
                    Icons.calendar_month_rounded,
                    size: 18,
                    color: Color(0xFFE66C8E),
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      _formatDate(selectedDate),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: selectedDate == null
                            ? const Color(0xFFAAAAAA)
                            : const Color(0xFF333333),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBudgetField() {
    return TextFormField(
      controller: _budgetController,
      keyboardType: TextInputType.number,
      textInputAction: TextInputAction.done,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
      ],
      onChanged: (_) {
        setState(() {});
      },
      onFieldSubmitted: (_) {
        _saveTravel();
      },
      decoration: _inputDecoration(
        hintText: '예: 500000',
        prefixIcon: Icons.account_balance_wallet_rounded,
        suffixText: '원',
      ),
      validator: (String? value) {
        final String input = value?.trim() ?? '';

        if (input.isEmpty) {
          return null;
        }

        final int? budget = _parseBudget(input);

        if (budget == null || budget <= 0) {
          return '예산은 1원 이상 입력해 주세요.';
        }

        return null;
      },
    );
  }

  Widget _buildSummaryCard() {
    final int? budget = _parseBudget(
      _budgetController.text,
    );

    final int? dailyBudget = _dailyBudget;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFF0EDF0),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 14,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildSummaryRow(
            title: '여행 기간',
            value: _travelDays > 0
                ? '$_travelDays일'
                : '미설정',
          ),
          const SizedBox(height: 14),
          _buildSummaryRow(
            title: '전체 예산',
            value: budget != null && budget > 0
                ? '${_formatMoney(budget)}원'
                : '예산 없음',
          ),
          const Divider(
            height: 28,
            color: Color(0xFFF0EDF0),
          ),
          _buildSummaryRow(
            title: '하루 권장 예산',
            value: dailyBudget != null
                ? '${_formatMoney(dailyBudget)}원'
                : '계산 전',
            valueColor: const Color(0xFFE66C8E),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow({
    required String title,
    required String value,
    Color valueColor = const Color(0xFF333333),
  }) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFF888888),
            fontSize: 12,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            color: valueColor,
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  Widget _buildStartButton() {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: _isSaving
            ? null
            : _saveTravel,
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: const Color(0xFFE66C8E),
          disabledBackgroundColor:
          const Color(0xFFF0B8C7),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(17),
          ),
        ),
        child: _isSaving
            ? const SizedBox(
          width: 23,
          height: 23,
          child: CircularProgressIndicator(
            strokeWidth: 2.4,
            color: Colors.white,
          ),
        )
            : const Text(
          '여행 모드 시작하기',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hintText,
    required IconData prefixIcon,
    String? suffixText,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(
        color: Color(0xFFAAAAAA),
        fontSize: 13,
      ),
      prefixIcon: Icon(
        prefixIcon,
        color: const Color(0xFFE66C8E),
      ),
      suffixText: suffixText,
      suffixStyle: const TextStyle(
        color: Color(0xFF555555),
        fontSize: 13,
        fontWeight: FontWeight.w700,
      ),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 16,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(
          color: Color(0xFFE6E3E7),
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(
          color: Color(0xFFE6E3E7),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(
          color: Color(0xFFE66C8E),
          width: 1.5,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(
          color: Colors.redAccent,
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(
          color: Colors.redAccent,
          width: 1.5,
        ),
      ),
    );
  }
}