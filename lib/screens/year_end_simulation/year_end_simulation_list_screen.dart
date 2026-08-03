import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../utils/app_colors.dart';
import '../../utils/formatters.dart';
import '../../models/year_end_simulation_model.dart';
import '../../services/year_end_simulation_service.dart';

class YearEndSimulationListScreen extends StatelessWidget {
  const YearEndSimulationListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    final service = YearEndSimulationService();

    return Scaffold(
      backgroundColor: AppColors.bg,
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
            itemBuilder: (context, index) => _SimulationCard(sim: sims[index]),
          );
        },
      ),
    );
  }
}

class _SimulationCard extends StatelessWidget {
  final YearEndSimulationModel sim;
  const _SimulationCard({required this.sim});

  @override
  Widget build(BuildContext context) {
    final credit = (sim.deductions['creditCardUsage'] as num?)?.toInt() ?? 0;
    final debit = (sim.deductions['debitCardUsage'] as num?)?.toInt() ?? 0;

    return Container(
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
          if (sim.createdAt != null)
            Text(
              '${sim.createdAt!.year}.${sim.createdAt!.month}.${sim.createdAt!.day}',
              style: const TextStyle(fontSize: 12, color: AppColors.inkSub),
            ),
          const SizedBox(height: 8),
          Text('총급여 ${CurrencyFormatter.format(sim.income)}원',
              style: const TextStyle(fontSize: 13, color: AppColors.ink)),
          const SizedBox(height: 4),
          Text('신용 ${CurrencyFormatter.format(credit)} · 체크 ${CurrencyFormatter.format(debit)}',
              style: const TextStyle(fontSize: 12, color: AppColors.inkSub)),
          const SizedBox(height: 12),
          Text('예상 소득공제액',
              style: const TextStyle(fontSize: 12, color: AppColors.inkSub)),
          Text(
            '${CurrencyFormatter.format(sim.estimatedRefund)} 원',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.ink),
          ),
        ],
      ),
    );
  }
}