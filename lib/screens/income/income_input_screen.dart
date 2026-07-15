import 'package:flutter/material.dart';
import '../../models/income_model.dart';
import '../../services/income_service.dart';

/// 수입 추가하기 - 사진업로드 없이 직접입력만 (수입은 명세서상 문자/영수증 파싱 대상 아님)
///
/// TODO: IncomeService가 아직 없다면 expense_service.dart 패턴 그대로
///       income_service.dart에 addIncome(IncomeModel) 메서드 추가 필요
/// TODO: "매달 자동 등록" 토글 켰을 때 RecurringIncomeTemplate 생성/조회 로직은
///       아직 미연결 — 지금은 이번 한 건만 IncomeModel로 저장됨
class IncomeInputScreen extends StatefulWidget {
  const IncomeInputScreen({super.key});

  @override
  State<IncomeInputScreen> createState() => _IncomeInputScreenState();
}

class _IncomeInputScreenState extends State<IncomeInputScreen> {
  final _incomeService = IncomeService();
  final _amountController = TextEditingController(text: '0');
  final _memoController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  IncomeSource _selectedSource = IncomeSource.salary;

  // 월급일 때만 노출되는 반복등록 옵션
  bool _isRecurring = false;
  int _payDay = DateTime.now().day.clamp(1, 28);

  @override
  void dispose() {
    _amountController.dispose();
    _memoController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  void _selectSource(IncomeSource source) {
    setState(() {
      _selectedSource = source;
      // 월급이 아니면 반복등록 옵션은 의미 없으니 초기화
      if (source != IncomeSource.salary) _isRecurring = false;
    });
  }

  int get _amount => int.tryParse(_amountController.text.replaceAll(',', '')) ?? 0;

  Future<void> _save() async {
    if (_amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('실수령액을 입력해주세요')),
      );
      return;
    }

    // TODO: userId는 실제 로그인 유저 uid로 교체 (FirebaseAuth.instance.currentUser?.uid)
    const userId = 'TODO_USER_ID';

    final income = IncomeModel(
      incomeId: '',
      userId: userId,
      amount: _amount,
      incomeSource: _selectedSource,
      date: _selectedDate,
      memo: _memoController.text.isEmpty ? null : _memoController.text,
    );

    await _incomeService.addIncome(income);

    // TODO: _isRecurring이 true면 여기서 RecurringIncomeTemplate도 생성/갱신해야 함
    // (예: IncomeService().createOrUpdateRecurringTemplate(...))

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('수입 입력'),
        centerTitle: true,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('출처', style: TextStyle(fontSize: 13, color: Colors.grey)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: IncomeSource.values.map((source) {
                final selected = _selectedSource == source;
                return ChoiceChip(
                  label: Text(source.label),
                  selected: selected,
                  onSelected: (_) => _selectSource(source),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            _buildFormRow(
              label: '일시',
              child: InkWell(
                onTap: _pickDate,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.calendar_today, size: 16),
                    const SizedBox(width: 4),
                    Text(_formatDate(_selectedDate)),
                  ],
                ),
              ),
            ),
            _buildFormRow(
              label: '실수령액',
              child: SizedBox(
                width: 140,
                child: TextField(
                  controller: _amountController,
                  textAlign: TextAlign.right,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    suffixText: '원',
                    isDense: true,
                  ),
                ),
              ),
            ),

            // 프리랜서 소득일 때만 세전 추정액 안내 (저장하지 않는 참고용 계산값)
            if (_selectedSource == IncomeSource.freelanceIncome && _amount > 0)
              Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 8),
                child: Text(
                  '세전 약 ${(_amount / 0.967).round()}원 (추정 · 3.3% 원천징수 기준)',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),

            _buildFormRow(
              label: '메모',
              child: SizedBox(
                width: 160,
                child: TextField(
                  controller: _memoController,
                  textAlign: TextAlign.right,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText: '선택 사항',
                    isDense: true,
                  ),
                ),
              ),
            ),

            // 월급일 때만 반복등록 옵션 노출
            if (_selectedSource == IncomeSource.salary) ...[
              const Divider(height: 32),
              _buildFormRow(
                label: '매달 자동 등록',
                child: Switch(
                  value: _isRecurring,
                  onChanged: (v) => setState(() => _isRecurring = v),
                ),
              ),
              if (_isRecurring)
                _buildFormRow(
                  label: '매달 며칠',
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline, size: 20),
                        onPressed: _payDay > 1
                            ? () => setState(() => _payDay--)
                            : null,
                      ),
                      Text('$_payDay일'),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline, size: 20),
                        onPressed: _payDay < 28
                            ? () => setState(() => _payDay++)
                            : null,
                      ),
                    ],
                  ),
                ),
            ],

            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _save,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                child: const Text('저장', style: TextStyle(color: Colors.white, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormRow({required String label, required Widget child}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [Text(label), child],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final today = DateTime.now();
    if (date.year == today.year && date.month == today.month && date.day == today.day) {
      return '오늘';
    }
    return '${date.month}/${date.day}';
  }
}