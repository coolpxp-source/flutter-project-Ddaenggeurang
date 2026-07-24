import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../services/community_service.dart';
import '../../models/community_stat_model.dart';

class PeerCompareScreen extends StatefulWidget {
  final String ageGroup;
  final String job;

  const PeerCompareScreen({
    super.key,
    required this.ageGroup,
    required this.job,
  });

  @override
  State<PeerCompareScreen> createState() => _PeerCompareScreenState();
}

class _PeerCompareScreenState extends State<PeerCompareScreen> {
  final _service = CommunityService();

  // 커뮤니티 홈과 동일한 오렌지/코랄 톤
  static const _pink = Color(0xFFEE5586);
  static const _green = Color(0xFFFF8A3D);
  static const _greenLight = Color(0xFFFFF0E8);

  late final Future<_PeerCompareData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_PeerCompareData> _load() async {
    final String uid = FirebaseAuth.instance.currentUser!.uid;

    final results = await Future.wait([
      _service.getMyStat(uid),
      _service.getPeerAverages(ageGroup: widget.ageGroup, job: widget.job),
    ]);

    return _PeerCompareData(
      myStat: results[0] as CommunityStat?,
      peerAverages: results[1] as PeerAverages,
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
        title: const Text('또래 비교', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      ),
      body: FutureBuilder<_PeerCompareData>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator(color: _green));
          }

          final data = snapshot.data!;

          if (data.myStat == null) {
            return _buildNoShareYetView();
          }

          return _buildCompareView(data);
        },
      ),
    );
  }

  Widget _buildNoShareYetView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(color: _greenLight, shape: BoxShape.circle),
              child: const Icon(Icons.bar_chart_rounded, size: 32, color: _green),
            ),
            const SizedBox(height: 18),
            const Text('아직 저축비율을 공유하지 않았어요',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              '저축비율을 공유하면 또래와 비교해볼 수 있어요.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompareView(_PeerCompareData data) {
    final CommunityStat mine = data.myStat!;
    final PeerAverages peer = data.peerAverages;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
      children: [
        Text('${widget.ageGroup} · ${widget.job} 평균과 비교',
            style: TextStyle(fontSize: 13, color: Colors.grey[500])),
        if (peer.matchLevel != 'exact') ...[
          const SizedBox(height: 10),
          _buildMatchLevelNotice(peer),
        ],
        const SizedBox(height: 18),
        _buildCompareCard(
          icon: Icons.savings_rounded,
          title: '저축률',
          myValue: mine.savingRate.toDouble(),
          peerValue: peer.savingRate,
          unit: '%',
          higherIsBetter: true,
          barColor: const Color(0xFF4F7DF3),
        ),
        const SizedBox(height: 14),
        _buildCompareCard(
          icon: Icons.shopping_bag_rounded,
          title: '지출',
          myValue: mine.expenseAmount.toDouble(),
          peerValue: peer.expenseAmount,
          unit: '원',
          higherIsBetter: false,
          barColor: _pink,
        ),
        const SizedBox(height: 14),
        _buildCompareCard(
          icon: Icons.account_balance_wallet_rounded,
          title: '수입',
          myValue: mine.incomeAmount.toDouble(),
          peerValue: peer.incomeAmount,
          unit: '원',
          higherIsBetter: true,
          barColor: const Color(0xFF4CAF87),
        ),
      ],
    );
  }

  Widget _buildMatchLevelNotice(PeerAverages peer) {
    final String message = peer.matchLevel == 'ageGroupOnly'
        ? '같은 연령대 전체 평균으로 대신 보여드려요 (표본 ${peer.sampleSize}명)'
        : peer.matchLevel == 'all'
        ? '또래 데이터가 부족해 전체 커뮤니티 평균으로 보여드려요 (표본 ${peer.sampleSize}명)'
        : '아직 비교할 또래 데이터가 없어요';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(color: _greenLight, borderRadius: BorderRadius.circular(10)),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, size: 14, color: _green),
          const SizedBox(width: 6),
          Expanded(
            child: Text(message, style: const TextStyle(fontSize: 11, color: Color(0xFFB05A1E))),
          ),
        ],
      ),
    );
  }

  Widget _buildCompareCard({
    required IconData icon,
    required String title,
    required double myValue,
    required double peerValue,
    required String unit,
    required bool higherIsBetter,
    required Color barColor,
  }) {
    final double diff = myValue - peerValue;
    final bool isPositive = higherIsBetter ? diff >= 0 : diff <= 0;

    final String formattedMy = unit == '%' ? myValue.toStringAsFixed(1) : _formatAmount(myValue);
    final String formattedPeer = unit == '%' ? peerValue.toStringAsFixed(1) : _formatAmount(peerValue);
    final String formattedDiff = unit == '%' ? diff.abs().toStringAsFixed(1) : _formatAmount(diff.abs());

    const Color positiveBg = Color(0xFFE9F9F1);
    const Color positiveText = Color(0xFF1B8F5A);
    const Color negativeBg = Color(0xFFFFF1E5);
    const Color negativeText = Color(0xFFC2610C);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(color: _greenLight, shape: BoxShape.circle),
                child: Icon(icon, size: 16, color: _green),
              ),
              const SizedBox(width: 10),
              Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 16),
          _buildBarComparison(
            myValue: myValue,
            peerValue: peerValue,
            formattedMy: formattedMy,
            formattedPeer: formattedPeer,
            unit: unit,
            barColor: barColor,
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: isPositive ? positiveBg : negativeBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  isPositive ? Icons.thumb_up_rounded : Icons.info_rounded,
                  size: 14,
                  color: isPositive ? positiveText : negativeText,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    diff == 0
                        ? '또래 평균과 같아요'
                        : isPositive
                        ? '또래보다 $formattedDiff$unit 더 ${_positiveLabel(title)}'
                        : '또래보다 $formattedDiff$unit 더 ${_negativeLabel(title)}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isPositive ? positiveText : negativeText,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _positiveLabel(String title) {
    if (title == '지출') return '적게 쓰고 있어요';
    return '$title(이)가 높아요';
  }

  String _negativeLabel(String title) {
    if (title == '지출') return '많이 쓰고 있어요';
    return '$title(이)가 낮아요';
  }

  /// 내 값 / 또래 평균을 가로 막대로 비교 (별도 차트 라이브러리 없이 Container 너비 비율로 구현)
  Widget _buildBarComparison({
    required double myValue,
    required double peerValue,
    required String formattedMy,
    required String formattedPeer,
    required String unit,
    required Color barColor,
  }) {
    final double maxValue = [myValue, peerValue, 1].reduce((a, b) => a > b ? a : b).toDouble();

    Widget bar({
      required String label,
      required double value,
      required String formattedValue,
      required Color color,
      required Color trackColor,
    }) {
      final double ratio = (value / maxValue).clamp(0.0, 1.0);

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
              const Spacer(),
              Text('$formattedValue$unit',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
            ],
          ),
          const SizedBox(height: 5),
          LayoutBuilder(
            builder: (context, constraints) {
              return Stack(
                children: [
                  Container(
                    width: double.infinity,
                    height: 10,
                    decoration: BoxDecoration(color: trackColor, borderRadius: BorderRadius.circular(6)),
                  ),
                  Container(
                    width: constraints.maxWidth * (ratio == 0 ? 0.02 : ratio),
                    height: 10,
                    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(6)),
                  ),
                ],
              );
            },
          ),
        ],
      );
    }

    return Column(
      children: [
        bar(
          label: '내 값',
          value: myValue,
          formattedValue: formattedMy,
          color: barColor,
          trackColor: barColor.withOpacity(0.12),
        ),
        const SizedBox(height: 12),
        bar(
          label: '또래 평균',
          value: peerValue,
          formattedValue: formattedPeer,
          color: Colors.grey[500]!,
          trackColor: Colors.grey[200]!,
        ),
      ],
    );
  }

  String _formatAmount(num value) {
    return value.round().toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]},',
    );
  }
}

class _PeerCompareData {
  final CommunityStat? myStat;
  final PeerAverages peerAverages;

  _PeerCompareData({required this.myStat, required this.peerAverages});
}