import 'package:flutter/material.dart';
// import '../../utils/app_colors.dart'; // AppColors 경로에 맞게 수정하세요.
// import '../../utils/formatters.dart'; // CurrencyFormatter 등

class TaxSimulationScreen extends StatefulWidget {
  const TaxSimulationScreen({Key? key}) : super(key: key);

  @override
  State<TaxSimulationScreen> createState() => _TaxSimulationScreenState();
}

class _TaxSimulationScreenState extends State<TaxSimulationScreen> {
  final _salaryController = TextEditingController();
  final _creditController = TextEditingController();
  final _debitController = TextEditingController();

  int _estimatedDeduction = 0;

  void _calculateTax() {
    final salary = _parse(_salaryController.text);
    final credit = _parse(_creditController.text);
    final debit = _parse(_debitController.text);
    final totalUsage = credit + debit;

    if (salary <= 0 || totalUsage <= 0) {
      setState(() => _estimatedDeduction = 0);
      return;
    }

    final threshold = (salary * 0.25).round();
    final excessAmount = totalUsage - threshold;
    if (excessAmount <= 0) {
      setState(() => _estimatedDeduction = 0);
      return;
    }

    final creditRatio = credit / totalUsage;
    final debitRatio = debit / totalUsage;
    var deduction = (excessAmount * creditRatio * 0.15).round() +
        (excessAmount * debitRatio * 0.30).round();

    final limit = _deductionLimitFor(salary);
    if (deduction > limit) deduction = limit;

    setState(() => _estimatedDeduction = deduction);
  }

  int _parse(String text) => int.tryParse(text.replaceAll(',', '')) ?? 0;

  int _deductionLimitFor(int salary) {
    if (salary <= 70000000) return 3000000;
    if (salary <= 120000000) return 2500000;
    return 2000000;
  }

  @override
  void dispose() {
    _salaryController.dispose();
    _creditController.dispose();
    _debitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F0), // AppColors.bg
      appBar: AppBar(
        title: const Text('연말정산 미리보기', style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('올해 총급여액을 입력해주세요'),
            const SizedBox(height: 12),
            TextField(
              controller: _salaryController,
              keyboardType: TextInputType.number,
              // inputFormatters: [CurrencyFormatter()],
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white,
                hintText: '총급여액 입력',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (value) => _calculateTax(),
            ),
            const SizedBox(height: 32),
            const Text('신용카드 사용액'),
            const SizedBox(height: 12),
            TextField(
              controller: _creditController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white,
                hintText: '신용카드 사용액 입력',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (value) => _calculateTax(),
            ),
            const SizedBox(height: 20),

            const Text('체크카드 사용액'),
            const SizedBox(height: 12),
            TextField(
              controller: _debitController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white,
                hintText: '체크카드 사용액 입력',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (value) => _calculateTax(),
            ),
            const SizedBox(height: 32),
            // 결과 영역
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFFD7F3EF), // AppColors.savingSoft
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  const Text('예상 소득공제액'),
                  const SizedBox(height: 8),
                  Text(
                    '$_estimatedDeduction 원', // koreanAmountText() 적용 예정
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              '* 본 결과는 간이 시뮬레이션이며 실제 결과와 다를 수 있습니다.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}