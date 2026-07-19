import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/user_model.dart';
import '../../services/user_service.dart';
import '../../widgets/common/coach_avatar.dart';

const _accent = Color(0xFFF5A623);
const _accentSoft = Color(0xFFFFF0A6);
const _ink = Color(0xFF221A16);
const _inkSub = Color(0xFF8A7E77);
const _bg = Color(0xFFFAF8F6);
const _ok = Color(0xFF12B76A);
const _errorColor = Color(0xFFF04438);

enum _Hand {
  rock('✊', '바위'),
  scissors('✌️', '가위'),
  paper('✋', '보');

  final String emoji;
  final String label;
  const _Hand(this.emoji, this.label);
}

/// 이긴 쪽 판정. 1이면 a 승, -1이면 b 승, 0이면 비김.
int _judge(_Hand a, _Hand b) {
  if (a == b) return 0;
  final beats = {
    _Hand.rock: _Hand.scissors,
    _Hand.scissors: _Hand.paper,
    _Hand.paper: _Hand.rock,
  };
  return beats[a] == b ? 1 : -1;
}

/// 마이페이지 > 코치 화면에서 진입하는 하루 1회 가위바위보 미니게임.
/// 이기면 포인트, 결과와 무관하게 코치와의 친밀도가 조금 쌓인다.
class CoachRpsScreen extends StatefulWidget {
  const CoachRpsScreen({super.key});

  @override
  State<CoachRpsScreen> createState() => _CoachRpsScreenState();
}

class _CoachRpsScreenState extends State<CoachRpsScreen> {
  final _userService = UserService();
  String get _uid => FirebaseAuth.instance.currentUser!.uid;

  UserModel? _user;
  bool _loaded = false;

  bool _playedToday = false;
  _Hand? _userChoice;
  _Hand? _coachChoice;
  int _result = 0; // 1 승 / -1 패 / 0 무

  @override
  void initState() {
    super.initState();
    _load();
  }

  String get _today => DateTime.now().toIso8601String().substring(0, 10);

  Future<void> _load() async {
    final user = await _userService.getUser(_uid);
    final prefs = await SharedPreferences.getInstance();
    final lastDate = prefs.getString('lastRpsDate_$_uid');
    if (!mounted) return;
    setState(() {
      _user = user;
      if (lastDate == _today) {
        _playedToday = true;
        final u = prefs.getString('lastRpsUserChoice_$_uid');
        final c = prefs.getString('lastRpsCoachChoice_$_uid');
        _userChoice = _Hand.values.firstWhere((h) => h.name == u, orElse: () => _Hand.rock);
        _coachChoice = _Hand.values.firstWhere((h) => h.name == c, orElse: () => _Hand.rock);
        _result = prefs.getInt('lastRpsResult_$_uid') ?? 0;
      }
      _loaded = true;
    });
  }

  Future<void> _play(_Hand hand) async {
    if (_playedToday) return;
    final coachHand = _Hand.values[Random().nextInt(_Hand.values.length)];
    final result = _judge(hand, coachHand);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('lastRpsDate_$_uid', _today);
    await prefs.setString('lastRpsUserChoice_$_uid', hand.name);
    await prefs.setString('lastRpsCoachChoice_$_uid', coachHand.name);
    await prefs.setInt('lastRpsResult_$_uid', result);

    if (result == 1) {
      await _userService.addPoints(_uid, 10);
      await _userService.addCoachAffection(_uid, 3);
    } else {
      await _userService.addCoachAffection(_uid, 1);
    }

    if (!mounted) return;
    setState(() {
      _playedToday = true;
      _userChoice = hand;
      _coachChoice = coachHand;
      _result = result;
    });
  }

  String get _resultTitle {
    if (_result == 1) return '이겼어요! +10P 🎉';
    if (_result == -1) return '졌어요, 내일 다시 도전해요';
    return '비겼어요!';
  }

  Color get _resultColor {
    if (_result == 1) return _ok;
    if (_result == -1) return _errorColor;
    return _accent;
  }

  @override
  Widget build(BuildContext context) {
    final tone = _user?.coachTone;
    final name = _user?.coachDisplayName ?? '코치';

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: _ink,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text('오늘의 가위바위보', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator(color: _accent))
          : ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Center(
                  child: Column(
                    children: [
                      if (tone != null) CoachAvatar(imagePath: tone.imagePath, size: 76),
                      const SizedBox(height: 14),
                      Text('$name와 하루 한 번 가위바위보!',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w800, color: _ink)),
                      const SizedBox(height: 6),
                      const Text('이기면 포인트도 받고 친밀도도 올라가요',
                          style: TextStyle(fontSize: 12.5, color: _inkSub)),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                if (_playedToday && _userChoice != null && _coachChoice != null) ...[
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                            color: _ink.withValues(alpha: 0.05),
                            blurRadius: 16,
                            offset: const Offset(0, 6)),
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _HandDisplay(label: '나', hand: _userChoice!),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 20),
                              child: Text('VS',
                                  style: TextStyle(
                                      fontSize: 13, fontWeight: FontWeight.w800, color: _inkSub)),
                            ),
                            _HandDisplay(label: name, hand: _coachChoice!),
                          ],
                        ),
                        const SizedBox(height: 18),
                        Text(_resultTitle,
                            style: TextStyle(
                                fontSize: 15.5, fontWeight: FontWeight.w800, color: _resultColor)),
                        const SizedBox(height: 6),
                        const Text('오늘은 이미 도전했어요. 내일 또 만나요!',
                            style: TextStyle(fontSize: 11.5, color: _inkSub)),
                      ],
                    ),
                  ),
                ] else ...[
                  const Text('무엇을 낼까요?',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _ink)),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: _Hand.values
                        .map((h) => _HandButton(hand: h, onTap: () => _play(h)))
                        .toList(),
                  ),
                ],
              ],
            ),
    );
  }
}

class _HandDisplay extends StatelessWidget {
  final String label;
  final _Hand hand;
  const _HandDisplay({required this.label, required this.hand});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label,
            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: _inkSub)),
        const SizedBox(height: 6),
        Container(
          width: 56,
          height: 56,
          decoration: const BoxDecoration(color: _accentSoft, shape: BoxShape.circle),
          alignment: Alignment.center,
          child: Text(hand.emoji, style: const TextStyle(fontSize: 26)),
        ),
        const SizedBox(height: 4),
        Text(hand.label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _ink)),
      ],
    );
  }
}

class _HandButton extends StatelessWidget {
  final _Hand hand;
  final VoidCallback onTap;
  const _HandButton({required this.hand, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(40),
      child: Container(
        width: 78,
        height: 78,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(color: _ink.withValues(alpha: 0.08), blurRadius: 14, offset: const Offset(0, 6)),
          ],
        ),
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(hand.emoji, style: const TextStyle(fontSize: 28)),
            Text(hand.label, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: _ink)),
          ],
        ),
      ),
    );
  }
}
