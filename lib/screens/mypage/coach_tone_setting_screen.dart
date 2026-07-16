import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/coach_tone.dart';
import '../../models/user_model.dart';
import '../../services/user_service.dart';
import '../../widgets/common/coach_avatar.dart';

const _accent = Color(0xFFF5A623);
const _accentSoft = Color(0xFFFFF0A6);
const _ink = Color(0xFF221A16);
const _inkSub = Color(0xFF8A7E77);
const _bg = Color(0xFFFAF8F6);

class CoachToneSettingScreen extends StatefulWidget {
  const CoachToneSettingScreen({super.key});

  @override
  State<CoachToneSettingScreen> createState() => _CoachToneSettingScreenState();
}

class _CoachToneSettingScreenState extends State<CoachToneSettingScreen> {
  final _userService = UserService();
  String get _uid => FirebaseAuth.instance.currentUser!.uid;
  bool _saving = false;

  Future<void> _select(CoachTone tone) async {
    setState(() => _saving = true);
    await _userService.updateCoachTone(_uid, tone);
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${tone.emoji} ${tone.label} 코치로 바뀌었어요'),
        backgroundColor: _accent,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: _ink,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text('잔소리 캐릭터 설정', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: StreamBuilder<UserModel?>(
        stream: _userService.watchUser(_uid),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator(color: _accent));
          }
          final selected = snapshot.data!.coachTone;

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Text('코치의 성향에 따라 잔소리 수위가 달라져요',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: _inkSub)),
              const SizedBox(height: 16),
              ...CoachTone.values.map((tone) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _CoachCard(
                  tone: tone,
                  selected: tone == selected,
                  disabled: _saving,
                  onTap: () => _select(tone),
                ),
              )),
            ]
                .animate(interval: 70.ms)
                .fadeIn(duration: 360.ms, curve: Curves.easeOut)
                .slideY(begin: 0.06, end: 0, curve: Curves.easeOutCubic),
          );
        },
      ),
    );
  }
}

/// 코치 톤별 예시 잔소리 — 직접 골라보기 전에 말투를 미리 들어볼 수 있게.
String _exampleLine(CoachTone tone) {
  switch (tone.name) {
    case 'ddaenggu':
      return '오늘도 커피 한 잔 하셨네요! 내일은 텀블러 어때요? 😊';
    case 'ddaengjwi':
      return '이번 달 카페 지출이 예산의 42%예요. 데이터가 말해주네요.';
    case 'ddaengnyang':
      return '또 배달이야? 냉장고 파먹기 챌린지나 한 번 해보시죠?';
    default:
      return '';
  }
}

class _CoachCard extends StatelessWidget {
  final CoachTone tone;
  final bool selected;
  final bool disabled;
  final VoidCallback onTap;

  const _CoachCard({
    required this.tone,
    required this.selected,
    required this.disabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: disabled ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: selected
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [_accentSoft, Colors.white],
                )
              : null,
          color: selected ? null : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: selected ? Border.all(color: _accent, width: 1.6) : null,
          boxShadow: [
            BoxShadow(
              color: selected
                  ? _accent.withValues(alpha: 0.18)
                  : _ink.withValues(alpha: 0.045),
              blurRadius: selected ? 18 : 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: selected
                          ? [Colors.white, const Color(0xFFFFF4D6)]
                          : [const Color(0xFFFFF8E5), const Color(0xFFFFEFC7)],
                    ),
                    boxShadow: selected
                        ? [
                            BoxShadow(
                                color: _accent.withValues(alpha: 0.2),
                                blurRadius: 8,
                                offset: const Offset(0, 3)),
                          ]
                        : null,
                  ),
                  alignment: Alignment.center,
                  child: CoachAvatar(imagePath: tone.imagePath, size: 40),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(tone.label,
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w800, color: _ink)),
                          const SizedBox(width: 6),
                          Text(tone.title,
                              style: const TextStyle(
                                  fontSize: 11.5, fontWeight: FontWeight.w700, color: _inkSub)),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(tone.desc,
                          style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF4E5968))),
                    ],
                  ),
                ),
                Icon(
                  selected ? Icons.check_circle_rounded : Icons.circle_outlined,
                  color: selected ? _accent : const Color(0xFFD1D6DB),
                  size: 24,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: selected ? Colors.white.withValues(alpha: 0.6) : _bg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('💬 ', style: TextStyle(fontSize: 12)),
                  Expanded(
                    child: Text(_exampleLine(tone),
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            fontStyle: FontStyle.italic,
                            color: Color(0xFF4E5968),
                            height: 1.4)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
