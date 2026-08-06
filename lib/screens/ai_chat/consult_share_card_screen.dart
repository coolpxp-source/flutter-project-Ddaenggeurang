import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/consultation_model.dart';
import '../../models/user_model.dart';
import '../../services/ai_service.dart' as ai;
import '../../services/user_service.dart';
import '../../widgets/common/coach_avatar.dart';

const _ink = Color(0xFF221A16);
const _bg = Color(0xFFFAF8F6);

/// 상담 이력을 "이번 해 나의 소비습관" 느낌의 카드 이미지로 만들어 공유한다.
/// 계산은 전부 코드로 하고(LLM 미사용), 화면을 RepaintBoundary로 캡처해서
/// 이미지 파일로 저장한 뒤 공유 시트를 띄운다.
class ConsultShareCardScreen extends StatefulWidget {
  final List<ConsultationEntry> items;
  const ConsultShareCardScreen({super.key, required this.items});

  @override
  State<ConsultShareCardScreen> createState() => _ConsultShareCardScreenState();
}

class _ConsultShareCardScreenState extends State<ConsultShareCardScreen> {
  final _cardKey = GlobalKey();
  UserModel? _user;
  bool _sharing = false;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final u = await UserService().getUser(uid);
    if (mounted) setState(() => _user = u);
  }

  Future<void> _share() async {
    if (_sharing) return;
    setState(() => _sharing = true);
    try {
      final boundary =
          _cardKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData!.buffer.asUint8List();
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/ddaeng_consult_summary.png');
      await file.writeAsBytes(bytes);
      if (!mounted) return;
      await SharePlus.instance.share(ShareParams(
        files: [XFile(file.path)],
        text: '땡그랑과 함께한 나의 소비 상담 리포트 📊',
      ));
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    var buy = 0, hold = 0, conditional = 0;
    for (final e in widget.items) {
      switch (e.verdictCode) {
        case 'buy':
          buy++;
        case 'hold':
          hold++;
        case 'conditional':
          conditional++;
      }
    }
    final total = widget.items.length;
    final holdPercent = total == 0 ? 0 : (hold / total * 100).round();

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: _ink,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text('카드로 공유하기', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              RepaintBoundary(
                key: _cardKey,
                child: _SummaryCard(
                  nickname: _user?.nickname ?? '나',
                  imagePath:
                      (_user?.coachTone ?? ai.CoachTone.ddaengjwi).imagePath,
                  total: total,
                  buy: buy,
                  hold: hold,
                  conditional: conditional,
                  holdPercent: holdPercent,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _sharing ? null : _share,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF7A45),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: _sharing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white))
                      : const Icon(Icons.ios_share_rounded, size: 18),
                  label: Text(_sharing ? '이미지 만드는 중...' : '이미지로 저장 · 공유하기',
                      style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String nickname;
  final String imagePath;
  final int total;
  final int buy;
  final int hold;
  final int conditional;
  final int holdPercent;

  const _SummaryCard({
    required this.nickname,
    required this.imagePath,
    required this.total,
    required this.buy,
    required this.hold,
    required this.conditional,
    required this.holdPercent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 320,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFB648), Color(0xFFFF7A45)],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
              color: const Color(0xFFFF8A45).withValues(alpha: 0.35),
              blurRadius: 24,
              offset: const Offset(0, 14)),
        ],
      ),
      // 텍스트 위젯을 ClipRRect로 감싸면 첫 글자가 깨지는 렌더링 버그가 있어
      // (home_screen.dart에서 확인됨) 바깥 Container의 둥근 모서리만으로 처리한다.
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CoachAvatar(imagePath: imagePath, size: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$nickname님의',
                        style: const TextStyle(
                            fontSize: 12.5, fontWeight: FontWeight.w600, color: Colors.white70)),
                    const Text('소비 상담 리포트',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Container(height: 1, color: Colors.white.withValues(alpha: 0.35)),
          const SizedBox(height: 20),
          Text('총 $total번 상담했어요',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _stat('사도 됨', buy)),
              Expanded(child: _stat('보류', hold)),
              Expanded(child: _stat('조건부', conditional)),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              total == 0
                  ? '아직 상담 기록이 없어요'
                  : holdPercent >= 50
                      ? '충동구매를 $holdPercent%나 참아냈어요 💪'
                      : '필요한 소비를 확실하게 판단하고 있어요 ✨',
              style: const TextStyle(
                  fontSize: 12.5, fontWeight: FontWeight.w700, color: Colors.white, height: 1.4),
            ),
          ),
          const SizedBox(height: 18),
          const Align(
            alignment: Alignment.centerRight,
            child: Text('땡그랑 🪙',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white70)),
          ),
        ],
      ),
    );
  }

  Widget _stat(String label, int count) => Column(
        children: [
          Text('$count',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white)),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Colors.white70)),
        ],
      );
}
