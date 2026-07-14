import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/coach_tone.dart';
import '../../utils/formatters.dart';
import '../auth/login_screen.dart';
// 기존 import 문들 아래에 추가
import '../auth/email_signup_screen.dart'; // EmailSignUpScreen 파일 경로에 맞게 수정 필요

// ══════════════════════ 브랜드 색상 ══════════════════════
class DdaengColors {
  static const navy = Color(0xFF0D2247);
  static const blue = Color(0xFF2F6BFF);
  static const blueDeep = Color(0xFF1D4ED8);
  static const blueSoft = Color(0xFFEEF4FF);
  static const gold = Color(0xFFFFC93C);
  static const ink = Color(0xFF191F28);
  static const inkSub = Color(0xFF8B95A1);
  static const line = Color(0xFFEEEEF3);
  static const bg = Color(0xFFF7F8FA);
}

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageCtrl = PageController();
  int _step = 0;

  final _salaryCtrl = TextEditingController();
  String? _ageGroup;
  String? _selectedJob;
  CoachTone _tone = CoachTone.ddaengjwi;

  late Future<Map<String, dynamic>> _metaFuture;

  int get _salary => parseAmount(_salaryCtrl.text);
  int get _recommendedBudget => (_salary * 0.7).round() ~/ 10000 * 10000;
  bool get _step2Valid =>
      _salary >= 100000 && _ageGroup != null && _selectedJob != null;

  @override
  void initState() {
    super.initState();
    _metaFuture = _fetchMeta();
    _salaryCtrl.addListener(() => setState(() {}));
  }

  Future<Map<String, dynamic>> _fetchMeta() async {
    // 🔥 연령대를 세분화하고 10대 미만을 제외했습니다
    const fallbackAges = [
      '10대',
      '20대 초반',
      '20대 후반',
      '30대 초반',
      '30대 후반',
      '40대',
      '50대',
      '60대 이상'
    ];

    const fallbackJobs = ['개발·데이터 엔지니어', '기획·전략·마케팅', '학생', '기타'];
    const fallbackIcons = {'기타': '✨'};

    try {
      final doc = await FirebaseFirestore.instance
          .collection('metadata')
          .doc('options')
          .get();
      final data = doc.data() ?? {};

      final ageGroups = data['ageGroups'] != null
          ? List<String>.from(data['ageGroups'])
          : fallbackAges;

      return {
        'ages': ageGroups,
        'jobs': data['jobs'] != null ? List<String>.from(data['jobs']) : fallbackJobs,
        'jobIcons': data['jobIcons'] != null
            ? Map<String, String>.from(data['jobIcons'])
            : fallbackIcons,
      };
    } catch (e) {
      debugPrint('🔥 메타데이터 로드 실패: $e');
      return {'ages': fallbackAges, 'jobs': fallbackJobs, 'jobIcons': fallbackIcons};
    }
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _salaryCtrl.dispose();
    super.dispose();
  }

  void _next() {
    if (_step < 2) {
      _pageCtrl.nextPage(
          duration: const Duration(milliseconds: 380),
          curve: Curves.easeOutCubic);
    } else {
      _finish();
    }
  }

  void _back() => _pageCtrl.previousPage(
      duration: const Duration(milliseconds: 380), curve: Curves.easeOutCubic);

  // OnboardingScreen.dart의 _finish() 메서드 수정
  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('seenOnboarding', true);
    if (!mounted) return;

    final data = OnboardingData(
      salary: _salary,
      ageGroup: _ageGroup!,
      job: _selectedJob!,
      tone: _tone,
      budget: _recommendedBudget,
    );


    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => EmailSignUpScreen(onboardingData: data as OnboardingData),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: FutureBuilder<Map<String, dynamic>>(
          future: _metaFuture,
          builder: (context, snap) {
            final ages = (snap.data?['ages'] as List<String>?) ?? const [];
            final jobs = (snap.data?['jobs'] as List<String>?) ?? const [];
            final jobIcons =
                (snap.data?['jobIcons'] as Map<String, String>?) ?? const {};
            final loading = snap.connectionState == ConnectionState.waiting;

            return Column(
              children: [
                _TopBar(
                  step: _step,
                  onBack: _step > 0 ? _back : null,
                  onSkip: _step == 0 ? _finish : null,
                ),
                Expanded(
                  child: loading
                      ? const Center(
                      child: CircularProgressIndicator(
                          color: DdaengColors.blue))
                      : PageView(
                    controller: _pageCtrl,
                    physics: const NeverScrollableScrollPhysics(),
                    onPageChanged: (i) => setState(() => _step = i),
                    children: [
                      const _IntroPage(),
                      _InfoPage(
                        salaryCtrl: _salaryCtrl,
                        ageGroup: _ageGroup,
                        selectedJob: _selectedJob,
                        ages: ages,
                        jobs: jobs,
                        jobIcons: jobIcons,
                        onAge: (v) => setState(() => _ageGroup = v),
                        onJob: (v) => setState(() => _selectedJob = v),
                      ),
                      _ConfirmPage(
                        salary: _salary,
                        ageGroup: _ageGroup ?? '',
                        job: _selectedJob ?? '',
                        jobIcon: jobIcons[_selectedJob] ?? '✨',
                        budget: _recommendedBudget,
                        tone: _tone,
                        onToneChange: (t) => setState(() => _tone = t),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 16,
                          offset: const Offset(0, -4)),
                    ],
                  ),
                  child: _BottomButton(
                    label: switch (_step) {
                      0 => '시작하기',
                      1 => '다음',
                      _ => '땡그랑 시작하기',
                    },
                    enabled: _step == 1 ? _step2Valid : true,
                    onTap: _next,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class OnboardingData {
  final int salary;
  final String ageGroup;
  final String job;
  final CoachTone tone;
  final int budget;
  OnboardingData({
    required this.salary,
    required this.ageGroup,
    required this.job,
    required this.tone,
    required this.budget,
  });
}

// ══════════════════════ 상단바 ══════════════════════

class _TopBar extends StatelessWidget {
  final int step;
  final VoidCallback? onBack;
  final VoidCallback? onSkip;
  const _TopBar({required this.step, this.onBack, this.onSkip});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 20, 10),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: onBack != null
                ? IconButton(
              padding: EdgeInsets.zero,
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
              color: DdaengColors.inkSub,
              onPressed: onBack,
            )
                : null,
          ),
          Expanded(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: (step + 1) / 3),
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) => ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: value,
                  minHeight: 6,
                  backgroundColor: DdaengColors.line,
                  valueColor:
                  const AlwaysStoppedAnimation(DdaengColors.blue),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text('${step + 1}/3',
              style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: DdaengColors.inkSub)),
          if (onSkip != null) ...[
            const SizedBox(width: 14),
            GestureDetector(
              onTap: onSkip,
              child: const Text('건너뛰기',
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: DdaengColors.inkSub)),
            ),
          ],
        ],
      ),
    );
  }
}

// ══════════════════════ 1단계: 소개 ══════════════════════

class _IntroPage extends StatelessWidget {
  const _IntroPage();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 210,
              height: 210,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    DdaengColors.blueSoft,
                    DdaengColors.blueSoft.withOpacity(0),
                  ],
                ),
              ),
              alignment: Alignment.center,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: DdaengColors.gold.withOpacity(0.28),
                      blurRadius: 30,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: ClipOval(
                  child: Image.asset(
                    'assets/images/logo.png',
                    width: 72,
                    height: 72,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: RichText(
              textAlign: TextAlign.center,
              text: const TextSpan(
                style: TextStyle(
                  fontSize: 27,
                  fontWeight: FontWeight.w800,
                  height: 1.4,
                  letterSpacing: -0.7,
                  color: DdaengColors.ink,
                ),
                children: [
                  TextSpan(text: '잔소리 좀 하는\nAI 소비 코치, 땡그'),
                  TextSpan(text: '랑', style: TextStyle(color: DdaengColors.gold)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            '지출을 기록하면 AI가 잔소리하고,\n또래와 비교해서 알려드려요',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14.5,
              height: 1.65,
              fontWeight: FontWeight.w500,
              color: DdaengColors.inkSub,
            ),
          ),
          const SizedBox(height: 40),
          const _FeatureTile(
              emoji: '🔔',
              bg: Color(0xFFFFF0F3),
              title: '오늘의 잔소리',
              desc: '과소비하면 바로 알려드려요'),
          const _FeatureTile(
              emoji: '📊',
              bg: DdaengColors.blueSoft,
              title: '또래 비교 통계',
              desc: '나만 이렇게 쓰는 건지 확인해요'),
          const _FeatureTile(
              emoji: '🎯',
              bg: Color(0xFFE9F7F0),
              title: 'AI 맞춤 예산 추천',
              desc: '급여 기반으로 딱 맞게 짜드려요'),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _FeatureTile extends StatelessWidget {
  final String emoji;
  final Color bg;
  final String title;
  final String desc;
  const _FeatureTile(
      {required this.emoji,
        required this.bg,
        required this.title,
        required this.desc});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: DdaengColors.bg,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Text(emoji, style: const TextStyle(fontSize: 21)),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w700,
                      color: DdaengColors.ink)),
              const SizedBox(height: 3),
              Text(desc,
                  style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: DdaengColors.inkSub)),
            ],
          ),
        ],
      ),
    );
  }
}

// ══════════════════════ 2단계: 정보 입력 ══════════════════════

class _InfoPage extends StatelessWidget {
  final TextEditingController salaryCtrl;
  final String? ageGroup;
  final String? selectedJob;
  final List<String> ages;
  final List<String> jobs;
  final Map<String, String> jobIcons;
  final ValueChanged<String> onAge;
  final ValueChanged<String> onJob;

  const _InfoPage({
    required this.salaryCtrl,
    required this.ageGroup,
    required this.selectedJob,
    required this.ages,
    required this.jobs,
    required this.jobIcons,
    required this.onAge,
    required this.onJob,
  });

  String _iconOf(String j) => jobIcons[j] ?? '✨';

  void _openAgePicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AgePickerSheet(ages: ages, selected: ageGroup, onSelect: onAge),
    );
  }

  void _openJobPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _JobPickerSheet(
        jobs: jobs,
        jobIcons: jobIcons,
        selected: selectedJob,
        onSelect: onJob,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final amount = parseAmount(salaryCtrl.text);
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('거의 다 왔어요!\n딱 3가지만 알려주세요',
              style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800, height: 1.4, letterSpacing: -0.6, color: DdaengColors.ink)),
          const SizedBox(height: 10),
          const Text('입력하신 정보는 예산 추천과 또래 비교에만 쓰여요',
              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500, color: DdaengColors.inkSub)),
          const SizedBox(height: 38),

          const _QLabel(step: '1', title: '한 달에 얼마를 벌고 계신가요?'),
          const SizedBox(height: 14),
          TextField(
            controller: salaryCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: [ThousandsFormatter()],
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: DdaengColors.ink),
            decoration: InputDecoration(
              hintText: '2,800,000',
              hintStyle: const TextStyle(color: Color(0xFFB0B8C1), fontWeight: FontWeight.w700),
              suffixText: '원',
              suffixStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: DdaengColors.inkSub),
              filled: true,
              fillColor: DdaengColors.bg,
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: DdaengColors.blue, width: 1.6)),
            ),
          ),
          if (amount > 0) ...[
            const SizedBox(height: 8),
            Padding(padding: const EdgeInsets.only(left: 4), child: Text(koreanAmount(amount), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: DdaengColors.blue))),
          ],
          const SizedBox(height: 38),

          // 연령대 선택 (직군과 동일한 디자인 적용)
          const _QLabel(step: '2', title: '연령대가 어떻게 되시나요?'),
          const SizedBox(height: 14),
          _SelectBox(
            hint: '연령대를 선택해주세요',
            icon: '🎂',
            value: ageGroup,
            onTap: () => _openAgePicker(context),
          ),
          const SizedBox(height: 38),

          // 직군 선택
          const _QLabel(step: '3', title: '어떤 일을 하고 계신가요?'),
          const SizedBox(height: 14),
          _SelectBox(
            hint: '직군을 선택해주세요',
            icon: selectedJob != null ? _iconOf(selectedJob!) : '💭',
            value: selectedJob,
            onTap: () => _openJobPicker(context),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════ 공통 선택 박스 위젯 ══════════════════════
class _SelectBox extends StatelessWidget {
  final String hint, icon;
  final String? value;
  final VoidCallback onTap;

  const _SelectBox({required this.hint, required this.icon, required this.value, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: value != null ? DdaengColors.blueSoft : DdaengColors.bg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: value != null ? DdaengColors.blue : Colors.transparent, width: 1.6),
        ),
        child: Row(
          children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(color: value != null ? Colors.white : const Color(0xFFE8EAED), borderRadius: BorderRadius.circular(12)),
              alignment: Alignment.center,
              child: Text(icon, style: const TextStyle(fontSize: 22)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                value ?? hint,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: value != null ? FontWeight.w800 : FontWeight.w600,
                  color: value != null ? DdaengColors.ink : const Color(0xFFB0B8C1),
                ),
              ),
            ),
            const Icon(Icons.keyboard_arrow_down_rounded, color: DdaengColors.inkSub),
          ],
        ),
      ),
    );
  }
}


class _QLabel extends StatelessWidget {
  final String step;
  final String title;
  const _QLabel({required this.step, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration:
          const BoxDecoration(color: DdaengColors.blueSoft, shape: BoxShape.circle),
          alignment: Alignment.center,
          child: Text(step,
              style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: DdaengColors.blue)),
        ),
        const SizedBox(width: 10),
        Text(title,
            style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: DdaengColors.ink,
                letterSpacing: -0.4)),
      ],
    );
  }
}

class _ChipGroup extends StatelessWidget {
  final List<String> items;
  final String? selected;
  final ValueChanged<String> onSelect;
  const _ChipGroup(
      {required this.items, required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true, // 리스트 크기만큼만 공간 차지
      physics: const NeverScrollableScrollPhysics(), // 스크롤 방지
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2, // 2열 정렬
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 3.2, // 가로/세로 비율 (원하는 만큼 조절 가능)
      ),
      itemCount: items.length,
      itemBuilder: (context, i) {
        final e = items[i];
        final sel = e == selected;
        return GestureDetector(
          onTap: () => onSelect(e),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: sel ? DdaengColors.blueSoft : DdaengColors.bg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: sel ? DdaengColors.blue : Colors.transparent,
                width: 1.4,
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              e,
              style: TextStyle(
                fontSize: 14,
                fontWeight: sel ? FontWeight.w700 : FontWeight.w600,
                color: sel ? DdaengColors.blueDeep : const Color(0xFF333D4B),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ══════════════════════ 직군 선택 바텀시트 ══════════════════════

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
                          color: DdaengColors.ink,
                          letterSpacing: -0.4)),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 14, 24, 6),
                child: TextField(
                  autofocus: false,
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
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none),
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
                        onTap: () {
                          widget.onSelect(job);
                          Navigator.pop(context); // 선택 시 바텀시트 닫기 추가
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 140),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
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
// ══════════════════════ 연령대 바텀시트 ══════════════════════
class _AgePickerSheet extends StatelessWidget {
  final List<String> ages;
  final String? selected;
  final ValueChanged<String> onSelect;

  const _AgePickerSheet({
    required this.ages,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))
      ),
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 30),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
              width: 40, height: 5,
              decoration: BoxDecoration(color: DdaengColors.line, borderRadius: BorderRadius.circular(10))
          ),
          const SizedBox(height: 20),
          const Align(
              alignment: Alignment.centerLeft,
              child: Text('연령대를 선택해주세요', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800))
          ),
          const SizedBox(height: 10),
          ...ages.map((age) => ListTile(
            onTap: () {
              onSelect(age);
              Navigator.pop(context);
            },
            title: Text(
                age,
                style: TextStyle(
                    fontWeight: age == selected ? FontWeight.w800 : FontWeight.w600,
                    color: age == selected ? DdaengColors.blue : DdaengColors.ink
                )
            ),
            trailing: age == selected ? const Icon(Icons.check_circle_rounded, color: DdaengColors.blue) : null,
          )),
        ],
      ),
    );
  }
}

// ══════════════════════ 3단계: 확인 + 코치 선택 ══════════════════════

class _ConfirmPage extends StatelessWidget {
  final int salary;
  final String ageGroup;
  final String job;
  final String jobIcon;
  final int budget;
  final CoachTone tone;
  final ValueChanged<CoachTone> onToneChange;

  const _ConfirmPage({
    required this.salary,
    required this.ageGroup,
    required this.job,
    required this.jobIcon,
    required this.budget,
    required this.tone,
    required this.onToneChange,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 26, 24, 40),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration:
            const BoxDecoration(color: DdaengColors.blueSoft, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: const Icon(Icons.check_rounded, size: 34, color: DdaengColors.blue),
          ),
          const SizedBox(height: 18),
          const Text('프로필 완성!',
              style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.6,
                  color: DdaengColors.ink)),
          const SizedBox(height: 8),
          const Text('입력하신 정보로 예산을 짜봤어요',
              style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                  color: DdaengColors.inkSub)),
          const SizedBox(height: 28),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            decoration:
            BoxDecoration(color: DdaengColors.bg, borderRadius: BorderRadius.circular(18)),
            child: Column(
              children: [
                _SummaryRow('월 실수령액', '${comma(salary)}원'),
                const Divider(height: 1, color: DdaengColors.line),
                _SummaryRow('연령대', ageGroup),
                const Divider(height: 1, color: DdaengColors.line),
                _SummaryRow('직군', '$jobIcon $job'),
              ],
            ),
          ),
          const SizedBox(height: 16),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [DdaengColors.blue, DdaengColors.blueDeep],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                    color: DdaengColors.blue.withOpacity(0.25),
                    blurRadius: 22,
                    offset: const Offset(0, 10)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Icon(Icons.auto_awesome, size: 16, color: DdaengColors.gold),
                  const SizedBox(width: 6),
                  Text('AI 추천 이번 달 예산',
                      style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: Colors.white.withOpacity(0.85))),
                ]),
                const SizedBox(height: 10),
                Text('${comma(budget)}원',
                    style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1,
                        color: Colors.white)),
                const SizedBox(height: 6),
                Text('수입의 70% 기준이에요. 나머지 30%는 저축!',
                    style: TextStyle(
                        fontSize: 12.5, color: Colors.white.withOpacity(0.78))),
              ],
            ),
          ),
          const SizedBox(height: 32),

          Align(
            alignment: Alignment.centerLeft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('어떤 잔소리 코치를 원하시나요?',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: DdaengColors.ink,
                        letterSpacing: -0.4)),
                const SizedBox(height: 4),
                const Text('앱 설정에서 언제든 바꿀 수 있어요',
                    style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        color: DdaengColors.inkSub)),
              ],
            ),
          ),
          const SizedBox(height: 16),

          ...CoachTone.values.map((t) {
            final sel = t == tone;
            return GestureDetector(
              onTap: () => onToneChange(t),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: sel ? DdaengColors.blueSoft : DdaengColors.bg,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                      color: sel ? DdaengColors.blue : Colors.transparent,
                      width: 1.6),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: sel ? Colors.white : const Color(0xFFF2F4F6),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(t.emoji, style: const TextStyle(fontSize: 26)),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Text(t.label,
                                style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: DdaengColors.ink)),
                            const SizedBox(width: 6),
                            Text(t.title,
                                style: const TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: DdaengColors.inkSub)),
                          ]),
                          const SizedBox(height: 3),
                          Text(t.desc,
                              style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF4E5968))),
                        ],
                      ),
                    ),
                    Icon(
                      sel ? Icons.check_circle_rounded : Icons.circle_outlined,
                      color: sel ? DdaengColors.blue : const Color(0xFFD1D6DB),
                      size: 24,
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
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
        Text(label,
            style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: DdaengColors.inkSub)),
        Text(value,
            style: const TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w800,
                color: DdaengColors.ink)),
      ],
    ),
  );
}

// ══════════════════════ 하단 버튼 ══════════════════════

class _BottomButton extends StatelessWidget {
  final String label;
  final bool enabled;
  final VoidCallback onTap;
  const _BottomButton(
      {required this.label, required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: enabled ? onTap : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: DdaengColors.navy,
          disabledBackgroundColor: const Color(0xFFE5E8EB),
          foregroundColor: Colors.white,
          disabledForegroundColor: const Color(0xFFB0B8C1),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          transitionBuilder: (child, anim) => FadeTransition(opacity: anim, child: child),
          child: Text(label,
              key: ValueKey(label),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        ),
      ),
    );
  }
}