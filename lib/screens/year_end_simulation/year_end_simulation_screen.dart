import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/year_end_simulation_model.dart';
import '../../services/year_end_simulation_service.dart';
import '../../utils/formatters.dart';
import '../../utils/korean_amount.dart';
import '../../utils/year_end_tax_calculator.dart';
import '../../widgets/common/ddaeng_modal.dart';
import 'year_end_simulation_list_screen.dart';

const Color _mainColor = Color(0xFF1FA97D);
const Color _mainSoftColor = Color(0xFFE3F6EE);
const Color _mainBorderSoftColor = Color(0xFFC9EDDC);

class YearEndSimulationScreen extends StatefulWidget {
  const YearEndSimulationScreen({super.key});

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

    final result = YearEndTaxCalculator.calculate(salary: salary, credit: credit, debit: debit);
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

  InputDecoration _inputDecoration({
    required String hintText,
    required IconData prefixIcon,
    String? suffixText,
  }) {
    OutlineInputBorder border(Color color, {double width = 1}) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: color, width: width),
    );

    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(color: Color(0xFFAAAAAA), fontSize: 13),
      prefixIcon: Icon(prefixIcon, color: _mainColor),
      suffixText: suffixText,
      suffixStyle: const TextStyle(color: Color(0xFF555555), fontSize: 13, fontWeight: FontWeight.w700),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
      border: border(const Color(0xFFE6E3E7)),
      enabledBorder: border(const Color(0xFFE6E3E7)),
      focusedBorder: border(_mainColor, width: 1.5),
      errorBorder: border(Colors.redAccent),
      focusedErrorBorder: border(Colors.redAccent, width: 1.5),
    );
  }

  Widget _sectionTitle(String title, {required IconData icon}) {
    return Row(
      children: [
        Icon(icon, size: 16, color: _mainColor),
        const SizedBox(width: 6),
        Text(title, style: const TextStyle(color: Color(0xFF333333), fontSize: 14, fontWeight: FontWeight.w800)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final koreanText = koreanAmountText(_estimatedDeduction);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F7FA),
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        backgroundColor: const Color(0xFFF8F7FA),
        surfaceTintColor: Colors.transparent,
        foregroundColor: const Color(0xFF222222),
        title: const Text('연말정산 미리보기', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: IconButton(
              tooltip: '지난 기록 보기',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const YearEndSimulationListScreen()),
              ),
              style: IconButton.styleFrom(
                backgroundColor: _mainSoftColor,
                foregroundColor: _mainColor,
              ),
              icon: const Icon(Icons.history_rounded, size: 19),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              decoration: BoxDecoration(
                color: _mainSoftColor,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: _mainBorderSoftColor),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                    child: const Icon(Icons.receipt_long_rounded, color: _mainColor, size: 22),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Text('총급여와 카드 사용액으로\n예상 소득공제액을 확인해보세요.',
                        style: TextStyle(color: Color(0xFF1B6E52), fontSize: 12, fontWeight: FontWeight.w600, height: 1.5)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 26),
            _sectionTitle('올해 총급여액', icon: Icons.account_balance_wallet_rounded),
            const SizedBox(height: 10),
            TextField(
              controller: _salaryController,
              keyboardType: TextInputType.number,
              inputFormatters: [CurrencyFormatter()],
              decoration: _inputDecoration(
                hintText: '총급여액 입력',
                prefixIcon: Icons.account_balance_wallet_rounded,
                suffixText: '원',
              ),
              onChanged: (_) => _calculateTax(),
            ),
            const SizedBox(height: 24),
            _sectionTitle('신용카드 사용액', icon: Icons.credit_card_rounded),
            const SizedBox(height: 10),
            TextField(
              controller: _creditController,
              keyboardType: TextInputType.number,
              inputFormatters: [CurrencyFormatter()],
              decoration: _inputDecoration(
                hintText: '신용카드 사용액 입력',
                prefixIcon: Icons.credit_card_rounded,
                suffixText: '원',
              ),
              onChanged: (_) => _calculateTax(),
            ),
            const SizedBox(height: 24),
            _sectionTitle('체크카드 사용액', icon: Icons.payment_rounded),
            const SizedBox(height: 10),
            TextField(
              controller: _debitController,
              keyboardType: TextInputType.number,
              inputFormatters: [CurrencyFormatter()],
              decoration: _inputDecoration(
                hintText: '체크카드 사용액 입력',
                prefixIcon: Icons.payment_rounded,
                suffixText: '원',
              ),
              onChanged: (_) => _calculateTax(),
            ),
            const SizedBox(height: 26),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF1FA97D), Color(0xFF5FCBA4)],
                ),
                borderRadius: BorderRadius.circular(22),
              ),
              child: Column(
                children: [
                  const Text('예상 소득공제액',
                      style: TextStyle(fontSize: 13, color: Colors.white70, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Text(
                    '${CurrencyFormatter.format(_estimatedDeduction)}원',
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Colors.white),
                  ),
                  if (koreanText.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(koreanText, style: const TextStyle(fontSize: 12.5, color: Colors.white70)),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: (_isSaving || parseAmount(_salaryController.text) <= 0) ? null : _saveSimulation,
                style: ElevatedButton.styleFrom(
                  elevation: 0,
                  backgroundColor: _mainColor,
                  disabledBackgroundColor: const Color(0xFFAEE0CB),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)),
                ),
                child: _isSaving
                    ? const SizedBox(
                  width: 23, height: 23,
                  child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                )
                    : const Text('결과 저장하기', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              '* 본 결과는 간이 시뮬레이션이며 실제 결과와 다를 수 있습니다.',
              style: TextStyle(fontSize: 11.5, color: Color(0xFF999999)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}