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

  static const _pink = Color(0xFFEE5586);

  late final Future<_PeerCompareData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_PeerCompareData> _load() async {
    final String uid = FirebaseAuth.instance.currentUser!.uid;

    // 본인 통계와 또래 평균을 동시에 조회
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
      appBar: AppBar(title: const Text('또래 비교')),
      body: FutureBuilder<_PeerCompareData>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data!;

          // 아직 저축비율을 공유하지 않은 유저 — 비교할 내 데이터가 없음
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
            Icon(Icons.bar_chart_rounded, size: 48, color: Colors.grey[350]),
            const SizedBox(height: 16),
            const Text(
              '아직 저축비율을 공유하지 않았어요',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
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

    return Padding(
      padding: const EdgeInsets.all(20),
      child: ListView(
        children: [
          Text('${widget.ageGroup} · ${widget.job} 평균과 비교',
              style: const TextStyle(fontSize: 14, color: Colors.grey)),
          const SizedBox(height: 6),
          if (peer.matchLevel != 'exact') _buildMatchLevelNotice(peer),
          const SizedBox(height: 20),

          _buildCompareCard(
            title: '저축률',
            myValue: mine.savingRate.toDouble(),
            peerValue: peer.savingRate,
            unit: '%',
            higherIsBetter: true,
          ),
          const SizedBox(height: 14),
          _buildCompareCard(
            title: '지출',
            myValue: mine.expenseAmount.toDouble(),
            peerValue: peer.expenseAmount,
            unit: '원',
            higherIsBetter: false,
          ),
          const SizedBox(height: 14),
          _buildCompareCard(
            title: '수입',
            myValue: mine.incomeAmount.toDouble(),
            peerValue: peer.incomeAmount,
            unit: '원',
            higherIsBetter: true,
          ),
        ],
      ),
    );
  }

  /// 정확한 또래(연령대+직업 일치) 표본이 부족해서 조건을 완화했을 때 안내
  Widget _buildMatchLevelNotice(PeerAverages peer) {
    final String message = peer.matchLevel == 'ageGroupOnly'
        ? '같은 연령대 전체 평균으로 대신 보여드려요 (표본 ${peer.sampleSize}명)'
        : peer.matchLevel == 'all'
        ? '또래 데이터가 부족해 전체 커뮤니티 평균으로 보여드려요 (표본 ${peer.sampleSize}명)'
        : '아직 비교할 또래 데이터가 없어요';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.amber[50],
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, size: 14, color: Colors.amber[800]),
          const SizedBox(width: 6),
          Expanded(
            child: Text(message, style: TextStyle(fontSize: 11, color: Colors.amber[900])),
          ),
        ],
      ),
    );
  }

  Widget _buildCompareCard({
    required String title,
    required double myValue,
    required double peerValue,
    required String unit,
    required bool higherIsBetter,
  }) {
    final double diff = myValue - peerValue;

    // 저축률/수입은 높을수록, 지출은 낮을수록 긍정적인 방향
    final bool isPositive = higherIsBetter ? diff >= 0 : diff <= 0;

    final String formattedMy = unit == '%' ? myValue.toStringAsFixed(1) : _formatAmount(myValue);
    final String formattedPeer = unit == '%' ? peerValue.toStringAsFixed(1) : _formatAmount(peerValue);
    final String formattedDiff = unit == '%' ? diff.abs().toStringAsFixed(1) : _formatAmount(diff.abs());

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatColumn('내 $title', '$formattedMy$unit', _pink),
              _buildStatColumn('또래 평균', '$formattedPeer$unit', Colors.grey[700]!),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isPositive ? Colors.green[50] : Colors.orange[50],
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              diff == 0
                  ? '또래 평균과 같아요'
                  : isPositive
                  ? '또래보다 $formattedDiff$unit 더 ${_positiveLabel(title)}'
                  : '또래보다 $formattedDiff$unit 더 ${_negativeLabel(title)}',
              style: TextStyle(
                fontSize: 12,
                color: isPositive ? Colors.green[800] : Colors.orange[800],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _positiveLabel(String title) {
    if (title == '지출') return '적게 쓰고 있어요 👍';
    return '$title(이)가 높아요 👍';
  }

  String _negativeLabel(String title) {
    if (title == '지출') return '많이 쓰고 있어요';
    return '$title(이)가 낮아요';
  }

  Widget _buildStatColumn(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
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