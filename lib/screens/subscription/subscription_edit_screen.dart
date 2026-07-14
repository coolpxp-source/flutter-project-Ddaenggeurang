import 'package:flutter/material.dart';

import '../../models/subscription_model.dart';
import '../../services/subscription_service.dart';

class SubscriptionEditScreen extends StatefulWidget {
  // 현재 로그인한 사용자 UID
  final String userId;

  // 수정하려는 구독 데이터
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
  // Form 전체의 입력값 검사를 위한 키
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  // 입력창 값 관리
  late final TextEditingController _nameController;
  late final TextEditingController _amountController;
  late final TextEditingController _paymentDayController;

  // Firestore 수정 기능을 사용하기 위한 서비스 객체
  final SubscriptionService _subscriptionService =
  SubscriptionService();

  // 구독 활성화 여부
  late bool _isActive;

  // 수정 요청 중인지 확인
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();

    // 기존 구독 정보를 입력창의 초기값으로 넣음
    _nameController = TextEditingController(
      text: widget.subscription.name,
    );

    _amountController = TextEditingController(
      text: widget.subscription.amount.toString(),
    );

    _paymentDayController = TextEditingController(
      text: widget.subscription.paymentDay.toString(),
    );

    // 기존 활성화 상태 저장
    _isActive = widget.subscription.isActive;
  }

  /// 수정한 구독 정보를 Firestore에 저장하는 함수
  Future<void> _updateSubscription() async {
    // 입력값 검사에 실패하면 수정하지 않음
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // 서비스명 가져오기
    final String name = _nameController.text.trim();

    // 쉼표를 제거하고 숫자로 변환
    final int? amount = int.tryParse(
      _amountController.text.replaceAll(',', '').trim(),
    );

    // 결제일을 숫자로 변환
    final int? paymentDay = int.tryParse(
      _paymentDayController.text.trim(),
    );

    // 숫자 변환에 실패하면 중단
    if (amount == null || paymentDay == null) {
      return;
    }

    // 버튼 중복 클릭 방지
    setState(() {
      _isSaving = true;
    });

    try {
      // Firestore 문서 수정
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

      // 수정 성공 메시지
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('구독 정보가 수정되었습니다.'),
        ),
      );

      // 수정 완료 후 구독 목록 화면으로 돌아감
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) {
        return;
      }

      // 수정 실패 메시지
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
    // 화면이 종료될 때 Controller 메모리 정리
    _nameController.dispose();
    _amountController.dispose();
    _paymentDayController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 상단 앱바
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
                '등록된 구독 정보를 수정할 수 있습니다.',
                style: TextStyle(
                  fontSize: 15,
                  color: Color(0xFF667085),
                ),
              ),
              const SizedBox(height: 24),

              // 구독 서비스명 입력창
              TextFormField(
                controller: _nameController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: '구독 서비스명',
                  prefixIcon: Icon(
                    Icons.subscriptions_outlined,
                  ),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '구독 서비스명을 입력하세요.';
                  }

                  if (value.trim().length > 30) {
                    return '서비스명은 30자 이하로 입력하세요.';
                  }

                  return null;
                },
              ),
              const SizedBox(height: 16),

              // 월 결제 금액 입력창
              TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: '월 결제 금액',
                  prefixIcon: Icon(
                    Icons.payments_outlined,
                  ),
                  suffixText: '원',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  final int? amount = int.tryParse(
                    value?.replaceAll(',', '').trim() ?? '',
                  );

                  if (amount == null) {
                    return '금액을 숫자로 입력하세요.';
                  }

                  if (amount <= 0) {
                    return '금액은 0원보다 커야 합니다.';
                  }

                  return null;
                },
              ),
              const SizedBox(height: 16),

              // 매월 결제일 입력창
              TextFormField(
                controller: _paymentDayController,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  labelText: '매월 결제일',
                  prefixIcon: Icon(
                    Icons.calendar_month_outlined,
                  ),
                  suffixText: '일',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  final int? paymentDay = int.tryParse(
                    value?.trim() ?? '',
                  );

                  if (paymentDay == null) {
                    return '결제일을 숫자로 입력하세요.';
                  }

                  if (paymentDay < 1 || paymentDay > 31) {
                    return '결제일은 1일부터 31일 사이로 입력하세요.';
                  }

                  return null;
                },
              ),
              const SizedBox(height: 16),

              // 구독 활성화 여부
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  '구독 사용 여부',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Text(
                  _isActive
                      ? '현재 사용 중인 구독입니다.'
                      : '현재 중지된 구독입니다.',
                ),
                value: _isActive,
                onChanged: (value) {
                  setState(() {
                    _isActive = value;
                  });
                },
              ),
              const SizedBox(height: 28),

              // 수정 저장 버튼
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  // 저장 중에는 버튼 비활성화
                  onPressed:
                  _isSaving ? null : _updateSubscription,
                  child: _isSaving
                      ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  )
                      : const Text(
                    '수정 저장',
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