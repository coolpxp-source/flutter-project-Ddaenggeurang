import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/coach_tone.dart';
import '../../models/user_model.dart';
import '../../services/user_service.dart';
import '../../widgets/common/coach_avatar.dart';
import '../../widgets/common/ddaeng_modal.dart';
import 'coach_rps_screen.dart';

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

  Future<void> _editNickname(UserModel user) async {
    final ctrl = TextEditingController(text: user.coachNickname);
    final formKey = GlobalKey<FormState>();

    final result = await DdaengModal.custom<String>(
      context,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${user.coachTone.emoji} 코치 애칭 짓기',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '앞으로 이 이름으로 불러드릴게요',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: _inkSub),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: ctrl,
                autofocus: true,
                maxLength: 8,
                textAlign: TextAlign.center,
                validator: (v) {
                  if (v != null && v.trim().length > 8) return '8자 이내로 입력해주세요';
                  return null;
                },
                decoration: InputDecoration(
                  counterText: '',
                  hintText: user.coachTone.label,
                  filled: true,
                  fillColor: _bg,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, ''),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        foregroundColor: _inkSub,
                        side: const BorderSide(color: Color(0xFFE8ECF3)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('기본 이름으로'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        if (formKey.currentState!.validate()) {
                          Navigator.pop(context, ctrl.text.trim());
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: _accent,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('저장'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (result == null) return;
    await _userService.updateCoachNickname(_uid, result);
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
        title: const Text(
          '잔소리 캐릭터 설정',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: StreamBuilder<UserModel?>(
        stream: _userService.watchUser(_uid),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: _accent),
            );
          }
          final user = snapshot.data!;
          final selected = user.coachTone;

          return ListView(
            padding: const EdgeInsets.all(20),
            children:
                [
                      _AffectionCard(user: user),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _CoachActionButton(
                              icon: Icons.edit_outlined,
                              label: '${user.coachDisplayName} 애칭 짓기',
                              onTap: () => _editNickname(user),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _CoachActionButton(
                              icon: Icons.back_hand_outlined,
                              label: '오늘의 가위바위보',
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const CoachRpsScreen(),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        '코치의 성향에 따라 잔소리 수위가 달라져요',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          color: _inkSub,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ...CoachTone.values.map(
                        (tone) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _CoachCard(
                            tone: tone,
                            selected: tone == selected,
                            disabled: _saving,
                            onTap: () => _select(tone),
                          ),
                        ),
                      ),
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

/// 친밀도 게이지 카드 — AI상담을 쌓을수록 지금 고른 코치와 얼마나 가까워졌는지 보여준다.
/// 레벨/단계 계산은 마이페이지 홈에서도 똑같이 노출하므로 UserModel에 공유돼 있다.
class _AffectionCard extends StatelessWidget {
  final UserModel user;
  const _AffectionCard({required this.user});

  @override
  Widget build(BuildContext context) {
    final tone = user.coachTone;
    final affection = user.coachAffection;
    final level = user.coachAffectionLevel;
    final isMax = level >= UserModel.coachAffectionMaxLevel;
    final intoLevel =
        affection - (level - 1) * UserModel.coachAffectionPerLevel;
    final progress = isMax
        ? 1.0
        : (intoLevel / UserModel.coachAffectionPerLevel).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _ink.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CoachAvatar(imagePath: tone.imagePath, size: 48),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '친밀도 Lv.$level',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: _ink,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      user.coachAffectionTitle,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: _inkSub,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 7,
                    backgroundColor: _bg,
                    valueColor: const AlwaysStoppedAnimation(_accent),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  isMax
                      ? '최고 단계에 도달했어요!'
                      : '다음 단계까지 ${UserModel.coachAffectionPerLevel - intoLevel}점',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: _inkSub,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 애칭 짓기 / 가위바위보 진입용 작은 액션 버튼 — 나란히 2개 배치.
class _CoachActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _CoachActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: _ink.withValues(alpha: 0.045),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, size: 18, color: _accent),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: _ink,
              ),
            ),
          ],
        ),
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

/// 캐릭터 이미지를 길게 누르면 나오는 숨겨진 대사 — 이스터에그.
String _hiddenLine(CoachTone tone) {
  switch (tone.name) {
    case 'ddaenggu':
      return '사실 저도 몰래 배달 시켜먹어요... 이건 비밀이에요 🤫';
    case 'ddaengjwi':
      return '데이터는 거짓말 안 해요. 근데 저도 가끔 홧김에 지릅니다.';
    case 'ddaengnyang':
      return '냉장고 파먹기? 그거 제가 만든 말인데 저도 안 지켜요 ㅋㅋ';
    default:
      return '비밀이에요 🤐';
  }
}

void _showEasterEgg(BuildContext context, CoachTone tone) {
  HapticFeedback.mediumImpact();
  showDialog(
    context: context,
    barrierDismissible: true,
    builder: (context) => Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 22, 24, 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '🎉 히든 대사 발견!',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: _accent,
              ),
            ),
            const SizedBox(height: 14),
            CoachAvatar(imagePath: tone.imagePath, size: 72),
            const SizedBox(height: 14),
            Text(
              _hiddenLine(tone),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: _ink,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    ),
  );
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
                GestureDetector(
                  onLongPress: () => _showEasterEgg(context, tone),
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: selected
                            ? [Colors.white, const Color(0xFFFFF4D6)]
                            : [
                                const Color(0xFFFFF8E5),
                                const Color(0xFFFFEFC7),
                              ],
                      ),
                      boxShadow: selected
                          ? [
                              BoxShadow(
                                color: _accent.withValues(alpha: 0.2),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ]
                          : null,
                    ),
                    alignment: Alignment.center,
                    child: CoachAvatar(imagePath: tone.imagePath, size: 40),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            tone.label,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: _ink,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            tone.title,
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: _inkSub,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        tone.desc,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF4E5968),
                        ),
                      ),
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
                    child: Text(
                      _exampleLine(tone),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        fontStyle: FontStyle.italic,
                        color: Color(0xFF4E5968),
                        height: 1.4,
                      ),
                    ),
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
