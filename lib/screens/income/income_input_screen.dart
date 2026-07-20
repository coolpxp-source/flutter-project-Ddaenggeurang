import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import '../../utils/formatters.dart';
import 'package:intl/intl.dart'; // 프리랜서 세전 금액(NumberFormat) 계산용
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/income_model.dart';
import '../../services/income_service.dart';

class IncomeInputScreen extends StatefulWidget {
  const IncomeInputScreen({super.key});

  @override
  State<IncomeInputScreen> createState() => _IncomeInputScreenState();
}

class _IncomeInputScreenState extends State<IncomeInputScreen> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _memoController = TextEditingController();
  final IncomeService _incomeService = IncomeService();

  DateTime _selectedDate = DateTime.now();
  IncomeSource _selectedSource = IncomeSource.salary; // 기본값: 월급

  // 🚀 부가 자동화 상태 변수
  bool _isRecurring = false;
  int _payDay = 1;

  int _currentAmount = 0;

  @override
  void initState() {
    super.initState();
    // 금액 입력 시 실시간 세전 계산을 위한 리스너
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
    _memoController.dispose();
    super.dispose();
  }

  Future<void> _saveIncome() async {
    if (_currentAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('수입 금액을 입력해주세요!')),
      );
      return;
    }

    try {
      final String userId = FirebaseAuth.instance.currentUser?.uid ?? 'test_user_id';
      final String? recurringTemplateId = _isRecurring ? 'temp_recurring_income_id' : null;

      final newIncome = IncomeModel(
        incomeId: '',
        userId: userId,
        amount: _currentAmount,
        incomeSource: _selectedSource,
        date: _selectedDate,
        memo: _memoController.text,
        recurringIncomeTemplateId: recurringTemplateId,
      );

      await _incomeService.addIncome(newIncome);

      debugPrint('✅ 수입 저장 시도: 금액=$_currentAmount, 출처=${_selectedSource.label}');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('수입 내역이 저장되었습니다!')),
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
    // 명세서 규칙: 프리랜서 소득 3.3% 원천징수 기준 세전 금액 역산
    final double estimatedGross = _currentAmount / 0.967;

    return Scaffold(
      appBar: AppBar(title: const Text('수입 기록')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. 금액 입력 (지출 폼과 동일한 위치 배치)
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              inputFormatters: [CurrencyFormatter()],
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              decoration: const InputDecoration(
                labelText: '실수령액 (세후 금액)',
                prefixText: '₩ ',
                prefixStyle: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                border: OutlineInputBorder(),
              ),
            ),

            // 💡 프리랜서 전용: 금액 아래에 바로 세전 안내 문구 표시
            if (_selectedSource == IncomeSource.freelanceIncome && _currentAmount > 0)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  '약 ${NumberFormat('#,###').format(estimatedGross)}원 (세전 추정)',
                  style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.right,
                ),
              ),
            const SizedBox(height: 24),

            // 2. 수입 분류 (지출 성격 선택과 동일한 UI)
            const Text('1. 수입 분류', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8.0,
              children: IncomeSource.values.map((source) {
                return ChoiceChip(
                  label: Text(source.label),
                  selected: _selectedSource == source,
                  onSelected: (bool selected) {
                    if (selected) {
                      setState(() {
                        _selectedSource = source;
                        // 매달 들어오는 성격이 아니면 반복 스위치 초기화
                        if (source != IncomeSource.salary && source != IncomeSource.allowance) {
                          _isRecurring = false;
                        }
                      });
                    }
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            // 3. 정기 수입 부가 기능 (지출의 할부/구독 기능과 동일한 배치)
            if (_selectedSource == IncomeSource.salary || _selectedSource == IncomeSource.allowance) ...[
              const Divider(thickness: 2),
              const Text('부가 기능 연결 (옵션)', style: TextStyle(fontWeight: FontWeight.bold)),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('매달 자동으로 기록하기'),
                subtitle: const Text('매월 설정한 날짜에 자동으로 내역이 생성됩니다.'),
                value: _isRecurring,
                onChanged: (bool value) {
                  setState(() => _isRecurring = value);
                },
              ),
              if (_isRecurring)
                Row(
                  children: [
                    const Text('매월 입금일: '),
                    const SizedBox(width: 16),
                    DropdownButton<int>(
                      value: _payDay,
                      items: List.generate(31, (index) => index + 1).map((int day) {
                        return DropdownMenuItem<int>(
                          value: day,
                          child: Text('$day일'),
                        );
                      }).toList(),
                      onChanged: (int? newDay) {
                        if (newDay != null) {
                          setState(() => _payDay = newDay);
                        }
                      },
                    ),
                  ],
                ),
              const Divider(thickness: 2),
              const SizedBox(height: 16),
            ],

            // 4. 날짜 및 메모 (지출 폼과 완벽하게 동일)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('입금일: ${_selectedDate.toLocal().toString().split(' ')[0]}'),
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

            // 저장 버튼
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.blueAccent, // 지출 폼과 동일한 테마 컬러로 통일
                foregroundColor: Colors.white,
              ),
              onPressed: _saveIncome,
              child: const Text('저장하기', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}