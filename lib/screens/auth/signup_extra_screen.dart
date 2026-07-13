import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/coach_tone.dart';
import '../../models/user_model.dart';
import '../../services/user_service.dart';
import '../../widgets/common/ddaeng_modal.dart';
import '../onboarding/onboarding_screen.dart';

class DBCoach {
  final String id;
  final String name;
  final String title;
  final String desc;
  final String emoji;

  DBCoach({required this.id, required this.name, required this.title, required this.desc, required this.emoji});

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
  final _customJobCtrl = TextEditingController(); // 기타 직군 직접 입력용 컨트롤러 추가

  String _ageGroup = '20대';
  String _job = '개발자';
  String _selectedCoachId = 'ddaengjwi';
  String _selectedCoachEmoji = '🐭';
  String _selectedCoachName = '땡쥐';

  bool _saving = false;
  String? _nicknameError;
  int _nicknameLength = 0;

  late Future<Map<String, dynamic>> _metaDataFuture;

  bool get _fromOnboarding => widget.onboardingData != null;

  // 기타 선택 시 입력 필드가 비어있으면 버튼 비활성화하는 규칙 추가
  bool get _isButtonEnabled {
    final isNicknameOk = _nicknameLength >= 2 && _nicknameLength <= 10;
    final isCustomJobOk = _job != '기타' || _customJobCtrl.text.trim().isNotEmpty;
    return isNicknameOk && isCustomJobOk && !_saving;
  }

  @override
  void initState() {
    super.initState();
    _loadFirebaseMetadata();

    final d = widget.onboardingData;
    if (d != null) {
      _salaryCtrl.text = d.salary.toString();
      _ageGroup = d.ageGroup;
      _job = d.job;
      _selectedCoachId = d.tone.name;
      _selectedCoachEmoji = d.tone.emoji;
      _selectedCoachName = d.tone.label;
    }

    _nicknameCtrl.addListener(() {
      setState(() => _nicknameLength = _nicknameCtrl.text.trim().length);
    });

    // 기타 입력창 텍스트 감지 리스너 (하단 버튼 활성화 실시간 반영용)
    _customJobCtrl.addListener(() {
      setState(() {});
    });
  }

  void _loadFirebaseMetadata() {
    _metaDataFuture = Future.wait([
      _firestore.collection('metadata').doc('options').get(),
      _firestore.collection('coaches').get(),
    ]).then((results) {
      final optionsDoc = results[0] as DocumentSnapshot;
      final coachesSnapshot = results[1] as QuerySnapshot;

      final optionsData = optionsDoc.data() as Map<String, dynamic>? ?? {};
      final ageGroups = List<String>.from(optionsData['ageGroups'] ?? ['10대', '20대', '30대']);

      // 파이어베이스에서 직군 긁어온 뒤, 마지막에 '기타' 강제 추가
      final jobs = List<String>.from(optionsData['jobs'] ?? []);
      if (!jobs.contains('기타')) {
        jobs.add('기타');
      }

      final coaches = coachesSnapshot.docs.map((doc) => DBCoach.fromFirestore(doc)).toList();

      return {
        'ageGroups': ageGroups,
        'jobs': jobs,
        'coaches': coaches,
      };
    });
  }

  @override
  void dispose() {
    _nicknameCtrl.dispose();
    _salaryCtrl.dispose();
    _customJobCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final nickname = _nicknameCtrl.text.trim();
    final salary = int.tryParse(_salaryCtrl.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;

    // 최종 저장할 직군 텍스트 결정 로직
    final finalJob = _job == '기타' ? _customJobCtrl.text.trim() : _job;

    if (nickname.length < 2 || nickname.length > 10) {
      setState(() => _nicknameError = '닉네임은 2~10자로 입력해주세요');
      return;
    }

    setState(() {
      _saving = true;
      _nicknameError = null;
    });

    try {
      if (await _userService.isNicknameTaken(nickname)) {
        setState(() {
          _nicknameError = '이미 사용 중인 닉네임이에요';
          _saving = false;
        });
        return;
      }

      await _userService.createUser(UserModel(
        userId: widget.uid,
        nickname: nickname,
        email: widget.email,
        salary: salary,
        ageGroup: _ageGroup,
        job: finalJob, // 직접 입력 혹은 선택한 직군 저장
        coachTone: CoachTone.values.firstWhere((t) => t.name == _selectedCoachId, orElse: () => CoachTone.ddaengjwi),
      ));

      if (!mounted) return;
      await DdaengModal.alert(
        context,
        title: '$nickname님, 환영해요!',
        message: '$_selectedCoachName 코치가 함께할게요.\n이제 지출을 기록하고 잔소리를 들어보세요',
        type: ModalType.success,
        emoji: _selectedCoachEmoji,
        confirmText: '시작하기',
      );
    } catch (e) {
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
      backgroundColor: const Color(0xFFFAFAFC),
      body: SafeArea(
        child: FutureBuilder<Map<String, dynamic>>(
          future: _metaDataFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: Color(0xFF2F6BFF)));
            }
            if (snapshot.hasError || !snapshot.hasData) {
              return const Center(child: Text('데이터를 불러오지 못했어요. 앱을 재실행해주세요.'));
            }

            final ageGroups = snapshot.data!['ageGroups'] as List<String>;
            final jobs = snapshot.data!['jobs'] as List<String>;
            final coaches = snapshot.data!['coaches'] as List<DBCoach>;

            return Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(24, 40, 24, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ─── 상단 코치 헤더링 ───
                        Center(
                          child: Column(
                            children: [
                              Container(
                                width: 88,
                                height: 88,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF2F6BFF).withOpacity(0.08),
                                      blurRadius: 24,
                                      offset: const Offset(0, 8),
                                    )
                                  ],
                                ),
                                alignment: Alignment.center,
                                child: Text(_selectedCoachEmoji, style: const TextStyle(fontSize: 42)),
                              ),
                              const SizedBox(height: 24),
                              Text(
                                _fromOnboarding ? '마지막으로\n닉네임만 정해주세요' : '반가워요!\n몇 가지만 알려주세요',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                  height: 1.4,
                                  letterSpacing: -0.6,
                                  color: Color(0xFF191F28),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _fromOnboarding
                                    ? '$_selectedCoachName 코치가 이 이름으로 매섭게 잔소리해 드릴게요'
                                    : '땡그랑이 확실하게 예산을 밀착 코칭해 드릴게요',
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF8B95A1)),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 40),

                        // ─── 닉네임 ───
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const _FieldLabel('닉네임', required: true),
                            Text('$_nicknameLength/10',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: _nicknameLength > 10 ? const Color(0xFFF04438) : const Color(0xFFB0B8C1),
                              ),
                            ),
                          ],
                        ),
                        TextField(
                          controller: _nicknameCtrl,
                          maxLength: 10,
                          autofocus: _fromOnboarding,
                          onChanged: (_) => setState(() => _nicknameError = null),
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF191F28)),
                          decoration: InputDecoration(
                            hintText: '대체로 불릴 예쁜 이름을 적어주세요',
                            hintStyle: const TextStyle(fontWeight: FontWeight.w500, color: Color(0xFFB0B8C1)),
                            errorText: _nicknameError,
                            counterText: '',
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(color: Color(0xFFEEEEF3), width: 1.2),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(color: Color(0xFF2F6BFF), width: 1.8),
                            ),
                            errorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(color: Color(0xFFF04438), width: 1.2),
                            ),
                            focusedErrorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(color: Color(0xFFF04438), width: 1.8),
                            ),
                          ),
                        ),

                        if (_fromOnboarding) ...[
                          const SizedBox(height: 32),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: const Color(0xFFEEEEF3), width: 1.2),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('설정된 나의 소비 프로필', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF8B95A1))),
                                const SizedBox(height: 8),
                                _SummaryRow('월 실수령액', '${_comma(int.tryParse(_salaryCtrl.text) ?? 0)}원'),
                                _SummaryRow('연령대 · 직군', '$_ageGroup · $_job'),
                                _SummaryRow('선택한 코치', '$_selectedCoachEmoji $_selectedCoachName'),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          Center(
                            child: TextButton.icon(
                              onPressed: () => Navigator.pop(context),
                              icon: const Icon(Icons.keyboard_arrow_left_rounded, size: 18),
                              label: const Text('프로필 정보 다시 입력할래요'),
                              style: TextButton.styleFrom(
                                foregroundColor: const Color(0xFF8B95A1),
                                textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                        ],

                        // ─── 온보딩 우회 폼 풀버전 ───
                        if (!_fromOnboarding) ...[
                          const SizedBox(height: 32),
                          const _FieldLabel('월 실수령액', required: true),
                          TextField(
                            controller: _salaryCtrl,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF191F28)),
                            decoration: InputDecoration(
                              hintText: '예시: 2,800,000',
                              hintStyle: const TextStyle(fontWeight: FontWeight.w500, color: Color(0xFFB0B8C1)),
                              suffixText: '원',
                              suffixStyle: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF4E5968)),
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: const BorderSide(color: Color(0xFFEEEEF3), width: 1.2),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: const BorderSide(color: Color(0xFF2F6BFF), width: 1.8),
                              ),
                            ),
                          ),
                          const SizedBox(height: 32),

                          const _FieldLabel('연령대', required: true),
                          _ChipGroup(
                            items: ageGroups,
                            selected: _ageGroup,
                            onSelect: (v) => setState(() => _ageGroup = v),
                          ),
                          const SizedBox(height: 32),

                          const _FieldLabel('직군', required: true),
                          _ChipGroup(
                            items: jobs,
                            selected: _job,
                            onSelect: (v) => setState(() {
                              _job = v;
                              if (v != '기타') _customJobCtrl.clear(); // 기타 해제 시 입력 내용 삭제
                            }),
                          ),

                          // ─── [핵심 개선] '기타' 선택 시 자연스럽게 등장하는 인풋 위젯 ───
                          AnimatedCrossFade(
                            duration: const Duration(milliseconds: 250),
                            firstChild: const SizedBox.shrink(),
                            secondChild: Padding(
                              padding: const EdgeInsets.only(top: 14),
                              child: TextField(
                                controller: _customJobCtrl,
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                                decoration: InputDecoration(
                                  hintText: '나의 직군을 직접 입력해 주세요 (예: 전문직, 요리사 등)',
                                  hintStyle: const TextStyle(color: Color(0xFFB0B8C1), fontSize: 14),
                                  filled: true,
                                  fillColor: Colors.white,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(color: Color(0xFF2F6BFF), width: 1.2),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(color: Color(0xFF1D4ED8), width: 1.8),
                                  ),
                                ),
                              ),
                            ),
                            crossFadeState: _job == '기타' ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                          ),
                          const SizedBox(height: 32),

                          const _FieldLabel('잔소리 코치 성향'),
                          const Text('코치의 성향에 따라 잔소리 수위가 달라져요 (언제든 변경 가능)',
                            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: Color(0xFF8B95A1)),
                          ),
                          const SizedBox(height: 16),
                          ...coaches.map((c) => _CoachCard(
                            coach: c,
                            selected: _selectedCoachId == c.id,
                            onTap: () => setState(() {
                              _selectedCoachId = c.id;
                              _selectedCoachEmoji = c.emoji;
                              _selectedCoachName = c.name;
                            }),
                          )),
                        ],

                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),

                // ─── 하단 고정 버튼 시트 ───
                Container(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    boxShadow: [BoxShadow(color: Color(0xFFF2F4F6), blurRadius: 16, offset: Offset(0, -4))],
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isButtonEnabled ? _submit : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1D4ED8),
                        disabledBackgroundColor: const Color(0xFFE5E8EB),
                        foregroundColor: Colors.white,
                        disabledForegroundColor: const Color(0xFFB0B8C1),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: _saving
                          ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                      )
                          : const Text('땡그랑 시작하기', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
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

  static String _comma(int n) => n.toString().replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+$)'),
        (m) => '${m[1]},',
  );
}

// ══════════════════ 서브 위젯 레이어 ══════════════════

class _FieldLabel extends StatelessWidget {
  final String text;
  final bool required;
  const _FieldLabel(this.text, {this.required = false});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      children: [
        Text(text, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF4E5968))),
        if (required)
          const Text(' *', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFFF04438))),
      ],
    ),
  );
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  const _SummaryRow(this.label, this.value);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF4E5968))),
        Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF191F28))),
      ],
    ),
  );
}

class _ChipGroup extends StatelessWidget {
  final List<String> items;
  final String selected;
  final ValueChanged<String> onSelect;

  const _ChipGroup({required this.items, required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: items.map((e) {
        final sel = e == selected;
        return GestureDetector(
          onTap: () => onSelect(e),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: sel ? const Color(0xFFE8F3FF) : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: sel ? const Color(0xFF2F6BFF) : const Color(0xFFEEEEF3), width: sel ? 1.6 : 1.2),
            ),
            child: Text(e, style: TextStyle(fontSize: 14, fontWeight: sel ? FontWeight.w700 : FontWeight.w600, color: sel ? const Color(0xFF1B51E5) : const Color(0xFF4E5968))),
          ),
        );
      }).toList(),
    );
  }
}

class _CoachCard extends StatelessWidget {
  final DBCoach coach;
  final bool selected;
  final VoidCallback onTap;

  const _CoachCard({required this.coach, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFE8F3FF) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: selected ? const Color(0xFF2F6BFF) : const Color(0xFFEEEEF3), width: selected ? 1.8 : 1.2),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(color: selected ? Colors.white : const Color(0xFFF9FAFC), shape: BoxShape.circle),
              alignment: Alignment.center,
              child: Text(coach.emoji, style: const TextStyle(fontSize: 26)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(coach.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF191F28))),
                      const SizedBox(width: 8),
                      Text(coach.title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF96A0B1))),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(coach.desc, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF4E5968))),
                ],
              ),
            ),
            Icon(
              selected ? Icons.check_circle_rounded : Icons.radio_button_off_rounded,
              color: selected ? const Color(0xFF2F6BFF) : const Color(0xFFE5E8EB),
              size: 24,
            ),
          ],
        ),
      ),
    );
  }
}