import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/subscription_service.dart';

// 앱 공통 핑크 테마 컬러 (구독관리 도메인)
const Color _mainColor = Color(0xFFFF6F91);
const Color _mainSoftColor = Color(0xFFFFE3EC);
const Color _mainBorderSoftColor = Color(0xFFFFD3E0);

class SubscriptionAddScreen extends StatefulWidget {
  final String userId;

  const SubscriptionAddScreen({
    super.key,
    required this.userId,
  });

  @override
  State<SubscriptionAddScreen> createState() =>
      _SubscriptionAddScreenState();
}

class _SubscriptionAddScreenState extends State<SubscriptionAddScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _customServiceController = TextEditingController();
  final SubscriptionService _subscriptionService = SubscriptionService();

  static const List<String> _serviceOptions = [
    '넷플릭스',
    '티빙',
    '디즈니+',
    '웨이브',
    '왓챠',
    '쿠팡플레이',
    '유튜브 프리미엄',
    '스포티파이',
    '멜론 뮤직',
    '지니 뮤직',
    'Apple Music',
    '쿠팡 와우',
    '네이버 플러스 멤버십',
    'ChatGPT Plus',
    '기타(직접 입력)',
  ];

  String? _selectedService;
  int? _selectedPaymentDay;
  bool _isSaving = false;

  /// 입력한 구독 정보를 Firestore에 저장
  Future<void> _saveSubscription() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final String? name = _selectedService == '기타(직접 입력)'
        ? _customServiceController.text.trim()
        : _selectedService;
    final int? amount = int.tryParse(
      _amountController.text.replaceAll(',', '').trim(),
    );
    final int? paymentDay = _selectedPaymentDay;

    if (name == null || amount == null || paymentDay == null) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      await _subscriptionService.addSubscription(
        userId: widget.userId,
        name: name,
        amount: amount,
        paymentDay: paymentDay,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '$name · ${_formatAmount(amount)}원 · 매월 $paymentDay일',
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF333333),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              '구독 저장 중 오류가 발생했습니다.\n$e',
            ),
            backgroundColor: const Color(0xFFE0483C),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _selectPaymentDay() async {
    final now = DateTime.now();
    final initialDate = DateTime(
      now.year,
      now.month,
      (_selectedPaymentDay ?? now.day).clamp(
        1,
        DateTime(now.year, now.month + 1, 0).day,
      ),
    );

    final DateTime? selectedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 3),
      helpText: '매월 결제일 선택',
      cancelText: '취소',
      confirmText: '선택',
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: _mainColor,
              onPrimary: Colors.white,
              onSurface: Color(0xFF222222),
            ),
            datePickerTheme: DatePickerThemeData(
              headerBackgroundColor: _mainColor,
              headerForegroundColor: Colors.white,
              dayForegroundColor: WidgetStateProperty.resolveWith(
                    (Set<WidgetState> states) {
                  if (states.contains(WidgetState.selected)) {
                    return Colors.white;
                  }
                  if (states.contains(WidgetState.disabled)) {
                    return const Color(0xFFCCCCCC);
                  }
                  return const Color(0xFF222222);
                },
              ),
              dayBackgroundColor: WidgetStateProperty.resolveWith(
                    (Set<WidgetState> states) {
                  if (states.contains(WidgetState.selected)) {
                    return _mainColor;
                  }
                  return null;
                },
              ),
              todayForegroundColor: WidgetStateProperty.resolveWith(
                    (Set<WidgetState> states) {
                  if (states.contains(WidgetState.selected)) {
                    return Colors.white;
                  }
                  return _mainColor;
                },
              ),
              todayBackgroundColor: WidgetStateProperty.resolveWith(
                    (Set<WidgetState> states) {
                  if (states.contains(WidgetState.selected)) {
                    return _mainColor;
                  }
                  return null;
                },
              ),
              todayBorder: const BorderSide(
                color: _mainColor,
              ),
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: _mainColor,
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (selectedDate == null) {
      return;
    }

    setState(() {
      _selectedPaymentDay = selectedDate.day;
    });

    _formKey.currentState?.validate();
  }


  @override
  void dispose() {
    _amountController.dispose();
    _customServiceController.dispose();
    super.dispose();
  }

  InputDecoration _inputDecoration({
    required String hintText,
    required IconData prefixIcon,
    String? suffixText,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(
        color: Color(0xFFAAAAAA),
        fontSize: 13,
      ),
      prefixIcon: Icon(
        prefixIcon,
        color: _mainColor,
      ),
      suffixText: suffixText,
      suffixIcon: suffixIcon,
      suffixStyle: const TextStyle(
        color: Color(0xFF555555),
        fontSize: 13,
        fontWeight: FontWeight.w700,
      ),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 17,
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
          color: _mainColor,
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

  Widget _buildSectionTitle(
      String title, {
        required IconData icon,
      }) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: _mainColor,
        ),
        const SizedBox(width: 6),
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFF333333),
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
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
          '구독 추가',
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
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 20,
                ),
                decoration: BoxDecoration(
                  color: _mainSoftColor,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: _mainBorderSoftColor),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.subscriptions_rounded,
                        color: _mainColor,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Text(
                        '매달 결제되는 구독 정보를\n등록해 주세요.',
                        style: TextStyle(
                          color: Color(0xFF7A4457),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 26),
              _buildSectionTitle(
                '구독 서비스명',
                icon: Icons.subscriptions_rounded,
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: _selectedService,
                isExpanded: true,
                menuMaxHeight: 330,
                decoration: _inputDecoration(
                  hintText: '구독 서비스를 선택하세요',
                  prefixIcon: Icons.subscriptions_rounded,
                ),
                icon: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: _mainColor,
                ),
                items: _serviceOptions
                    .map(
                      (service) => DropdownMenuItem<String>(
                    value: service,
                    child: Text(
                      service,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF333333),
                      ),
                    ),
                  ),
                )
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedService = value;
                    if (value != '기타(직접 입력)') {
                      _customServiceController.clear();
                    }
                  });
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '구독 서비스를 선택하세요.';
                  }
                  return null;
                },
              ),
              if (_selectedService == '기타(직접 입력)') ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _customServiceController,
                  textInputAction: TextInputAction.next,
                  decoration: _inputDecoration(
                    hintText: '구독 서비스명을 직접 입력하세요',
                    prefixIcon: Icons.edit_rounded,
                  ),
                  validator: (value) {
                    if (_selectedService != '기타(직접 입력)') {
                      return null;
                    }
                    if (value == null || value.trim().isEmpty) {
                      return '구독 서비스명을 입력하세요.';
                    }
                    if (value.trim().length > 30) {
                      return '서비스명은 30자 이하로 입력하세요.';
                    }
                    return null;
                  },
                ),
              ],
              const SizedBox(height: 24),
              _buildSectionTitle(
                '월 결제 금액',
                icon: Icons.payments_rounded,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  _ThousandsSeparatorInputFormatter(),
                ],
                decoration: _inputDecoration(
                  hintText: '예: 17,000',
                  suffixText: '원',
                  prefixIcon: Icons.payments_rounded,
                ),
                validator: (value) {
                  final int? amount = int.tryParse(
                    value?.replaceAll(',', '').trim() ?? '',
                  );

                  if (amount == null) {
                    return '숫자로 금액을 입력하세요.';
                  }

                  if (amount <= 0) {
                    return '금액은 0원보다 커야 합니다.';
                  }

                  return null;
                },
              ),
              const SizedBox(height: 24),
              _buildSectionTitle(
                '매월 결제일',
                icon: Icons.calendar_month_rounded,
              ),
              const SizedBox(height: 10),
              FormField<int>(
                initialValue: _selectedPaymentDay,
                validator: (_) {
                  if (_selectedPaymentDay == null) {
                    return '캘린더에서 결제일을 선택하세요.';
                  }
                  return null;
                },
                builder: (field) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      InkWell(
                        onTap: _selectPaymentDay,
                        borderRadius: BorderRadius.circular(16),
                        child: InputDecorator(
                          decoration: _inputDecoration(
                            hintText: '캘린더에서 결제일 선택',
                            prefixIcon: Icons.calendar_month_rounded,
                            suffixIcon: const Icon(
                              Icons.chevron_right_rounded,
                              color: _mainColor,
                            ),
                          ).copyWith(
                            errorText: field.errorText,
                          ),
                          child: Text(
                            _selectedPaymentDay == null
                                ? '결제일을 선택하세요'
                                : '매월 $_selectedPaymentDay일',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: _selectedPaymentDay == null
                                  ? const Color(0xFFAAAAAA)
                                  : const Color(0xFF333333),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveSubscription,
                  style: ElevatedButton.styleFrom(
                    elevation: 0,
                    backgroundColor: _mainColor,
                    disabledBackgroundColor: const Color(0xFFFFC1D2),
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
                    '구독 저장',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
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

class _ThousandsSeparatorInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue,
      TextEditingValue newValue,
      ) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');

    if (digits.isEmpty) {
      return const TextEditingValue();
    }

    final number = int.tryParse(digits);

    if (number == null) {
      return oldValue;
    }

    final formatted = _formatAmount(number);

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

String _formatAmount(int amount) {
  return amount.toString().replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
        (match) => '${match[1]},',
  );
}
