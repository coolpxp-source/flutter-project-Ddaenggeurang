import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/year_end_simulation_model.dart';
import '../../services/year_end_simulation_service.dart';
import '../../utils/app_colors.dart';
import '../../utils/formatters.dart';
import '../../utils/korean_amount.dart';
import '../../utils/year_end_tax_calculator.dart';
import '../../widgets/common/ddaeng_modal.dart';
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

    final result = YearEndTaxCalculator.calculate(
      salary: salary,
      credit: credit,
      debit: debit,
    );

    setState(() => _estimatedDeduction = result.estimatedDeduction);
  }

  Future<void> _saveSimulation() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    final salary = parseAmount(_salaryController.text);

    if (userId == null || salary <= 0) {
      await DdaengModal.alert(
        context,
        title: '입력을 확인해주세요',
        message: '총급여액을 입력해주세요.',
        type: ModalType.warning,
      );
      return;
    }

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

      if (!mounted) return;
      setState(() => _isSaving = false);

      await DdaengModal.alert(
        context,
        title: '저장 완료',
        message: '시뮬레이션 결과를 저장했어요.',
        type: ModalType.success,
      );

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const YearEndSimulationListScreen()),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        await DdaengModal.alert(
          context,
          title: '저장에 실패했어요',
          message: '$e',
          type: ModalType.danger,
        );
      }
    }
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
    fillColor: AppColors.bg,
    hintText: hint,
    hintStyle: const TextStyle(fontSize: 13.5, color: AppColors.inkSub),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide.none,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final koreanText = koreanAmountText(_estimatedDeduction);

    return Scaffold(
      backgroundColor: Colors.white, // ← AppColors.bg에서 변경
      appBar: AppBar(
        title: const Text('연말정산 미리보기',
            style: TextStyle(color: AppColors.ink, fontWeight: FontWeight.w800, fontSize: 16)),
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
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
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('올해 총급여액을 입력해주세요',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.ink)),
            const SizedBox(height: 10),
            TextField(
              controller: _salaryController,
              keyboardType: TextInputType.number,
              inputFormatters: [CurrencyFormatter()],
              decoration: _deco('총급여액 입력'),
              onChanged: (value) => _calculateTax(),
            ),
            const SizedBox(height: 24),
            const Text('신용카드 사용액',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.ink)),
            const SizedBox(height: 10),
            TextField(
              controller: _creditController,
              keyboardType: TextInputType.number,
              inputFormatters: [CurrencyFormatter()],
              decoration: _deco('신용카드 사용액 입력'),
              onChanged: (value) => _calculateTax(),
            ),
            const SizedBox(height: 18),
            const Text('체크카드 사용액',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.ink)),
            const SizedBox(height: 10),
            TextField(
              controller: _debitController,
              keyboardType: TextInputType.number,
              inputFormatters: [CurrencyFormatter()],
              decoration: _deco('체크카드 사용액 입력'),
              onChanged: (value) => _calculateTax(),
            ),
            const SizedBox(height: 28),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.savingSoft,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  const Text('예상 소득공제액',
                      style: TextStyle(fontSize: 13, color: AppColors.ink, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Text(
                    '${CurrencyFormatter.format(_estimatedDeduction)} 원',
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.ink),
                  ),
                  if (koreanText.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(koreanText, style: const TextStyle(fontSize: 12.5, color: AppColors.inkSub)),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              height: 54,
              child: ElevatedButton(
                onPressed: (_isSaving || parseAmount(_salaryController.text) <= 0) ? null : _saveSimulation,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.ink,
                  disabledBackgroundColor: const Color(0xFFE5E8EB),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: _isSaving
                    ? const SizedBox(
                  width: 20, height: 20,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                )
                    : const Text('결과 저장하기', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              '* 본 결과는 간이 시뮬레이션이며 실제 결과와 다를 수 있습니다.',
              style: TextStyle(fontSize: 11.5, color: AppColors.inkSub),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}