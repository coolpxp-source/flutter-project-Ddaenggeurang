import 'package:flutter/material.dart';

import '../../models/subscription_model.dart';
import '../../services/subscription_service.dart';

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

class _SubscriptionEditScreenState
    extends State<SubscriptionEditScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _amountController;
  late final TextEditingController _paymentDayController;

  final SubscriptionService _subscriptionService =
  SubscriptionService();

  bool _isActive = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();

    // 기존 구독 정보를 입력창 초기값으로 설정
    _nameController = TextEditingController(
      text: widget.subscription.name,
    );

    _amountController = TextEditingController(
      text: widget.subscription.amount.toString(),
    );

    _paymentDayController = TextEditingController(
      text: widget.subscription.paymentDay.toString(),
    );

    _isActive = widget.subscription.isActive;
  }

  /// 수정한 구독 정보를 Firestore에 저장
  Future<void> _updateSubscription() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final String name = _nameController.text.trim();

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

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('구독 정보가 수정되었습니다.'),
        ),
      );

      // 수정 완료 후 목록 화면으로 돌아가기
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '구독 수정 중 오류가 발생했습니다.\n$e',
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
          '구독 수정',
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
                '등록한 구독 정보를 수정할 수 있습니다.',
                style: TextStyle(
                  fontSize: 15,
                  color: Color(0xFF667085),
                ),
              ),
              const SizedBox(height: 24),

              // 구독 서비스명
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

              // 월 결제 금액
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

              // 매월 결제일
              TextFormField(
                controller: _paymentDayController,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) {
                  if (!_isSaving) {
                    _updateSubscription();
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
              const SizedBox(height: 16),

              // 구독 활성화 여부
              Container(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: const Color(0xFFE4E7EC),
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: SwitchListTile(
                  title: const Text(
                    '구독 이용 상태',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    _isActive
                        ? '현재 이용 중인 구독입니다.'
                        : '현재 중지된 구독입니다.',
                  ),
                  value: _isActive,
                  onChanged: (value) {
                    setState(() {
                      _isActive = value;
                    });
                  },
                ),
              ),
              const SizedBox(height: 28),

              // 수정 저장 버튼
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: _isSaving
                      ? null
                      : _updateSubscription,
                  child: _isSaving
                      ? const SizedBox(
                    width: 22,
                    height: 22,
                    child:
                    CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                      : const Text(
                    '수정 저장',
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