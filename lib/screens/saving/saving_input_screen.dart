import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import '../../utils/formatters.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/saving_model.dart';
import '../../services/saving_service.dart';

class SavingInputScreen extends StatefulWidget {
  const SavingInputScreen({super.key});

  @override
  State<SavingInputScreen> createState() => _SavingInputScreenState();
}

class _SavingInputScreenState extends State<SavingInputScreen> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _accountNameController = TextEditingController();
  final TextEditingController _memoController = TextEditingController();

  // 투자 전용 컨트롤러
  final TextEditingController _brokerageController = TextEditingController();
  final TextEditingController _assetNameController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();

  final SavingService _savingService = SavingService();

  DateTime _selectedDate = DateTime.now();

  // 저축 소분류
  final List<String> _savingCategories = ['청약', '적금', '예금', '파킹통장', '투자'];
  String _selectedCategory = '적금'; // 기본값

  int _currentAmount = 0;

  @override
  void initState() {
    super.initState();
    _amountController.addListener(() {
      final text = _amountController.text.replaceAll(',', '');
      setState(() {
        _currentAmount = int.tryParse(text) ?? 0;
      });
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    _accountNameController.dispose();
    _memoController.dispose();
    _brokerageController.dispose();
    _assetNameController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  Future<void> _saveSaving() async {
    if (_currentAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('저축/투자 금액을 입력해주세요!')),
      );
      return;
    }

    // 🚨 투자 카테고리일 때 필수값 방어 로직
    if (_selectedCategory == '투자') {
      if (_brokerageController.text.isEmpty || _assetNameController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('증권사명과 종목명을 모두 입력해주세요!')),
        );
        return;
      }
    }

    try {
      final String userId = FirebaseAuth.instance.currentUser?.uid ?? 'test_user_id';

      // 아이디 확인용
      // print('1. 파이어베이스 인증 UID: [${FirebaseAuth.instance.currentUser?.uid}]');
      // print('2. 변수에 담긴 UID: [$userId]');

      // 1. 투자 정보 객체 생성 (카테고리가 '투자'일 때만)
      InvestmentDetail? investmentDetail;
      if (_selectedCategory == '투자') {
        investmentDetail = InvestmentDetail(
          brokerage: _brokerageController.text,
          assetName: _assetNameController.text,
          quantity: num.tryParse(_quantityController.text),
        );
      }

      // 2. 저축 모델 생성
      final newSaving = SavingModel(
        savingId: '',
        userId: userId,
        date: _selectedDate,
        categoryId: _selectedCategory,
        accountName: _accountNameController.text.isNotEmpty ? _accountNameController.text : null,
        amount: _currentAmount,
        memo: _memoController.text.isEmpty ? null : _memoController.text,
        investmentDetail: investmentDetail,
      );

      await _savingService.addSaving(newSaving);

      debugPrint('✅ 저축 저장 시도: 금액=$_currentAmount, 분류=$_selectedCategory');
      if (investmentDetail != null) {
        debugPrint('📈 투자 상세: ${investmentDetail.brokerage} / ${investmentDetail.assetName}');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('성공적으로 기록되었습니다!')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('🔥 저장 에러: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('저장 실패: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('저축 / 투자 기록')), // 색상 제거, 기본 테마 사용
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. 금액 입력 (지출/수입 폼과 완벽 동일한 스타일)
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              inputFormatters: [CurrencyFormatter()],
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              decoration: const InputDecoration(
                labelText: '이체 / 매수 금액',
                prefixText: '₩ ',
                prefixStyle: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),

            // 2. 분류 선택
            const Text('1. 분류', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8.0,
              children: _savingCategories.map((category) {
                return ChoiceChip(
                  label: Text(category),
                  selected: _selectedCategory == category,
                  onSelected: (bool selected) {
                    if (selected) {
                      setState(() => _selectedCategory = category);
                    }
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // 3. 계좌명 입력 (공통)
            const Text('2. 계좌 정보', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 8),
            TextField(
              controller: _accountNameController,
              decoration: const InputDecoration(
                labelText: '계좌명 (선택) - 예: 국민은행 청년희망적금',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),

            // 4. 투자 선택 시에만 펼쳐지는 부가 입력 폼
            if (_selectedCategory == '투자') ...[
              const Divider(thickness: 2),
              const Text('투자 상세 정보', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _brokerageController,
                      decoration: const InputDecoration(
                        labelText: '증권사명 (필수)',
                        hintText: '예: 토스증권',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextField(
                      controller: _quantityController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: '매수 수량 (선택)',
                        hintText: '예: 2.5',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _assetNameController,
                decoration: const InputDecoration(
                  labelText: '종목명 (필수)',
                  hintText: '예: S&P500 ETF',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),
              const Divider(thickness: 2),
            ],

            // 5. 날짜 및 메모 (공통 레이아웃 유지)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('기록일: ${_selectedDate.toLocal().toString().split(' ')[0]}'),
                OutlinedButton(
                  onPressed: () async {
                    final DateTime? picked = await showDatePicker(
                      context: context,
                      initialDate: _selectedDate,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) {
                      setState(() => _selectedDate = picked);
                    }
                  },
                  child: const Text('날짜 변경'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _memoController,
              decoration: const InputDecoration(
                labelText: '메모 (선택)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 32),

            // 6. 저장 버튼 (수입/지출과 동일한 파란색 계열 적용)
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.blueAccent,
                foregroundColor: Colors.white,
              ),
              onPressed: _saveSaving,
              child: const Text('저장하기', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}