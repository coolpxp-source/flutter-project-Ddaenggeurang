import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/year_end_simulation_model.dart';
import '../../services/year_end_simulation_service.dart';
import '../../utils/formatters.dart';
import '../../utils/year_end_tax_calculator.dart';
import '../../widgets/common/ddaeng_modal.dart';

const Color _mainColor = Color(0xFF1FA97D);
const Color _mainSoftColor = Color(0xFFE3F6EE);

class YearEndSimulationListScreen extends StatelessWidget {
  const YearEndSimulationListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    final service = YearEndSimulationService();

    return Scaffold(
      backgroundColor: const Color(0xFFF8F7FA),
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        backgroundColor: const Color(0xFFF8F7FA),
        surfaceTintColor: Colors.transparent,
        foregroundColor: const Color(0xFF222222),
        title: const Text('연말정산 기록', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
      ),
      body: userId == null
          ? const Center(child: Text('로그인이 필요해요', style: TextStyle(color: Color(0xFF999999))))
          : StreamBuilder<List<YearEndSimulationModel>>(
        stream: service.getSimulations(userId: userId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: _mainColor));
          }
          final sims = snapshot.data ?? [];
          final latest = sims.isEmpty ? null : sims.first;

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            children: [
              _SummaryCard(latest: latest, count: sims.length),
              const SizedBox(height: 14),
              _SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('저장된 기록',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF222222))),
                    if (sims.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 30),
                        child: Center(
                          child: Column(
                            children: [
                              Container(
                                width: 64,
                                height: 64,
                                decoration: const BoxDecoration(color: _mainSoftColor, shape: BoxShape.circle),
                                child: const Icon(Icons.receipt_long_rounded, size: 30, color: _mainColor),
                              ),
                              const SizedBox(height: 12),
                              const Text('저장된 시뮬레이션이 없어요',
                                  style: TextStyle(color: Color(0xFF555555), fontSize: 13)),
                            ],
                          ),
                        ),
                      )
                    else ...[
                      ...sims.map(
                            (sim) => Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: _SimulationCard(sim: sim, userId: userId),
                        ),
                      ),
                      const _LongPressHint(),
                    ],
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final YearEndSimulationModel? latest;
  final int count;
  const _SummaryCard({required this.latest, required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1FA97D), Color(0xFF5FCBA4)],
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('가장 최근 예상 공제액',
              style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text(
            latest == null ? '기록 없음' : '${CurrencyFormatter.format(latest!.estimatedRefund)}원',
            style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _SummaryItem(
                label: '총급여',
                value: latest == null ? '-' : '${CurrencyFormatter.format(latest!.income)}원',
              ),
              const SizedBox(width: 8),
              _SummaryItem(label: '저장된 기록', value: '$count건'),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final String label;
  final String value;
  const _SummaryItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.18), borderRadius: BorderRadius.circular(14)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10)),
            const SizedBox(height: 4),
            Text(value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }
}

class _LongPressHint extends StatelessWidget {
  const _LongPressHint();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(color: _mainSoftColor, borderRadius: BorderRadius.circular(10)),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, size: 14, color: _mainColor),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              '기록을 꾹 눌러서 삭제할 수 있어요',
              style: TextStyle(fontSize: 11, color: Colors.grey[600], fontWeight: FontWeight.w600),
            ),
          ),
        ],
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
    if (!confirmed) return;

    try {
      await _service.deleteSimulation(userId: widget.userId, simId: widget.sim.simId);
      if (mounted) {
        await DdaengModal.alert(
          context,
          title: '삭제 완료',
          message: '기록을 삭제했어요.',
          type: ModalType.success,
        );
      }
    } catch (e) {
      if (mounted) {
        await DdaengModal.alert(
          context,
          title: '삭제할 수 없어요',
          message: e.toString().replaceFirst('Exception: ', ''),
          type: ModalType.danger,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final credit = (widget.sim.deductions['creditCardUsage'] as num?)?.toInt() ?? 0;
    final debit = (widget.sim.deductions['debitCardUsage'] as num?)?.toInt() ?? 0;
    final income = widget.sim.income;

    final result = YearEndTaxCalculator.calculate(salary: income, credit: credit, debit: debit);

    return GestureDetector(
      onLongPress: _confirmDelete,
      child: Material(
        color: const Color(0xFFF7F8FB),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (widget.sim.createdAt != null)
                    Text(
                      '${widget.sim.createdAt!.year}.${widget.sim.createdAt!.month}.${widget.sim.createdAt!.day}',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF9A9DA5)),
                    ),
                  GestureDetector(
                    onTap: () => setState(() => _isExpanded = !_isExpanded),
                    child: AnimatedRotation(
                      turns: _isExpanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeInOut,
                      child: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF9A9DA5)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text('총급여 ${CurrencyFormatter.format(income)}원',
                  style: const TextStyle(fontSize: 13, color: Color(0xFF25272C), fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text('신용 ${CurrencyFormatter.format(credit)} · 체크 ${CurrencyFormatter.format(debit)}',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF9A9DA5))),
              const SizedBox(height: 12),
              const Text('예상 소득공제액', style: TextStyle(fontSize: 12, color: Color(0xFF9A9DA5))),
              Text(
                '${CurrencyFormatter.format(widget.sim.estimatedRefund)}원',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: _mainColor),
              ),
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
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF25272C))),
                    const SizedBox(height: 10),
                    if (!result.isEligible)
                      Text(
                        '💡 카드 사용액 ${CurrencyFormatter.format(result.totalUsage)}원이 총급여 25%인 '
                            '${CurrencyFormatter.format(result.threshold)}원을 넘지 않아 공제 대상이 아니에요.',
                        style: const TextStyle(fontSize: 12, color: Colors.redAccent, height: 1.5),
                      )
                    else ...[
                      Text(
                        '총급여의 25%인 ${CurrencyFormatter.format(result.threshold)}원을 '
                            '${CurrencyFormatter.format(result.overThreshold)}원만큼 넘겼어요.',
                        style: const TextStyle(fontSize: 12.5, color: Color(0xFF444444), height: 1.6),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '신용카드 사용분에서 ${CurrencyFormatter.format(result.creditDeduction)}원, '
                            '체크카드 사용분에서 ${CurrencyFormatter.format(result.debitDeduction)}원이 공제됐어요.',
                        style: const TextStyle(fontSize: 12.5, color: Color(0xFF444444), height: 1.6),
                      ),
                      if (result.isCapped) ...[
                        const SizedBox(height: 4),
                        Text(
                          '⚠️ 총급여 구간별 공제 한도(${CurrencyFormatter.format(result.limit)}원)가 '
                              '적용되어 실제 공제액이 조정됐어요.',
                          style: const TextStyle(fontSize: 11.5, color: Color(0xFF9A9DA5), height: 1.5),
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
      ),
    );
  }
}

class _ReportRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isHighlight;

  const _ReportRow({required this.label, required this.value, this.isHighlight = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF9A9DA5))),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isHighlight ? FontWeight.bold : FontWeight.normal,
              color: isHighlight ? _mainColor : const Color(0xFF25272C),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final Widget child;
  const _SectionCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF0EDF0)),
        boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 14, offset: Offset(0, 5))],
      ),
      child: child,
    );
  }
}