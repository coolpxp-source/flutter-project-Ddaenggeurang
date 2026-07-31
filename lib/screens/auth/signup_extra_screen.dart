import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/coach_tone.dart';
import '../../models/user_model.dart';
import '../../services/user_service.dart';
import '../../widgets/common/ddaeng_modal.dart';
import '../../widgets/common/coach_avatar.dart';
import '../onboarding/onboarding_screen.dart'; // OnboardingData, DdaengColors
import '../../utils/formatters.dart';
import '../home/home_screen.dart';
import '../../services/avatar_service.dart';

/// 온보딩에서 입력받은 데이터를 이메일 인증 화면까지 임시로 들고 가기 위한 홀더.
/// main.dart의 AppGate는 Firebase 인증 상태만 보고 라우팅하기 때문에,
/// 회원가입 직전 로컬 위젯에만 있던 OnboardingData를 AppGate가
/// SignupExtraScreen을 만들 때 넘겨줄 방법이 없어서 이 정적 홀더를 거쳐간다.
/// (이메일 인증 게이트를 통과해 SignupExtraScreen에 도달하면 다 쓴 것이므로
///  값을 계속 들고 있어도 무방 — 다음 로그인 때는 온보딩을 다시 안 거치므로
///  null로 남아 전체 입력 폼이 뜬다)
class PendingOnboarding {
  static OnboardingData? data;
}

class DBCoach {
  final String id;
  final String name;
  final String title;
  final String desc;
  final String emoji;

  DBCoach({
    required this.id,
    required this.name,
    required this.title,
    required this.desc,
    required this.emoji,
  });

  factory DBCoach.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return DBCoach(
      id: doc.id,
      name: data['name'] ?? '',
      title: data['title'] ?? '',
      desc: data['desc'] ?? '',
      emoji: data['emoji'] ?? '🐶',
    );
  }
}

class SignupExtraScreen extends StatefulWidget {
  final String uid;
  final String email;
  final OnboardingData? onboardingData;

  const SignupExtraScreen({
    super.key,
    required this.uid,
    required this.email,
    this.onboardingData,
  });

  @override
  State<SignupExtraScreen> createState() => _SignupExtraScreenState();
}

class _SignupExtraScreenState extends State<SignupExtraScreen> {
  final _userService = UserService();
  final _firestore = FirebaseFirestore.instance;

  final _nicknameCtrl = TextEditingController();
  final _salaryCtrl = TextEditingController();
  final _customJobCtrl = TextEditingController();

  String _ageGroup = ''; // 선택 전 빈 문자열
  String? _job = '개발자';
  String _selectedCoachId = 'ddaengjwi';
  String _selectedCoachName = '땡쥐';

  String get _selectedCoachImagePath => CoachTone.fromCode(_selectedCoachId).imagePath;

  bool _saving = false;
  bool _forceFullForm = false;
  String? _nicknameError;
  int _nicknameLength = 0;

  // ─── 실시간 닉네임 중복확인 상태 ───
  bool? _nicknameAvailable; // null=미확인, true=사용가능, false=중복
  bool _checkingNickname = false;
  Timer? _nicknameDebounce;

  late Future<Map<String, dynamic>> _metaDataFuture;

  bool get _fromOnboarding => widget.onboardingData != null && !_forceFullForm;

  bool get _isButtonEnabled {
    final isNicknameOk = _nicknameLength >= 2 &&
        _nicknameLength <= 10 &&
        _nicknameAvailable == true; // 실시간 체크 통과해야 활성화
    final isAgeOk = _ageGroup.isNotEmpty;
    final isJobOk = _job != null;
    final isCustomJobOk = _job != '기타' || _customJobCtrl.text.trim().isNotEmpty;
    return isNicknameOk && isAgeOk && isJobOk && isCustomJobOk && !_saving;
  }

  @override
  void initState() {
    super.initState();
    _loadFirebaseMetadata();

    final d = widget.onboardingData;
    if (d != null) {
      _salaryCtrl.text = comma(d.salary);
      _ageGroup = d.ageGroup;
      _job = d.job;
      _selectedCoachId = d.tone.name;
      _selectedCoachName = d.tone.label;
    }

    _nicknameCtrl.addListener(_onNicknameChanged);
    _customJobCtrl.addListener(() => setState(() {}));

    // 온보딩에서 넘어온 닉네임이 이미 있다면 초기 진입 시에도 한 번 확인
    if (_nicknameCtrl.text.trim().length >= 2) {
      _onNicknameChanged();
    }
  }

  void _onNicknameChanged() {
    final text = _nicknameCtrl.text.trim();
    setState(() {
      _nicknameLength = text.length;
      _nicknameAvailable = null;
      _nicknameError = null;
    });
    _nicknameDebounce?.cancel();
    if (text.length < 2 || text.length > 10) return;
    _nicknameDebounce =
        Timer(const Duration(milliseconds: 500), () => _checkNicknameRealtime(text));
  }

  Future<void> _checkNicknameRealtime(String nickname) async {
    setState(() => _checkingNickname = true);
    debugPrint('🔍 닉네임 중복확인 시작: $nickname');
    try {
      final taken = await _userService
          .isNicknameTaken(nickname)
          .timeout(const Duration(seconds: 6), onTimeout: () {
        debugPrint('⚠️ isNicknameTaken 타임아웃 (6초) — Firestore 응답 없음');
        throw Exception('시간 초과');
      });
      debugPrint('✅ 닉네임 중복확인 완료: taken=$taken');
      if (!mounted || nickname != _nicknameCtrl.text.trim()) return;
      setState(() {
        _nicknameAvailable = !taken;
        _checkingNickname = false;
      });
    } catch (e) {
      debugPrint('❌ 닉네임 중복확인 실패: $e');
      if (!mounted) return;
      setState(() {
        _nicknameAvailable = null;
        _checkingNickname = false;
      });
    }
  }

  void _loadFirebaseMetadata() {
    _metaDataFuture = Future.wait([
      _firestore.collection('metadata').doc('options').get(),
      _firestore.collection('coaches').get(),
    ]).then((results) {
      final optionsDoc = results[0] as DocumentSnapshot;
      final coachesSnapshot = results[1] as QuerySnapshot;

      final optionsData = optionsDoc.data() as Map<String, dynamic>? ?? {};
      final ageGroups =
      List<String>.from(optionsData['ageGroups'] ?? ['10대', '20대', '30대']);

      final jobs = List<String>.from(optionsData['jobs'] ?? []);
      if (!jobs.contains('기타')) jobs.add('기타');

      final jobIcons = optionsData['jobIcons'] != null
          ? Map<String, String>.from(optionsData['jobIcons'])
          : <String, String>{};

      final coaches =
      coachesSnapshot.docs.map((doc) => DBCoach.fromFirestore(doc)).toList();

      return {
        'ageGroups': ageGroups,
        'jobs': jobs,
        'jobIcons': jobIcons,
        'coaches': coaches,
      };
    });
  }

  @override
  void dispose() {
    _nicknameDebounce?.cancel();
    _nicknameCtrl.dispose();
    _salaryCtrl.dispose();
    _customJobCtrl.dispose();
    super.dispose();
  }

  /// 저장만 담당. 화면 전환은 main.dart의 AppGate(StreamBuilder)가 자동으로 처리한다.
  Future<void> _submit() async {
    final nickname = _nicknameCtrl.text.trim();
    final salary = parseAmount(_salaryCtrl.text);
    final finalJob = _job == '기타' ? _customJobCtrl.text.trim() : (_job ?? '');

    if (nickname.length < 2 || nickname.length > 10) {
      setState(() => _nicknameError = '닉네임은 2~10자로 입력해주세요');
      return;
    }

    setState(() {
      _saving = true;
      _nicknameError = null;
    });

    try {
      debugPrint('🔍 제출 시 최종 닉네임 재확인: $nickname');
      final taken = await _userService
          .isNicknameTaken(nickname)
          .timeout(const Duration(seconds: 6), onTimeout: () {
        debugPrint('⚠️ 제출 시 isNicknameTaken 타임아웃 (6초)');
        throw Exception('닉네임 확인 시간 초과');
      });
      debugPrint('✅ 제출 시 확인 완료: taken=$taken');

      if (taken) {
        if (!mounted) return;
        setState(() {
          _nicknameError = '이미 사용 중인 닉네임이에요';
          _nicknameAvailable = false;
          _saving = false;
        });
        return;
      }

      debugPrint('📝 createUser 호출 시작');
      await _userService
          .createUser(UserModel(
        userId: widget.uid,
        nickname: nickname,
        email: widget.email,
        salary: salary,
        ageGroup: _ageGroup,
        job: finalJob,
        coachTone: CoachTone.values.firstWhere(
              (t) => t.name == _selectedCoachId,
          orElse: () => CoachTone.ddaengjwi,
        ),
      ))
          .timeout(const Duration(seconds: 8), onTimeout: () {
        debugPrint('⚠️ createUser 타임아웃 (8초) — Firestore 쓰기 응답 없음');
        throw Exception('저장 시간 초과');
      });
      debugPrint('✅ createUser 완료');

      try {
        await AvatarService.instance.initializeDefaultAvatar();
        debugPrint('✅ 기본 아바타 초기화 완료');
      } catch (e) {
        debugPrint('⚠️ 기본 아바타 초기화 실패 (계속 진행): $e');
      }

      debugPrint('✅ 홈 화면으로 이동');
      if (!mounted) return;
      // login_screen.dart / email_signup_screen.dart가 pushReplacement로 이 화면을
      // 열기 때문에 main.dart의 AppGate는 더 이상 위젯 트리에 없다. 따라서 AppGate의
      // StreamBuilder에 의존하지 않고 여기서 직접 홈으로 전환하고 스택을 정리한다.
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (route) => false,
      );
    } catch (e) {
      debugPrint('❌ _submit 실패: $e');
      if (!mounted) return;
      setState(() => _saving = false);
      await DdaengModal.alert(
        context,
        title: '저장에 실패했어요',
        message: '잠시 후 다시 시도해주세요',
        type: ModalType.danger,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: FutureBuilder<Map<String, dynamic>>(
          future: _metaDataFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                  child: CircularProgressIndicator(color: DdaengColors.blue));
            }
            if (snapshot.hasError || !snapshot.hasData) {
              return const Center(child: Text('데이터를 불러오지 못했어요. 앱을 재실행해주세요.'));
            }

            final ageGroups = snapshot.data!['ageGroups'] as List<String>;
            final jobs = snapshot.data!['jobs'] as List<String>;
            final jobIcons = snapshot.data!['jobIcons'] as Map<String, String>;
            final coaches = snapshot.data!['coaches'] as List<DBCoach>;

            return Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(24, 28, 24, 40),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ─── 헤더 (풀폼일 때만) ───
                        if (!_fromOnboarding) ...[
                          Center(
                            child: Column(
                              children: [
                                Container(
                                  width: 84,
                                  height: 84,
                                  decoration: BoxDecoration(
                                    color: DdaengColors.blueSoft,
                                    shape: BoxShape.circle,
                                  ),
                                  alignment: Alignment.center,
                                  child: CoachAvatar(
                                      imagePath: _selectedCoachImagePath, size: 64),
                                ),
                                const SizedBox(height: 20),
                                const Text(
                                  '반가워요!\n몇 가지만 알려주세요',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w800,
                                    height: 1.4,
                                    letterSpacing: -0.6,
                                    color: DdaengColors.ink,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  '땡그랑이 확실하게 예산을 밀착 코칭해 드릴게요',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w500,
                                    color: DdaengColors.inkSub,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 40),
                        ],

                        // ─── 온보딩 거친 경우: 히어로 카드 + 닉네임(실시간 중복확인) + 프로필 요약 ───
                        if (_fromOnboarding) ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  DdaengColors.navy,
                                  DdaengColors.navy.withOpacity(0.85),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: [
                                BoxShadow(
                                  color: DdaengColors.navy.withOpacity(0.25),
                                  blurRadius: 24,
                                  offset: const Offset(0, 12),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                Container(
                                  width: 76,
                                  height: 76,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.12),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color: Colors.white.withOpacity(0.2),
                                        width: 1.5),
                                  ),
                                  alignment: Alignment.center,
                                  child: CoachAvatar(
                                      imagePath: _selectedCoachImagePath, size: 60),
                                ),
                                const SizedBox(height: 14),
                                Text('$_selectedCoachName 코치',
                                    style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white)),
                                const SizedBox(height: 4),
                                Text('이 이름으로 매일 소비 습관을 응원할게요',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.white.withOpacity(0.6))),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const _FieldLabel('닉네임', required: true),
                              Text('$_nicknameLength/10',
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: _nicknameLength > 10
                                          ? const Color(0xFFF04438)
                                          : const Color(0xFFB0B8C1))),
                            ],
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _nicknameCtrl,
                            maxLength: 10,
                            autofocus: true,
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: DdaengColors.ink),
                            decoration: InputDecoration(
                              hintText: '불릴 예쁜 이름을 적어주세요',
                              hintStyle: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFFB0B8C1)),
                              errorText: _nicknameError,
                              counterText: '',
                              filled: true,
                              fillColor: DdaengColors.bg,
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 18, vertical: 18),
                              suffixIcon: _checkingNickname
                                  ? const Padding(
                                padding: EdgeInsets.all(14),
                                child: SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: DdaengColors.blue),
                                ),
                              )
                                  : _nicknameAvailable == true
                                  ? const Icon(Icons.check_circle_rounded,
                                  color: Color(0xFF12B76A))
                                  : _nicknameAvailable == false
                                  ? const Icon(Icons.cancel_rounded,
                                  color: Color(0xFFF04438))
                                  : null,
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide.none),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: const BorderSide(
                                    color: DdaengColors.blue, width: 1.8),
                              ),
                              errorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide:
                                const BorderSide(color: Color(0xFFF04438)),
                              ),
                            ),
                          ),
                          if (_nicknameError == null &&
                              _nicknameAvailable == false)
                            const Padding(
                              padding: EdgeInsets.only(top: 6, left: 4),
                              child: Text('이미 사용 중인 닉네임이에요',
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFFF04438))),
                            )
                          else if (_nicknameError == null &&
                              _nicknameAvailable == true)
                            const Padding(
                              padding: EdgeInsets.only(top: 6, left: 4),
                              child: Text('✓ 사용 가능한 닉네임이에요',
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF12B76A))),
                            ),
                          const SizedBox(height: 28),

                          const _FieldLabel('설정된 프로필'),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: _ProfileChip(
                                  icon: Icons.savings_outlined,
                                  label: '월 실수령액',
                                  value:
                                  '${comma(parseAmount(_salaryCtrl.text))}원',
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _ProfileChip(
                                  icon: Icons.cake_outlined,
                                  label: '연령대',
                                  value: _ageGroup,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          _ProfileChip(
                            icon: Icons.badge_outlined,
                            label: '직군',
                            value: '${jobIcons[_job] ?? '✨'} ${_job ?? ''}',
                            fullWidth: true,
                          ),
                          const SizedBox(height: 12),

                          Center(
                            child: TextButton.icon(
                              onPressed: () =>
                                  setState(() => _forceFullForm = true),
                              icon: const Icon(Icons.tune_rounded, size: 16),
                              label: const Text('프로필 정보 다시 입력할래요'),
                              style: TextButton.styleFrom(
                                foregroundColor: DdaengColors.inkSub,
                                textStyle: const TextStyle(
                                    fontSize: 12.5, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                        ],

                        // ─── 온보딩 안 거친 경우: 전체 입력 폼 ───
                        if (!_fromOnboarding) ...[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const _FieldLabel('닉네임', required: true),
                              Text('$_nicknameLength/10',
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: _nicknameLength > 10
                                          ? const Color(0xFFF04438)
                                          : const Color(0xFFB0B8C1))),
                            ],
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _nicknameCtrl,
                            maxLength: 10,
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: DdaengColors.ink),
                            decoration: InputDecoration(
                              hintText: '불릴 예쁜 이름을 적어주세요',
                              hintStyle: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFFB0B8C1)),
                              errorText: _nicknameError,
                              counterText: '',
                              filled: true,
                              fillColor: DdaengColors.bg,
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 18, vertical: 16),
                              suffixIcon: _checkingNickname
                                  ? const Padding(
                                padding: EdgeInsets.all(14),
                                child: SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: DdaengColors.blue),
                                ),
                              )
                                  : _nicknameAvailable == true
                                  ? const Icon(Icons.check_circle_rounded,
                                  color: Color(0xFF12B76A))
                                  : _nicknameAvailable == false
                                  ? const Icon(Icons.cancel_rounded,
                                  color: Color(0xFFF04438))
                                  : null,
                              enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide.none),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: const BorderSide(
                                    color: DdaengColors.blue, width: 1.8),
                              ),
                            ),
                          ),
                          if (_nicknameError == null &&
                              _nicknameAvailable == false)
                            const Padding(
                              padding: EdgeInsets.only(top: 6, left: 4),
                              child: Text('이미 사용 중인 닉네임이에요',
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFFF04438))),
                            )
                          else if (_nicknameError == null &&
                              _nicknameAvailable == true)
                            const Padding(
                              padding: EdgeInsets.only(top: 6, left: 4),
                              child: Text('✓ 사용 가능한 닉네임이에요',
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF12B76A))),
                            ),
                          const SizedBox(height: 32),

                          const _FieldLabel('월 실수령액', required: true),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _salaryCtrl,
                            keyboardType: TextInputType.number,
                            inputFormatters: [ThousandsFormatter()],
                            onChanged: (_) => setState(() {}),
                            style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: DdaengColors.ink),
                            decoration: InputDecoration(
                              hintText: '2,800,000',
                              hintStyle: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFFB0B8C1)),
                              suffixText: '원',
                              suffixStyle: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: DdaengColors.inkSub),
                              filled: true,
                              fillColor: DdaengColors.bg,
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 18, vertical: 18),
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide.none),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: const BorderSide(
                                    color: DdaengColors.blue, width: 1.8),
                              ),
                            ),
                          ),
                          if (parseAmount(_salaryCtrl.text) > 0) ...[
                            const SizedBox(height: 8),
                            Padding(
                              padding: const EdgeInsets.only(left: 4),
                              child: Text(
                                koreanAmount(parseAmount(_salaryCtrl.text)),
                                style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: DdaengColors.blue),
                              ),
                            ),
                          ],
                          const SizedBox(height: 30),

                          const _FieldLabel('연령대', required: true),
                          const SizedBox(height: 10),
                          _AgeGroupSelector(
                            ages: ageGroups,
                            selected: _ageGroup.isEmpty ? null : _ageGroup,
                            onSelect: (v) => setState(() => _ageGroup = v),
                          ),
                          const SizedBox(height: 30),

                          const _FieldLabel('직군', required: true),
                          const SizedBox(height: 10),
                          GestureDetector(
                            onTap: () => _openJobPicker(context, jobs, jobIcons),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 160),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: _job != null
                                    ? DdaengColors.blueSoft
                                    : DdaengColors.bg,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: _job != null
                                      ? DdaengColors.blue
                                      : Colors.transparent,
                                  width: 1.6,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 42,
                                    height: 42,
                                    decoration: BoxDecoration(
                                      color: _job != null
                                          ? Colors.white
                                          : const Color(0xFFE8EAED),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      _job != null
                                          ? (jobIcons[_job] ?? '✨')
                                          : '💭',
                                      style: const TextStyle(fontSize: 20),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      _job ?? '직군을 선택해주세요',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: _job != null
                                            ? FontWeight.w800
                                            : FontWeight.w600,
                                        color: _job != null
                                            ? DdaengColors.ink
                                            : const Color(0xFFB0B8C1),
                                      ),
                                    ),
                                  ),
                                  Icon(Icons.keyboard_arrow_down_rounded,
                                      color: _job != null
                                          ? DdaengColors.blue
                                          : DdaengColors.inkSub),
                                ],
                              ),
                            ),
                          ),
                          AnimatedCrossFade(
                            duration: const Duration(milliseconds: 220),
                            firstChild: const SizedBox.shrink(),
                            secondChild: Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: TextField(
                                controller: _customJobCtrl,
                                style: const TextStyle(
                                    fontSize: 14, fontWeight: FontWeight.w600),
                                decoration: InputDecoration(
                                  hintText: '직군을 직접 입력해주세요',
                                  hintStyle: const TextStyle(
                                      fontSize: 13.5,
                                      color: Color(0xFFB0B8C1)),
                                  filled: true,
                                  fillColor: DdaengColors.bg,
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 14),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                        color: DdaengColors.blue, width: 1.2),
                                  ),
                                ),
                              ),
                            ),
                            crossFadeState: _job == '기타'
                                ? CrossFadeState.showSecond
                                : CrossFadeState.showFirst,
                          ),
                          const SizedBox(height: 30),

                          const _FieldLabel('잔소리 코치 성향'),
                          const SizedBox(height: 4),
                          const Text('코치의 성향에 따라 잔소리 수위가 달라져요',
                              style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w500,
                                  color: DdaengColors.inkSub)),
                          const SizedBox(height: 14),
                          if (coaches.isEmpty)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 20),
                              child: Text(
                                '코치 정보를 불러올 수 없어요.\ncoaches 컬렉션을 확인해주세요.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    fontSize: 12.5, color: Color(0xFFF04438)),
                              ),
                            )
                          else
                            ...coaches.map((c) => _CoachCard(
                              coach: c,
                              selected: _selectedCoachId == c.id,
                              onTap: () => setState(() {
                                _selectedCoachId = c.id;
                                _selectedCoachName = c.name;
                              }),
                            )),
                        ],
                      ],
                    ),
                  ),
                ),

                // ─── 하단 버튼 ───
                Container(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 16,
                          offset: const Offset(0, -4)),
                    ],
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isButtonEnabled ? _submit : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: DdaengColors.navy,
                        disabledBackgroundColor: const Color(0xFFE5E8EB),
                        foregroundColor: Colors.white,
                        disabledForegroundColor: const Color(0xFFB0B8C1),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                      child: _saving
                          ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.4, color: Colors.white))
                          : const Text('땡그랑 시작하기',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _openJobPicker(
      BuildContext context, List<String> jobs, Map<String, String> jobIcons) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _JobPickerSheet(
        jobs: jobs,
        jobIcons: jobIcons,
        selected: _job,
        onSelect: (j) {
          setState(() {
            _job = j;
            if (j != '기타') _customJobCtrl.clear();
          });
          Navigator.pop(context);
        },
      ),
    );
  }
}

// ══════════════════ 서브 위젯 ══════════════════

class _FieldLabel extends StatelessWidget {
  final String text;
  final bool required;
  const _FieldLabel(this.text, {this.required = false});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Text(text,
          style: const TextStyle(
              fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF4E5968))),
      if (required)
        const Text(' *',
            style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFFF04438))),
    ],
  );
}

/// 프로필 요약 아이콘 칩 (온보딩 완료 화면용)
class _ProfileChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool fullWidth;

  const _ProfileChip({
    required this.icon,
    required this.label,
    required this.value,
    this.fullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: fullWidth ? double.infinity : null,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: DdaengColors.bg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration:
            const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Icon(icon, size: 16, color: DdaengColors.blue),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: DdaengColors.inkSub)),
                const SizedBox(height: 1),
                Text(value,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: DdaengColors.ink)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 연령대 선택 (드롭다운 스타일 바텀시트) — 직군 선택과 톤 통일
class _AgeGroupSelector extends StatelessWidget {
  final List<String> ages;
  final String? selected;
  final ValueChanged<String> onSelect;

  const _AgeGroupSelector({
    required this.ages,
    required this.selected,
    required this.onSelect,
  });

  void _open(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                    color: DdaengColors.line, borderRadius: BorderRadius.circular(10)),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(24, 18, 24, 12),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('연령대가 어떻게 되시나요?',
                      style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                          color: DdaengColors.ink)),
                ),
              ),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.6,
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: ages.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 4),
                  itemBuilder: (context, i) {
                    final age = ages[i];
                    final sel = age == selected;
                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () {
                          onSelect(age);
                          Navigator.pop(context);
                        },
                        child: Container(
                          padding:
                          const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                          decoration: BoxDecoration(
                            color: sel ? DdaengColors.blueSoft : Colors.transparent,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  age,
                                  style: TextStyle(
                                    fontSize: 15.5,
                                    fontWeight:
                                    sel ? FontWeight.w700 : FontWeight.w500,
                                    color: sel
                                        ? DdaengColors.blueDeep
                                        : DdaengColors.ink,
                                  ),
                                ),
                              ),
                              if (sel)
                                const Icon(Icons.check_rounded,
                                    color: DdaengColors.blue, size: 20),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _open(context),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: selected != null ? DdaengColors.blueSoft : DdaengColors.bg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected != null ? DdaengColors.blue : Colors.transparent,
            width: 1.6,
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.cake_outlined,
                size: 19,
                color: selected != null ? DdaengColors.blue : DdaengColors.inkSub),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                selected ?? '연령대를 선택해주세요',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: selected != null ? FontWeight.w800 : FontWeight.w600,
                  color: selected != null
                      ? DdaengColors.ink
                      : const Color(0xFFB0B8C1),
                ),
              ),
            ),
            Icon(Icons.keyboard_arrow_down_rounded,
                color: selected != null ? DdaengColors.blue : DdaengColors.inkSub),
          ],
        ),
      ),
    );
  }
}

class _CoachCard extends StatelessWidget {
  final DBCoach coach;
  final bool selected;
  final VoidCallback onTap;

  const _CoachCard({
    required this.coach,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? DdaengColors.blueSoft : DdaengColors.bg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
              color: selected ? DdaengColors.blue : Colors.transparent, width: 1.6),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                  color: selected ? Colors.white : const Color(0xFFF2F4F6),
                  shape: BoxShape.circle),
              alignment: Alignment.center,
              child: CoachAvatar(
                  imagePath: CoachTone.fromCode(coach.id).imagePath, size: 40),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(coach.name,
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: DdaengColors.ink)),
                      const SizedBox(width: 6),
                      Text(coach.title,
                          style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: DdaengColors.inkSub)),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(coach.desc,
                      style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF4E5968))),
                ],
              ),
            ),
            Icon(
              selected ? Icons.check_circle_rounded : Icons.circle_outlined,
              color: selected ? DdaengColors.blue : const Color(0xFFD1D6DB),
              size: 24,
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════ 직군 검색 그리드 바텀시트 ══════════════════

class _JobPickerSheet extends StatefulWidget {
  final List<String> jobs;
  final Map<String, String> jobIcons;
  final String? selected;
  final ValueChanged<String> onSelect;

  const _JobPickerSheet({
    required this.jobs,
    required this.jobIcons,
    required this.selected,
    required this.onSelect,
  });

  @override
  State<_JobPickerSheet> createState() => _JobPickerSheetState();
}

class _JobPickerSheetState extends State<_JobPickerSheet> {
  String _query = '';

  String _iconOf(String j) => widget.jobIcons[j] ?? '✨';

  @override
  Widget build(BuildContext context) {
    final filtered = widget.jobs
        .where((j) => j.toLowerCase().contains(_query.toLowerCase()))
        .toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.78,
      minChildSize: 0.5,
      maxChildSize: 0.94,
      expand: false,
      builder: (context, scrollCtrl) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                    color: DdaengColors.line, borderRadius: BorderRadius.circular(10)),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(24, 18, 24, 0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('어떤 일을 하고 계신가요?',
                      style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                          color: DdaengColors.ink)),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 14, 24, 6),
                child: TextField(
                  onChanged: (v) => setState(() => _query = v),
                  decoration: InputDecoration(
                    hintText: '직군 검색',
                    hintStyle: const TextStyle(color: Color(0xFFB0B8C1)),
                    prefixIcon:
                    const Icon(Icons.search, color: DdaengColors.inkSub, size: 20),
                    filled: true,
                    fillColor: DdaengColors.bg,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                  ),
                ),
              ),
              Expanded(
                child: filtered.isEmpty
                    ? const Center(
                    child: Text('검색 결과가 없어요',
                        style: TextStyle(color: DdaengColors.inkSub, fontSize: 14)))
                    : GridView.builder(
                  controller: scrollCtrl,
                  physics: const ClampingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 2.5,
                  ),
                  itemCount: filtered.length,
                  itemBuilder: (context, i) {
                    final job = filtered[i];
                    final sel = job == widget.selected;
                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () => widget.onSelect(job),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 140),
                          padding:
                          const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: sel ? DdaengColors.blueSoft : DdaengColors.bg,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: sel ? DdaengColors.blue : Colors.transparent,
                              width: 1.4,
                            ),
                          ),
                          child: Row(
                            children: [
                              Text(_iconOf(job), style: const TextStyle(fontSize: 19)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  job,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight:
                                    sel ? FontWeight.w700 : FontWeight.w600,
                                    color: sel
                                        ? DdaengColors.blueDeep
                                        : const Color(0xFF333D4B),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}