import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../models/community_stat_model.dart';
import '../../services/community_service.dart';
import '../../services/expense_service.dart';
import '../../services/income_service.dart';
import '../../services/saving_service.dart';

class SavingShareScreen extends StatefulWidget {
  const SavingShareScreen({super.key});

  @override
  State<SavingShareScreen> createState() => _SavingShareScreenState();
}

class _SavingShareScreenState extends State<SavingShareScreen> {
  static const _green = Color(0xFFFF8A3D);
  static const _gradientStart = Color(0xFFFFA351);
  static const _gradientEnd = Color(0xFFFF6B1A);

  final _communityService = CommunityService();
  final _expenseService = ExpenseService();
  final _incomeService = IncomeService();
  final _savingService = SavingService();

  final _nicknameController = TextEditingController();

  String _ageGroup = '20대';
  String _job = '학생';

  bool _isLoadingMonthly = true;
  bool _isSaving = false;

  num _monthlyExpense = 0;
  num _monthlyIncome = 0;
  num _monthlySaving = 0;

  final String _myId = FirebaseAuth.instance.currentUser!.uid;

  @override
  void initState() {
    super.initState();
    _loadMonthlyTotals();
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    super.dispose();
  }

  double get _savingRate {
    if (_monthlyIncome <= 0) return 0;
    return (_monthlySaving / _monthlyIncome * 100).clamp(0, 100).toDouble();
  }

  Future<void> _loadMonthlyTotals() async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1);
    final end = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

    final results = await Future.wait([
      _expenseService.getExpensesByDateRangeOnce(userId: _myId, start: start, end: end),
      _incomeService.getIncomesByDateRangeOnce(userId: _myId, start: start, end: end),
      _savingService.getTotalSavingAmount(userId: _myId, start: start, end: end),
    ]);

    final expenses = results[0] as List;
    final incomes = results[1] as List;
    final totalSaving = results[2] as double;

    final totalExpense = expenses.fold<num>(0, (sum, e) => sum + e.amount);
    final totalIncome = incomes.fold<num>(0, (sum, i) => sum + i.amount);

    if (!mounted) return;

    setState(() {
      _monthlyExpense = totalExpense;
      _monthlyIncome = totalIncome;
      _monthlySaving = totalSaving;
      _isLoadingMonthly = false;
    });
  }

  Future<void> _submit() async {
    if (_nicknameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('닉네임을 입력해 주세요.')),
      );
      return;
    }

    setState(() => _isSaving = true);

    final stat = CommunityStat(
      userId: _myId,
      nicknameMasked: _nicknameController.text.trim(),
      savingRate: _savingRate,
      savingAmount: _monthlySaving,
      expenseAmount: _monthlyExpense,
      incomeAmount: _monthlyIncome,
      ageGroup: _ageGroup,
      job: _job,
      updatedAt: DateTime.now(),
    );

    await _communityService.updateMyStat(_myId, stat);

    if (!mounted) return;
    setState(() => _isSaving = false);
    Navigator.pop(context);
  }

  String _formatAmount(num value) {
    return value.round().toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]},',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        backgroundColor: const Color(0xFFF8F9FA),
        surfaceTintColor: Colors.transparent,
        foregroundColor: Colors.black87,
        title: const Text('저축 비율 공유', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      ),
      body: _isLoadingMonthly
          ? const Center(child: CircularProgressIndicator(color: _green))
          : ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildRateCard(),
          const SizedBox(height: 14),
          _buildMonthlySummaryCard(),
          const SizedBox(height: 20),
          _buildSectionLabel('닉네임', Icons.badge_outlined),
          const SizedBox(height: 8),
          TextField(
            controller: _nicknameController,
            decoration: _inputDecoration(hintText: '커뮤니티에 마스킹되어 표시돼요'),
          ),
          const SizedBox(height: 18),
          _buildSectionLabel('연령대', Icons.groups_outlined),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _ageGroup,
            decoration: _inputDecoration(hintText: '연령대 선택'),
            items: ['10대', '20대', '30대', '40대', '50대 이상']
                .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                .toList(),
            onChanged: (v) => setState(() => _ageGroup = v!),
          ),
          const SizedBox(height: 18),
          _buildSectionLabel('직군', Icons.work_outline_rounded),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _job,
            decoration: _inputDecoration(hintText: '직군 선택'),
            items: ['학생', '직장인', '자영업', '기타']
                .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                .toList(),
            onChanged: (v) => setState(() => _job = v!),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _submit,
              style: ElevatedButton.styleFrom(
                elevation: 0,
                backgroundColor: _green,
                disabledBackgroundColor: _green.withOpacity(0.4),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: _isSaving
                  ? const SizedBox(
                width: 22, height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
              )
                  : const Text('공유하기', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRateCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [_gradientStart, _gradientEnd], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('이번 달 저축률', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text('${_savingRate.toStringAsFixed(1)}%', style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('내 지출·수입·저축 내역으로 자동 계산돼요', style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildMonthlySummaryCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Row(
        children: [
          Expanded(child: _summaryItem('수입', _monthlyIncome, const Color(0xFF4CAF87))),
          Container(width: 1, height: 34, color: Colors.grey[200]),
          Expanded(child: _summaryItem('지출', _monthlyExpense, const Color(0xFFE5735A))),
          Container(width: 1, height: 34, color: Colors.grey[200]),
          Expanded(child: _summaryItem('저축', _monthlySaving, _green)),
        ],
      ),
    );
  }

  Widget _summaryItem(String label, num amount, Color color) {
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
        const SizedBox(height: 6),
        Text('${_formatAmount(amount)}원', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

  Widget _buildSectionLabel(String label, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 15, color: _green),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
      ],
    );
  }

  InputDecoration _inputDecoration({required String hintText}) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey[200]!)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey[200]!)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _green, width: 1.5)),
    );
  }
}