import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/coach_tone.dart';
import '../../models/user_model.dart';
import '../../services/user_service.dart';
import '../../widgets/common/ddaeng_modal.dart';
import '../onboarding/onboarding_screen.dart'; // OnboardingData, DdaengColors
import '../../utils/formatters.dart';

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

  String _ageGroup = '20대';
  String? _job = '개발자';
  String _selectedCoachId = 'ddaengjwi';
  String _selectedCoachEmoji = '🐭';
  String _selectedCoachName = '땡쥐';

  bool _saving = false;
  bool _forceFullForm = false;

  // ─── 닉네임 중복 확인용 상태 ───
  String? _nicknameError;
  int _nicknameLength = 0;
  bool _isNicknameChecked = false; // 중복 확인 완료 여부
  bool _isCheckingNickname = false; // 중복 확인 로딩 상태

  late Future<Map<String, dynamic>> _metaDataFuture;

  bool get _fromOnboarding => widget.onboardingData != null && !_forceFullForm;

  // 🔥 중복 확인(_isNicknameChecked)을 통과해야만 버튼 활성화
  bool get _isButtonEnabled {
    final isCustomJobOk = _job != '기타' || _customJobCtrl.text.trim().isNotEmpty;
    return _isNicknameChecked && isCustomJobOk && !_saving;
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
      _selectedCoachEmoji = d.tone.emoji;
      _selectedCoachName = d.tone.label;
    }

    _nicknameCtrl.addListener(() {
      setState(() {
        _nicknameLength = _nicknameCtrl.text.trim().length;
        // 닉네임이 한 글자라도 수정되면 중복 확인 상태 초기화
        _isNicknameChecked = false;
        _nicknameError = null;
      });
    });
    _customJobCtrl.addListener(() => setState(() {}));
  }

  void _loadFirebaseMetadata() {
    _metaDataFuture = Future.wait([
      _firestore.collection('metadata').doc('options').get(),
      _firestore.collection('coaches').get(),
    ]).then((results) {
      final optionsDoc = results[0] as DocumentSnapshot;
      final coachesSnapshot = results[1] as QuerySnapshot;

      final optionsData = optionsDoc.data() as Map<String, dynamic>? ?? {};

      // 🔥 연령대 대폭 확장 (10대 미만 ~ 60대 이상)
      final fallbackAges = ['10대 미만', '10대', '20대', '30대', '40대', '50대', '60대 이상'];
      final ageGroups = List<String>.from(optionsData['ageGroups'] ?? fallbackAges);

      final jobs = List<String>.from(optionsData['jobs'] ?? []);
      if (!jobs.contains('기타')) jobs.add('기타');

      final jobIcons = optionsData['jobIcons'] != null
          ? Map<String, String>.from(optionsData['jobIcons'])
          : <String, String>{};

      final coaches = coachesSnapshot.docs.map((doc) => DBCoach.fromFirestore(doc)).toList();

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
    _nicknameCtrl.dispose();
    _salaryCtrl.dispose();
    _customJobCtrl.dispose();
    super.dispose();
  }

  // ─── 닉네임 중복 확인 로직 ───
  Future<void> _checkNicknameDuplicate() async {
    final nickname = _nicknameCtrl.text.trim();
    if (nickname.length < 2 || nickname.length > 10) {
      setState(() => _nicknameError = '닉네임은 2~10자로 입력해주세요');
      return;
    }

    setState(() {
      _isCheckingNickname = true;
      _nicknameError = null;
    });

    try {
      final taken = await _userService.isNicknameTaken(nickname).timeout(const Duration(seconds: 10));
      setState(() {
        if (taken) {
          _nicknameError = '이미 사용 중인 닉네임이에요';
          _isNicknameChecked = false;
        } else {
          _nicknameError = null;
          _isNicknameChecked = true;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('사용 가능한 닉네임입니다!'),
              backgroundColor: Color(0xFF03C75A), // 초록색 성공 메시지
              duration: Duration(seconds: 2),
            ),
          );
        }
      });
    } catch (e) {
      setState(() => _nicknameError = '확인 중 오류가 발생했어요. 다시 시도해주세요.');
    } finally {
      setState(() => _isCheckingNickname = false);
    }
  }

  Future<void> _submit() async {
    final nickname = _nicknameCtrl.text.trim();
    final salary = parseAmount(_salaryCtrl.text);
    final finalJob = _job == '기타' ? _customJobCtrl.text.trim() : (_job ?? '');

    setState(() => _saving = true);

    try {
      // (중복 확인은 이미 마쳤으므로 바로 DB 저장으로 넘어갑니다)
      await _userService.createUser(UserModel(
        userId: widget.uid,
        nickname: nickname,
        email: widget.email,
        salary: salary,
        ageGroup: _ageGroup,
        job: finalJob,
        coachTone: CoachTone.values.firstWhere((t) => t.name == _selectedCoachId, orElse: () => CoachTone.ddaengjwi),
      )).timeout(const Duration(seconds: 10));

      if (!mounted) return;

      await DdaengModal.alert(
        context,
        title: '$nickname님, 환영해요!',
        message: '$_selectedCoachName 코치가 함께할게요.\n이제 지출을 기록하고 잔소리를 들어보세요',
        type: ModalType.success,
        emoji: _selectedCoachEmoji,
        confirmText: '시작하기',
      );

      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }

    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      await DdaengModal.alert(
          context,
          title: '저장에 실패했어요',
          message: '네트워크 연결이 불안정합니다. 다시 시도해주세요.',
          type: ModalType.danger
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
              return const Center(child: CircularProgressIndicator(color: DdaengColors.blue));
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
                        // ─── 헤더 ───
                        Center(
                          child: Column(
                            children: [
                              Container(
                                width: 84,
                                height: 84,
                                decoration: const BoxDecoration(
                                  color: DdaengColors.blueSoft,
                                  shape: BoxShape.circle,
                                ),
                                alignment: Alignment.center,
                                child: Text(_selectedCoachEmoji,
                                    style: const TextStyle(fontSize: 40)),
                              ),
                              const SizedBox(height: 20),
                              Text(
                                _fromOnboarding ? '마지막으로\n닉네임만 정해주세요' : '반가워요!\n몇 가지만 알려주세요',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                  height: 1.4,
                                  letterSpacing: -0.6,
                                  color: DdaengColors.ink,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _fromOnboarding ? '$_selectedCoachName 코치가 이 이름으로 불러드릴게요' : '땡그랑이 확실하게 예산을 밀착 코칭해 드릴게요',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w500,
                                  color: DdaengColors.inkSub,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 36),

                        // ─── 닉네임 입력 & 중복 확인 ───
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const _FieldLabel('닉네임', required: true),
                            Text('$_nicknameLength/10',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: _nicknameLength > 10 ? const Color(0xFFF04438) : const Color(0xFFB0B8C1),
                                )),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _nicknameCtrl,
                                maxLength: 10,
                                autofocus: _fromOnboarding,
                                style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: DdaengColors.ink),
                                decoration: InputDecoration(
                                  hintText: '불릴 예쁜 이름을 적어주세요',
                                  hintStyle: const TextStyle(fontWeight: FontWeight.w500, color: Color(0xFFB0B8C1)),
                                  errorText: _nicknameError,
                                  counterText: '',
                                  filled: true,
                                  fillColor: DdaengColors.bg,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                                  // 🔥 중복확인 완료 시 초록색 체크마크 표시
                                  suffixIcon: _isNicknameChecked
                                      ? const Icon(Icons.check_circle_rounded, color: Color(0xFF03C75A), size: 22)
                                      : null,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: DdaengColors.blue, width: 1.8)),
                                  errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFF04438))),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              height: 52, // 텍스트필드와 높이 맞춤
                              child: ElevatedButton(
                                onPressed: (_isNicknameChecked || _nicknameLength < 2 || _nicknameLength > 10 || _isCheckingNickname)
                                    ? null
                                    : _checkNicknameDuplicate,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: DdaengColors.blueSoft,
                                  foregroundColor: DdaengColors.blueDeep,
                                  disabledBackgroundColor: const Color(0xFFF2F4F6),
                                  disabledForegroundColor: const Color(0xFFB0B8C1),
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                ),
                                child: _isCheckingNickname
                                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: DdaengColors.blueDeep))
                                    : Text(_isNicknameChecked ? '확인완료' : '중복확인', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                              ),
                            ),
                          ],
                        ),

                        // ─── 온보딩 요약 ───
                        if (_fromOnboarding) ...[
                          const SizedBox(height: 28),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                            decoration: BoxDecoration(
                              color: DdaengColors.bg,
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Column(
                              children: [
                                _SummaryRow('월 실수령액', '${comma(parseAmount(_salaryCtrl.text))}원'),
                                const Divider(height: 1, color: DdaengColors.line),
                                _SummaryRow('연령대', _ageGroup),
                                const Divider(height: 1, color: DdaengColors.line),
                                _SummaryRow('직군', '${jobIcons[_job] ?? '✨'} ${_job ?? ''}'),
                                const Divider(height: 1, color: DdaengColors.line),
                                _SummaryRow('선택한 코치', '$_selectedCoachEmoji $_selectedCoachName'),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          Center(
                            child: TextButton.icon(
                              onPressed: () {
                                setState(() {
                                  _forceFullForm = true;
                                });
                              },
                              icon: const Icon(Icons.tune_rounded, size: 16),
                              label: const Text('프로필 정보 다시 입력할래요'),
                              style: TextButton.styleFrom(
                                foregroundColor: DdaengColors.inkSub,
                                textStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                        ],

                        // ─── 전체 입력 폼 ───
                        if (!_fromOnboarding) ...[
                          const SizedBox(height: 32),
                          const _FieldLabel('월 실수령액', required: true),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _salaryCtrl,
                            keyboardType: TextInputType.number,
                            inputFormatters: [ThousandsFormatter()],
                            onChanged: (_) => setState(() {}),
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: DdaengColors.ink),
                            decoration: InputDecoration(
                              hintText: '2,800,000',
                              hintStyle: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFFB0B8C1)),
                              suffixText: '원',
                              suffixStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: DdaengColors.inkSub),
                              filled: true,
                              fillColor: DdaengColors.bg,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: DdaengColors.blue, width: 1.8)),
                            ),
                          ),
                          if (parseAmount(_salaryCtrl.text) > 0) ...[
                            const SizedBox(height: 8),
                            Padding(
                              padding: const EdgeInsets.only(left: 4),
                              child: Text(
                                koreanAmount(parseAmount(_salaryCtrl.text)),
                                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: DdaengColors.blue),
                              ),
                            ),
                          ],
                          const SizedBox(height: 30),

                          const _FieldLabel('연령대', required: true),
                          const SizedBox(height: 10),
                          _ChipGroup(
                            items: ageGroups,
                            selected: _ageGroup,
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
                                color: _job != null ? DdaengColors.blueSoft : DdaengColors.bg,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: _job != null ? DdaengColors.blue : Colors.transparent,
                                  width: 1.6,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 42,
                                    height: 42,
                                    decoration: BoxDecoration(
                                      color: _job != null ? Colors.white : const Color(0xFFE8EAED),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(_job != null ? (jobIcons[_job] ?? '✨') : '💭', style: const TextStyle(fontSize: 20)),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      _job ?? '직군을 선택해주세요',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: _job != null ? FontWeight.w800 : FontWeight.w600,
                                        color: _job != null ? DdaengColors.ink : const Color(0xFFB0B8C1),
                                      ),
                                    ),
                                  ),
                                  Icon(Icons.keyboard_arrow_down_rounded, color: _job != null ? DdaengColors.blue : DdaengColors.inkSub),
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
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                                decoration: InputDecoration(
                                  hintText: '직군을 직접 입력해주세요',
                                  hintStyle: const TextStyle(fontSize: 13.5, color: Color(0xFFB0B8C1)),
                                  filled: true,
                                  fillColor: DdaengColors.bg,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: DdaengColors.blue, width: 1.2)),
                                ),
                              ),
                            ),
                            crossFadeState: _job == '기타' ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                          ),
                          const SizedBox(height: 30),

                          const _FieldLabel('잔소리 코치 성향'),
                          const SizedBox(height: 4),
                          const Text('코치의 성향에 따라 잔소리 수위가 달라져요', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: DdaengColors.inkSub)),
                          const SizedBox(height: 14),
                          if (coaches.isEmpty)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 20),
                              child: Text('코치 정보를 불러올 수 없어요.\ncoaches 컬렉션을 확인해주세요.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12.5, color: Color(0xFFF04438))),
                            )
                          else
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
                      BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 16, offset: const Offset(0, -4)),
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
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: _saving
                          ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
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

  void _openJobPicker(BuildContext context, List<String> jobs, Map<String, String> jobIcons) {
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
      Text(text, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF4E5968))),
      if (required) const Text(' *', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFFF04438))),
    ],
  );
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  const _SummaryRow(this.label, this.value);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 13),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: DdaengColors.inkSub)),
        Text(value, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: DdaengColors.ink)),
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
      spacing: 9,
      runSpacing: 10,
      children: items.map((e) {
        final sel = e == selected;
        return GestureDetector(
          onTap: () => onSelect(e),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            decoration: BoxDecoration(
              color: sel ? DdaengColors.blueSoft : DdaengColors.bg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: sel ? DdaengColors.blue : Colors.transparent, width: 1.5),
            ),
            child: Text(e,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: sel ? FontWeight.w700 : FontWeight.w600,
                  color: sel ? DdaengColors.blueDeep : DdaengColors.inkSub,
                )),
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
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? DdaengColors.blueSoft : DdaengColors.bg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: selected ? DdaengColors.blue : Colors.transparent, width: 1.6),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(color: selected ? Colors.white : const Color(0xFFF2F4F6), shape: BoxShape.circle),
              alignment: Alignment.center,
              child: Text(coach.emoji, style: const TextStyle(fontSize: 26)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(coach.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: DdaengColors.ink)),
                      const SizedBox(width: 6),
                      Text(coach.title, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: DdaengColors.inkSub)),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(coach.desc, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: Color(0xFF4E5968))),
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

  const _JobPickerSheet({required this.jobs, required this.jobIcons, required this.selected, required this.onSelect});

  @override
  State<_JobPickerSheet> createState() => _JobPickerSheetState();
}

class _JobPickerSheetState extends State<_JobPickerSheet> {
  String _query = '';
  String _iconOf(String j) => widget.jobIcons[j] ?? '✨';

  @override
  Widget build(BuildContext context) {
    final filtered = widget.jobs.where((j) => j.toLowerCase().contains(_query.toLowerCase())).toList();

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
              Container(margin: const EdgeInsets.only(top: 12), width: 40, height: 5, decoration: BoxDecoration(color: DdaengColors.line, borderRadius: BorderRadius.circular(10))),
              const Padding(
                padding: EdgeInsets.fromLTRB(24, 18, 24, 0),
                child: Align(alignment: Alignment.centerLeft, child: Text('어떤 일을 하고 계신가요?', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: DdaengColors.ink))),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 14, 24, 6),
                child: TextField(
                  onChanged: (v) => setState(() => _query = v),
                  decoration: InputDecoration(
                    hintText: '직군 검색',
                    hintStyle: const TextStyle(color: Color(0xFFB0B8C1)),
                    prefixIcon: const Icon(Icons.search, color: DdaengColors.inkSub, size: 20),
                    filled: true,
                    fillColor: DdaengColors.bg,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                  ),
                ),
              ),
              Expanded(
                child: filtered.isEmpty
                    ? const Center(child: Text('검색 결과가 없어요', style: TextStyle(color: DdaengColors.inkSub, fontSize: 14)))
                    : GridView.builder(
                  controller: scrollCtrl,
                  physics: const ClampingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 2.5),
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
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: sel ? DdaengColors.blueSoft : DdaengColors.bg,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: sel ? DdaengColors.blue : Colors.transparent, width: 1.4),
                          ),
                          child: Row(
                            children: [
                              Text(_iconOf(job), style: const TextStyle(fontSize: 19)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(job, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, fontWeight: sel ? FontWeight.w700 : FontWeight.w600, color: sel ? DdaengColors.blueDeep : const Color(0xFF333D4B))),
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