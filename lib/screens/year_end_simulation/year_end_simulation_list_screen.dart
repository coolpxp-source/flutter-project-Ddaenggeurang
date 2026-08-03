import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../utils/app_colors.dart';
import '../../utils/formatters.dart';
import '../../utils/year_end_tax_calculator.dart';
import '../../models/year_end_simulation_model.dart';
import '../../services/year_end_simulation_service.dart';
import '../../widgets/common/ddaeng_modal.dart';

class YearEndSimulationListScreen extends StatelessWidget {
  const YearEndSimulationListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    final service = YearEndSimulationService();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.ink,
        elevation: 0,
        title: const Text('연말정산 기록',
            style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.ink)),
        centerTitle: true,
      ),
      body: userId == null
          ? const Center(child: Text('로그인이 필요해요', style: TextStyle(color: AppColors.inkSub)))
          : StreamBuilder<List<YearEndSimulationModel>>(
        stream: service.getSimulations(userId: userId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppColors.expense));
          }
          final sims = snapshot.data ?? [];
          if (sims.isEmpty) {
            return const Center(
              child: Text('저장된 시뮬레이션이 없어요', style: TextStyle(color: AppColors.inkSub)),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: sims.length,
            itemBuilder: (context, index) => _SimulationCard(
              sim: sims[index],
              userId: userId,
            ),
          );
        },
      ),
    );
  }
}

class _SimulationCard extends StatefulWidget {
  final YearEndSimulationModel sim;
  final String userId;
  const _SimulationCard({required this.sim, required this.userId});

  @override
  State<_SimulationCard> createState() => _SimulationCardState();
}

class _SimulationCardState extends State<_SimulationCard> {
  bool _isExpanded = false;
  final _service = YearEndSimulationService();

  Future<void> _confirmDelete() async {
    final confirmed = await DdaengModal.confirm(
      context,
      title: '기록 삭제',
      message: '이 시뮬레이션 기록을 삭제할까요?',
      type: ModalType.danger,
      confirmText: '삭제',
    );

    if (confirmed) {
      await _service.deleteSimulation(userId: widget.userId, simId: widget.sim.simId);
      if (mounted) {
        await DdaengModal.alert(
          context,
          title: '삭제 완료',
          message: '기록을 삭제했어요.',
          type: ModalType.success,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final credit = (widget.sim.deductions['creditCardUsage'] as num?)?.toInt() ?? 0;
    final debit = (widget.sim.deductions['debitCardUsage'] as num?)?.toInt() ?? 0;
    final income = widget.sim.income;

    final result = YearEndTaxCalculator.calculate(
      salary: income,
      credit: credit,
      debit: debit,
    );

    return GestureDetector(
        onLongPress: _confirmDelete, // ← 카드 전체로 이동
        child: Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: AppColors.cardShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (widget.sim.createdAt != null)
                    Text(
                      '${widget.sim.createdAt!.year}.${widget.sim.createdAt!.month}.${widget.sim.createdAt!.day}',
                      style: const TextStyle(fontSize: 12, color: AppColors.inkSub),
                    ),
                  GestureDetector(
                    onTap: () => setState(() => _isExpanded = !_isExpanded), // ← onLongPress 제거
                    child: AnimatedRotation(
                      turns: _isExpanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeInOut,
                      child: const Icon(Icons.keyboard_arrow_down, color: AppColors.inkSub),
                    ),
                  ),
                ],
              ),
          const SizedBox(height: 8),
          Text('총급여 ${CurrencyFormatter.format(income)}원',
              style: const TextStyle(fontSize: 13, color: AppColors.ink)),
          const SizedBox(height: 4),
          Text('신용 ${CurrencyFormatter.format(credit)} · 체크 ${CurrencyFormatter.format(debit)}',
              style: const TextStyle(fontSize: 12, color: AppColors.inkSub)),
          const SizedBox(height: 12),
          const Text('예상 소득공제액', style: TextStyle(fontSize: 12, color: AppColors.inkSub)),
          Text(
            '${CurrencyFormatter.format(widget.sim.estimatedRefund)} 원',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.ink),
          ),

          // ↓ 애니메이션 펼침 영역
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: !_isExpanded
                ? const SizedBox(width: double.infinity)
                : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Divider(color: Color(0xFFEEEEEE), height: 1),
                ),
                const Text('계산 리포트',
                    style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.ink)),
                const SizedBox(height: 10),

                if (!result.isEligible)
                  Text(
                    '💡 카드 사용액 ${CurrencyFormatter.format(result.totalUsage)}원이 총급여 25%인 '
                        '${CurrencyFormatter.format(result.threshold)}원을 넘지 않아 공제 대상이 아니에요.',
                    style: const TextStyle(fontSize: 12, color: AppColors.expense, height: 1.5),
                  )
                else ...[
                  Text(
                    '총급여의 25%인 ${CurrencyFormatter.format(result.threshold)}원을 '
                        '${CurrencyFormatter.format(result.overThreshold)}원만큼 넘겼어요.',
                    style: const TextStyle(fontSize: 12.5, color: AppColors.ink, height: 1.6),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '신용카드 사용분에서 ${CurrencyFormatter.format(result.creditDeduction)}원, '
                        '체크카드 사용분에서 ${CurrencyFormatter.format(result.debitDeduction)}원이 공제됐어요.',
                    style: const TextStyle(fontSize: 12.5, color: AppColors.ink, height: 1.6),
                  ),
                  if (result.isCapped) ...[
                    const SizedBox(height: 4),
                    Text(
                      '⚠️ 총급여 구간별 공제 한도(${CurrencyFormatter.format(result.limit)}원)가 '
                          '적용되어 실제 공제액이 조정됐어요.',
                      style: const TextStyle(fontSize: 11.5, color: AppColors.inkSub, height: 1.5),
                    ),
                  ],
                  const SizedBox(height: 10),
                  _ReportRow(label: '공제 문턱 (총급여 25%)', value: '${CurrencyFormatter.format(result.threshold)}원'),
                  _ReportRow(label: '총 카드 사용액', value: '${CurrencyFormatter.format(result.totalUsage)}원'),
                  _ReportRow(
                    label: '공제 대상 금액 (초과분)',
                    value: '${CurrencyFormatter.format(result.overThreshold)}원',
                    isHighlight: true,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
     ),
    );
  }
}

class _ReportRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isHighlight;

  const _ReportRow({
    required this.label,
    required this.value,
    this.isHighlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: AppColors.inkSub)),
          Text(value, style: TextStyle(
            fontSize: 12,
            fontWeight: isHighlight ? FontWeight.bold : FontWeight.normal,
            color: isHighlight ? AppColors.income : AppColors.ink,
          )),
        ],
      ),
    );
  }
}