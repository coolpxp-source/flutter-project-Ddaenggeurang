import 'package:flutter/material.dart';

import '../../services/subscription_service.dart';

class SubscriptionAddScreen extends StatefulWidget {
  // 현재 로그인한 사용자의 Firebase UID
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
  // 입력값 검사를 위한 Form 키
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  // 각 입력창의 값을 관리하는 Controller
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _paymentDayController =
  TextEditingController();

  // Firestore 구독 저장 기능을 담당하는 서비스
  final SubscriptionService _subscriptionService = SubscriptionService();

  // 저장 진행 중 여부
  // true일 때 저장 버튼을 비활성화해서 중복 저장을 막음
  bool _isSaving = false;

  /// 입력한 구독 정보를 Firestore에 저장하는 함수
  Future<void> _saveSubscription() async {
    // Form 입력값 검사
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // 구독 서비스명
    final String name = _nameController.text.trim();

    // 금액의 쉼표를 제거한 후 정수로 변환
    final int? amount = int.tryParse(
      _amountController.text.replaceAll(',', '').trim(),
    );

    // 결제일을 정수로 변환
    final int? paymentDay = int.tryParse(
      _paymentDayController.text.trim(),
    );

    // 숫자 변환에 실패한 경우 저장하지 않음
    if (amount == null || paymentDay == null) {
      return;
    }

    // 저장 버튼 중복 클릭 방지
    setState(() {
      _isSaving = true;
    });

    try {
      debugPrint('============================');
      debugPrint('구독 추가 화면 저장 요청');
      debugPrint('화면에서 전달받은 UID: ${widget.userId}');
      debugPrint('서비스명: $name');
      debugPrint('금액: $amount');
      debugPrint('결제일: $paymentDay');
      debugPrint('============================');

      // SubscriptionService를 통해 Firestore에 저장
      await _subscriptionService.addSubscription(
        userId: widget.userId,
        name: name,
        amount: amount,
        paymentDay: paymentDay,
      );

      // 저장 완료 전에 화면이 종료됐으면 이후 작업을 실행하지 않음
      if (!mounted) {
        return;
      }

      // 저장 성공 메시지
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('구독이 저장되었습니다.'),
          duration: Duration(seconds: 2),
        ),
      );
      // 구독 목록 화면으로 돌아가기
      Navigator.pop(context, true);

      // 저장 성공 후 입력창 초기화
      _nameController.clear();
      _amountController.clear();
      _paymentDayController.clear();

      // 키보드 닫기
      FocusScope.of(context).unfocus();
    } catch (e, stackTrace) {
      // Android Studio Run 창에 정확한 오류 출력
      debugPrint('============================');
      debugPrint('구독 저장 실패');
      debugPrint('오류 내용: $e');
      debugPrint('스택트레이스:');
      debugPrint('$stackTrace');
      debugPrint('============================');

      if (!mounted) {
        return;
      }

      // 사용자 화면에도 오류 표시
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '구독 저장 실패\n$e',
          ),
          duration: const Duration(seconds: 8),
        ),
      );
    } finally {
      // 성공·실패와 관계없이 저장 상태 종료
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

              // 구독 서비스명 입력창
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
                  // 빈 값 검사
                  if (value == null || value.trim().isEmpty) {
                    return '구독 서비스명을 입력하세요.';
                  }

                  // 최대 글자 수 검사
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
                  hintText: '예: 17000',
                  prefixIcon: Icon(
                    Icons.payments_outlined,
                  ),
                  suffixText: '원',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  // 쉼표를 제거한 뒤 숫자로 변환
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
              const SizedBox(height: 16),

              // 매월 결제일 입력창
              TextFormField(
                controller: _paymentDayController,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,

                // 키보드 완료 버튼을 눌러도 저장 실행
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
              const SizedBox(height: 28),

              // 구독 저장 버튼
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  // 저장 중이면 버튼 비활성화
                  onPressed: _isSaving ? null : _saveSubscription,

                  child: _isSaving
                  // 저장 중 로딩 표시
                      ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  )
                  // 저장 전 기본 버튼
                      : const Text(
                    '구독 저장',
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