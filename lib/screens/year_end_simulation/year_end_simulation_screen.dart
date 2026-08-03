import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/year_end_simulation_model.dart';
import '../../services/year_end_simulation_service.dart';
import '../../utils/app_colors.dart';
import '../../utils/formatters.dart';
import '../../utils/korean_amount.dart';
import 'year_end_simulation_list_screen.dart';

class YearEndSimulationScreen extends StatefulWidget {
  const YearEndSimulationScreen({Key? key}) : super(key: key);

  @override
  State<YearEndSimulationScreen> createState() => _YearEndSimulationScreenState();
}

class _YearEndSimulationScreenState extends State<YearEndSimulationScreen> {
  final _salaryController = TextEditingController();
  final _creditController = TextEditingController();
  final _debitController = TextEditingController();
  final _service = YearEndSimulationService();

  int _estimatedDeduction = 0;
  bool _isSaving = false;

  void _calculateTax() {
    final salary = parseAmount(_salaryController.text);
    final credit = parseAmount(_creditController.text);
    final debit = parseAmount(_debitController.text);
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

  Future<void> _saveSimulation() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null || _estimatedDeduction == 0) return;

    setState(() => _isSaving = true);
    try {
      await _service.saveSimulation(
        userId: userId,
        simulation: YearEndSimulationModel(
          simId: '',
          income: parseAmount(_salaryController.text),
          deductions: {
            'creditCardUsage': parseAmount(_creditController.text),
            'debitCardUsage': parseAmount(_debitController.text),
          },
          estimatedRefund: _estimatedDeduction,
        ),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('시뮬레이션 결과를 저장했어요')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

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

  InputDecoration _deco(String hint) => InputDecoration(
    filled: true,
    fillColor: Colors.white,
    hintText: hint,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final koreanText = koreanAmountText(_estimatedDeduction);

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('연말정산 미리보기', style: TextStyle(color: AppColors.ink)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.history, color: AppColors.ink),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const YearEndSimulationListScreen()),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('올해 총급여액을 입력해주세요', style: TextStyle(color: AppColors.ink)),
            const SizedBox(height: 12),
            TextField(
              controller: _salaryController,
              keyboardType: TextInputType.number,
              inputFormatters: [CurrencyFormatter()],
              decoration: _deco('총급여액 입력'),
              onChanged: (value) => _calculateTax(),
            ),
            const SizedBox(height: 32),
            const Text('신용카드 사용액', style: TextStyle(color: AppColors.ink)),
            const SizedBox(height: 12),
            TextField(
              controller: _creditController,
              keyboardType: TextInputType.number,
              inputFormatters: [CurrencyFormatter()],
              decoration: _deco('신용카드 사용액 입력'),
              onChanged: (value) => _calculateTax(),
            ),
            const SizedBox(height: 20),

            const Text('체크카드 사용액', style: TextStyle(color: AppColors.ink)),
            const SizedBox(height: 12),
            TextField(
              controller: _debitController,
              keyboardType: TextInputType.number,
              inputFormatters: [CurrencyFormatter()],
              decoration: _deco('체크카드 사용액 입력'),
              onChanged: (value) => _calculateTax(),
            ),
            const SizedBox(height: 32),
            // 결과 영역
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.savingSoft,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  const Text('예상 소득공제액', style: TextStyle(color: AppColors.ink)),
                  const SizedBox(height: 8),
                  Text(
                    '${CurrencyFormatter.format(_estimatedDeduction)} 원',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: AppColors.ink,
                    ),
                  ),
                  if (koreanText.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      koreanText,
                      style: const TextStyle(fontSize: 13, color: AppColors.inkSub),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 54,
              child: ElevatedButton(
                onPressed: (_isSaving || _estimatedDeduction == 0) ? null : _saveSimulation,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.ink,
                  disabledBackgroundColor: const Color(0xFFE5E8EB),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: _isSaving
                    ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                )
                    : const Text('결과 저장하기', style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              '* 본 결과는 간이 시뮬레이션이며 실제 결과와 다를 수 있습니다.',
              style: TextStyle(fontSize: 12, color: AppColors.inkSub),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}