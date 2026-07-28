import 'package:cloud_firestore/cloud_firestore.dart';
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
  static const _greenLight = Color(0xFFFFF0E8);
  static const _gradientStart = Color(0xFFFFA351);
  static const _gradientEnd = Color(0xFFFF6B1A);

  static const _ageGroups = [
    '10대', '20대 초반', '20대 후반', '30대 초반', '30대 후반', '40대', '50대', '60대 이상',
  ];

  static const _jobs = [
    '경영·관리·인사',
    '기획·전략·마케팅',
    '개발·데이터 엔지니어',
    '디자인·UI·UX',
    '영업·고객상담',
    '금융·재무·회계',
    '연구개발·바이오',
    '미디어·엔터·문화',
    '의료·보건·복지',
    '교육·학원·학술',
    '서비스·식음료·유통',
    '제조·생산·품질',
  ];

  final _communityService = CommunityService();
  final _expenseService = ExpenseService();
  final _incomeService = IncomeService();
  final _savingService = SavingService();

  final _nicknameController = TextEditingController();

  String _ageGroup = _ageGroups[1];
  String _job = _jobs[2];

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
    _loadProfileDefaults();
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

  /// users/{uid} 문서에서 닉네임/연령대/직군을 미리 채워온다.
  /// 필드가 없거나 값이 목록에 없으면 기존 기본값을 그대로 둔다.
  Future<void> _loadProfileDefaults() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(_myId).get();
      final data = doc.data();
      if (data == null || !mounted) return;

      final nickname = data['nickname'] as String?;
      final ageGroup = data['ageGroup'] as String?;
      final job = data['job'] as String?;

      setState(() {
        if (nickname != null && nickname.trim().isNotEmpty) {
          _nicknameController.text = nickname.trim();
        }
        if (ageGroup != null && _ageGroups.contains(ageGroup)) {
          _ageGroup = ageGroup;
        }
        if (job != null && _jobs.contains(job)) {
          _job = job;
        }
      });
    } catch (_) {
      // 프로필 자동완성 실패해도 화면은 그대로 수동 입력으로 진행 가능
    }
  }

  Future<void> _loadMonthlyTotals() async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1);
    final end = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

    final results = await Future.wait([
      _expenseService.getExpensesByDateRangeOnce(userId: _myId, start: start, end: end),
      _incomeService.getIncomesByDateRangeOnce(userId: _myId, start: start, end: end),
      _savingService.getTotalSavingAmount(userId: _myId, start: start, end: end),
      _incomeService.getRecurringTemplates(_myId).first,
    ]);

    final expenses = results[0] as List;
    final incomes = results[1] as List;
    final totalSaving = results[2] as double;
    final recurringTemplates = results[3] as List;

    final totalExpense = expenses.fold<num>(0, (sum, e) => sum + e.amount);

    final manualIncomeTotal = incomes.fold<num>(0, (sum, i) => sum + i.amount);

    final activeTemplates = recurringTemplates.where(
          (t) => t.isActive && !t.isDeleted && !t.startDate.isAfter(end),
    );
    final recurringIncomeTotal = activeTemplates.fold<num>(0, (sum, t) => sum + t.amount);

    num totalIncome = manualIncomeTotal + recurringIncomeTotal;

    if (totalIncome == 0) {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(_myId).get();
      totalIncome = (userDoc.data()?['salary'] as num?) ?? 0;
    }

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

  /// 연령대/직군 선택 바텀시트 (화이트 배경, 선택 항목 체크 표시)
  Future<void> _openPicker({
    required String title,
    required List<String> options,
    required String current,
    required ValueChanged<String> onSelected,
  }) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.7,
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                    child: Text(title,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  ),
                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      children: options.map((option) {
                        final isSelected = option == current;
                        return ListTile(
                          onTap: () => Navigator.pop(context, option),
                          title: Text(
                            option,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: isSelected ? _green : const Color(0xFF333333),
                            ),
                          ),
                          trailing: isSelected
                              ? const Icon(Icons.check_rounded, color: _green)
                              : null,
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (selected != null) onSelected(selected);
  }

  Widget _buildPickerField({
    required IconData icon,
    required String value,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: _green),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  value,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF333333)),
                ),
              ),
              const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF999999)),
            ],
          ),
        ),
      ),
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
          _buildPickerField(
            icon: Icons.groups_outlined,
            value: _ageGroup,
            onTap: () => _openPicker(
              title: '연령대 선택',
              options: _ageGroups,
              current: _ageGroup,
              onSelected: (v) => setState(() => _ageGroup = v),
            ),
          ),
          const SizedBox(height: 18),
          _buildSectionLabel('직군', Icons.work_outline_rounded),
          const SizedBox(height: 8),
          _buildPickerField(
            icon: Icons.work_outline_rounded,
            value: _job,
            onTap: () => _openPicker(
              title: '직군 선택',
              options: _jobs,
              current: _job,
              onSelected: (v) => setState(() => _job = v),
            ),
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