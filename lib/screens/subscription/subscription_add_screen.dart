import 'package:flutter/material.dart';

import '../../services/subscription_service.dart';

// 앱 공통 핑크 테마 컬러 (구독관리 도메인)
const Color _mainColor = Color(0xFFFF6F91);

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

  final TextEditingController _nameController =
  TextEditingController();

  final TextEditingController _amountController =
  TextEditingController();

  final TextEditingController _paymentDayController =
  TextEditingController();

  final SubscriptionService _subscriptionService =
  SubscriptionService();

  bool _isSaving = false;

  /// 입력한 구독 정보를 Firestore에 저장
  Future<void> _saveSubscription() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final String name =
    _nameController.text.trim();

    final int? amount = int.tryParse(
      _amountController.text
          .replaceAll(',', '')
          .trim(),
    );

    final int? paymentDay = int.tryParse(
      _paymentDayController.text.trim(),
    );

    if (amount == null || paymentDay == null) {
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

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('구독이 저장되었습니다.'),
          behavior: SnackBarBehavior.floating,
        ),
      );

      // 저장 성공 후 목록 화면으로 돌아감
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '구독 저장 중 오류가 발생했습니다.\n$e',
          ),
          behavior: SnackBarBehavior.floating,
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

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _paymentDayController.dispose();

    super.dispose();
  }

  /// 공통 입력창 디자인 (다른 화면들과 동일한 톤)
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
        color: _mainColor,
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

  /// 입력 영역 제목 (아이콘 + 텍스트)
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
                  color: const Color(0xFFFFE3EC),
                  borderRadius: BorderRadius.circular(22),
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
              TextFormField(
                controller: _nameController,
                textInputAction: TextInputAction.next,
                decoration: _inputDecoration(
                  hintText: '예: 넷플릭스',
                  prefixIcon: Icons.subscriptions_rounded,
                ),
                validator: (value) {
                  if (value == null ||
                      value.trim().isEmpty) {
                    return '구독 서비스명을 입력하세요.';
                  }

                  if (value.trim().length > 30) {
                    return '서비스명은 30자 이하로 입력하세요.';
                  }

                  return null;
                },
              ),
              const SizedBox(height: 24),

              _buildSectionTitle(
                '월 결제 금액',
                icon: Icons.payments_rounded,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                decoration: _inputDecoration(
                  hintText: '예: 17000',
                  suffixText: '원',
                  prefixIcon: Icons.payments_rounded,
                ),
                validator: (value) {
                  final int? amount = int.tryParse(
                    value
                        ?.replaceAll(',', '')
                        .trim() ??
                        '',
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
              TextFormField(
                controller: _paymentDayController,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) {
                  if (!_isSaving) {
                    _saveSubscription();
                  }
                },
                decoration: _inputDecoration(
                  hintText: '1~31',
                  suffixText: '일',
                  prefixIcon: Icons.calendar_month_rounded,
                ),
                validator: (value) {
                  final int? paymentDay =
                  int.tryParse(
                    value?.trim() ?? '',
                  );

                  if (paymentDay == null) {
                    return '결제일을 숫자로 입력하세요.';
                  }

                  if (paymentDay < 1 ||
                      paymentDay > 31) {
                    return '결제일은 1일부터 31일 사이로 입력하세요.';
                  }

                  return null;
                },
              ),
              const SizedBox(height: 30),

              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed:
                  _isSaving ? null : _saveSubscription,
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
                    child:
                    CircularProgressIndicator(
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