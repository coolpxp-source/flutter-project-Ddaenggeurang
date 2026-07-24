import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/subscription_model.dart';
import '../../services/subscription_service.dart';

const Color _mainColor = Color(0xFFFF6F91);
const Color _mainSoftColor = Color(0xFFFFE3EC);
const Color _mainBorderSoftColor = Color(0xFFFFD3E0);

class SubscriptionEditScreen extends StatefulWidget {
  final String userId;
  final SubscriptionModel subscription;

  const SubscriptionEditScreen({
    super.key,
    required this.userId,
    required this.subscription,
  });

  @override
  State<SubscriptionEditScreen> createState() =>
      _SubscriptionEditScreenState();
}

class _SubscriptionEditScreenState extends State<SubscriptionEditScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final SubscriptionService _subscriptionService = SubscriptionService();

  late final TextEditingController _amountController;
  late final TextEditingController _customServiceController;

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

  bool _isActive = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();

    final existingName = widget.subscription.name.trim();

    if (_serviceOptions.contains(existingName) &&
        existingName != '기타(직접 입력)') {
      _selectedService = existingName;
      _customServiceController = TextEditingController();
    } else {
      _selectedService = '기타(직접 입력)';
      _customServiceController = TextEditingController(
        text: existingName,
      );
    }

    _amountController = TextEditingController(
      text: _formatAmount(widget.subscription.amount),
    );

    _selectedPaymentDay = widget.subscription.paymentDay;
    _isActive = widget.subscription.isActive;
  }

  Future<void> _updateSubscription() async {
    FocusScope.of(context).unfocus();

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

    if (name == null ||
        name.isEmpty ||
        amount == null ||
        paymentDay == null) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      await _subscriptionService.updateSubscription(
        userId: widget.userId,
        subscriptionId: widget.subscription.id,
        name: name,
        amount: amount,
        paymentDay: paymentDay,
        isActive: _isActive,
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
                const Icon(
                  Icons.check_circle_rounded,
                  color: Colors.white,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '$name 구독 정보가 수정되었습니다.',
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
              '구독 수정 중 오류가 발생했습니다.\n$e',
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
    final currentMonthLastDay =
        DateTime(now.year, now.month + 1, 0).day;

    final initialDate = DateTime(
      now.year,
      now.month,
      (_selectedPaymentDay ?? now.day).clamp(
        1,
        currentMonthLastDay,
      ),
    );

    final selectedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 3),
      locale: const Locale('ko', 'KR'),
      helpText: '매월 결제일 선택',
      cancelText: '취소',
      confirmText: '선택',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: _mainColor,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Color(0xFF222222),
            ),
            datePickerTheme: DatePickerThemeData(
              backgroundColor: Colors.white,
              headerBackgroundColor: _mainColor,
              headerForegroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              dayShape: WidgetStatePropertyAll(
                RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            dialogTheme: DialogThemeData(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
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
    OutlineInputBorder createBorder(
        Color color, {
          double width = 1,
        }) {
      return OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: color,
          width: width,
        ),
      );
    }

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
      border: createBorder(const Color(0xFFE6E3E7)),
      enabledBorder: createBorder(const Color(0xFFE6E3E7)),
      focusedBorder: createBorder(
        _mainColor,
        width: 1.5,
      ),
      errorBorder: createBorder(Colors.redAccent),
      focusedErrorBorder: createBorder(
        Colors.redAccent,
        width: 1.5,
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
          '구독 수정',
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
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: _mainSoftColor,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: _mainBorderSoftColor,
                  ),
                ),
                child: const Row(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: Colors.white,
                      child: Icon(
                        Icons.edit_rounded,
                        color: _mainColor,
                        size: 20,
                      ),
                    ),
                    SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        '등록한 구독 정보를\n수정할 수 있습니다.',
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
                onChanged: _isSaving
                    ? null
                    : (value) {
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
                  enabled: !_isSaving,
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
                enabled: !_isSaving,
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
                validator: (_) {
                  if (_selectedPaymentDay == null) {
                    return '캘린더에서 결제일을 선택하세요.';
                  }
                  return null;
                },
                builder: (field) {
                  return InkWell(
                    onTap: _isSaving ? null : _selectPaymentDay,
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
                  );
                },
              ),
              const SizedBox(height: 24),
              _buildSectionTitle(
                '구독 이용 상태',
                icon: Icons.toggle_on_rounded,
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFFE6E3E7),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _isActive
                            ? '현재 이용 중인 구독입니다.'
                            : '현재 중지된 구독입니다.',
                        style: const TextStyle(
                          color: Color(0xFF555555),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Transform.scale(
                      scale: 0.85,
                      child: CupertinoSwitch(
                        value: _isActive,
                        onChanged: _isSaving
                            ? null
                            : (value) {
                          setState(() {
                            _isActive = value;
                          });
                        },
                        activeTrackColor: _mainColor,
                        inactiveTrackColor:
                        const Color(0xFFE3E3E8),
                        trackOutlineColor:
                        const WidgetStatePropertyAll(
                          Colors.transparent,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _isSaving
                      ? null
                      : _updateSubscription,
                  style: ElevatedButton.styleFrom(
                    elevation: 0,
                    backgroundColor: _mainColor,
                    disabledBackgroundColor:
                    const Color(0xFFFFC1D2),
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
                    '수정 저장',
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

class _ThousandsSeparatorInputFormatter
    extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue,
      TextEditingValue newValue,
      ) {
    final String digits = newValue.text.replaceAll(
      RegExp(r'[^0-9]'),
      '',
    );

    if (digits.isEmpty) {
      return const TextEditingValue();
    }

    final int? number = int.tryParse(digits);

    if (number == null) {
      return oldValue;
    }

    final String formatted = _formatAmount(number);

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(
        offset: formatted.length,
      ),
    );
  }
}

String _formatAmount(int amount) {
  return amount.toString().replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
        (match) => '${match[1]},',
  );
}
