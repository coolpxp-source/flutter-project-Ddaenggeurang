import 'package:flutter/material.dart';

import '../../services/subscription_service.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '구독 추가',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Text(
                '매달 결제되는 구독 정보를 등록해 주세요.',
                style: TextStyle(
                  fontSize: 15,
                  color: Color(0xFF667085),
                ),
              ),
              const SizedBox(height: 24),

              TextFormField(
                controller: _nameController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: '구독 서비스명',
                  hintText: '예: 넷플릭스',
                  prefixIcon: Icon(
                    Icons.subscriptions_outlined,
                  ),
                  border: OutlineInputBorder(),
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
              const SizedBox(height: 16),

              TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: '월 결제 금액',
                  hintText: '예: 17000',
                  prefixIcon: Icon(
                    Icons.payments_outlined,
                  ),
                  suffixText: '원',
                  border: OutlineInputBorder(),
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
              const SizedBox(height: 16),

              TextFormField(
                controller: _paymentDayController,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) {
                  if (!_isSaving) {
                    _saveSubscription();
                  }
                },
                decoration: const InputDecoration(
                  labelText: '매월 결제일',
                  hintText: '1~31',
                  prefixIcon: Icon(
                    Icons.calendar_month_outlined,
                  ),
                  suffixText: '일',
                  border: OutlineInputBorder(),
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
              const SizedBox(height: 28),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed:
                  _isSaving ? null : _saveSubscription,
                  child: _isSaving
                      ? const SizedBox(
                    width: 22,
                    height: 22,
                    child:
                    CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  )
                      : const Text(
                    '구독 저장',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight:
                      FontWeight.bold,
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