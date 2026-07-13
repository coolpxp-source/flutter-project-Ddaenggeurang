import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/coach_tone.dart';
import '../auth/login_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageCtrl = PageController();
  int _step = 0;

  // 입력값 상태 관리
  final _salaryCtrl = TextEditingController();
  String? _ageGroup;
  String? _selectedJob;
  CoachTone _tone = CoachTone.ddaengjwi;

  static const _ages = ['10대', '20대', '30대', '40대', '50대 이상'];
  late Future<List<String>> _jobCategoriesFuture;

  int get _salary =>
      int.tryParse(_salaryCtrl.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;

  int get _recommendedBudget => (_salary * 0.7).round() ~/ 10000 * 10000;

  bool get _step2Valid => _salary >= 100000 && _ageGroup != null && _selectedJob != null;

  @override
  void initState() {
    super.initState();
    _jobCategoriesFuture = _fetchJobCategories();
  }

  Future<List<String>> _fetchJobCategories() async {
    final fallbackJobs = ['경영·관리', '기획·마케팅', '개발·엔지니어', '디자인', '서비스·영업', '학생', '기타'];
    try {
      final docSnapshot = await FirebaseFirestore.instance
          .collection('metadata')
          .doc('options')
          .get();

      if (docSnapshot.exists && docSnapshot.data() != null) {
        final data = docSnapshot.data()!;
        if (data['jobs'] != null) {
          final fetchedJobs = List<String>.from(data['jobs']);
          if (fetchedJobs.isNotEmpty) {
            return fetchedJobs;
          }
        }
      }
      return fallbackJobs;
    } catch (e) {
      debugPrint("🔥 Firebase 직군 불러오기 에러: $e");
      return fallbackJobs;
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
        duration: const Duration(milliseconds: 400),
        curve: Curves.fastOutSlowIn,
      );
    } else {
      _finish();
    }
  }

  void _back() => _pageCtrl.previousPage(
    duration: const Duration(milliseconds: 400),
    curve: Curves.fastOutSlowIn,
  );

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('seenOnboarding', true);

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => LoginScreen(
          onboardingData: _step2Valid
              ? OnboardingData(
            salary: _salary,
            ageGroup: _ageGroup!,
            job: _selectedJob!,
            tone: _tone,
            budget: _recommendedBudget,
          )
              : null,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _TopBar(
              step: _step,
              onBack: _step > 0 ? _back : null,
              onSkip: _step == 0 ? _finish : null,
            ),
            Expanded(
              child: PageView(
                controller: _pageCtrl,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (i) => setState(() => _step = i),
                children: [
                  _AnimatedPageTransition(
                    visible: _step == 0,
                    child: _IntroPage(),
                  ),
                  _AnimatedPageTransition(
                    visible: _step == 1,
                    child: FutureBuilder<List<String>>(
                      future: _jobCategoriesFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation(Color(0xFF3182F6)),
                            ),
                          );
                        }
                        final jobsData = snapshot.data ?? [];

                        return _InfoPage(
                          salaryCtrl: _salaryCtrl,
                          ageGroup: _ageGroup,
                          selectedJob: _selectedJob,
                          onAge: (v) => setState(() => _ageGroup = v),
                          onJob: (v) => setState(() => _selectedJob = v),
                          onChanged: () => setState(() {}),
                          ages: _ages,
                          jobs: jobsData,
                        );
                      },
                    ),
                  ),
                  _AnimatedPageTransition(
                    visible: _step == 2,
                    child: _ConfirmPage(
                      salary: _salary,
                      ageGroup: _ageGroup ?? '',
                      job: _selectedJob ?? '',
                      budget: _recommendedBudget,
                      tone: _tone,
                      onToneChange: (t) => setState(() => _tone = t),
                    ),
                  ),
                ],
              ),
            ),
            // 하단 플로팅 버튼 시트
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 20,
                    offset: const Offset(0, -4),
                  ),
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

// ════════════════════════ 애니메이션 컴포넌트 ════════════════════════

class _AnimatedPageTransition extends StatelessWidget {
  final Widget child;
  final bool visible;

  const _AnimatedPageTransition({required this.child, required this.visible});

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 400),
      opacity: visible ? 1.0 : 0.0,
      child: AnimatedSlide(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutCubic,
        offset: visible ? Offset.zero : const Offset(0, 0.05),
        child: child,
      ),
    );
  }
}

class _AnimatedCountText extends StatefulWidget {
  final int targetValue;
  final TextStyle style;

  const _AnimatedCountText({required this.targetValue, required this.style});

  @override
  State<_AnimatedCountText> createState() => _AnimatedCountTextState();
}

class _AnimatedCountTextState extends State<_AnimatedCountText>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0, end: widget.targetValue.toDouble())
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutExpo));
    _controller.forward();
  }

  @override
  void didUpdateWidget(_AnimatedCountText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.targetValue != widget.targetValue) {
      _animation = Tween<double>(
        begin: _animation.value,
        end: widget.targetValue.toDouble(),
      ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutExpo));
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _won(int n) => n.toString().replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+$)'),
        (m) => '${m[1]},',
  );

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Text(
          '${_won(_animation.value.round())}원',
          style: widget.style,
        );
      },
    );
  }
}

class _AnimatedCheckMark extends StatefulWidget {
  const _AnimatedCheckMark();

  @override
  State<_AnimatedCheckMark> createState() => _AnimatedCheckMarkState();
}

class _AnimatedCheckMarkState extends State<_AnimatedCheckMark>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.15), weight: 70),
      TweenSequenceItem(tween: Tween(begin: 1.15, end: 1.0), weight: 30),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOutCubic));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: Container(
        width: 64,
        height: 64,
        decoration: const BoxDecoration(
          color: Color(0xFFE8F3FF),
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: const Icon(Icons.check_rounded, size: 34, color: Color(0xFF3182F6)),
      ),
    );
  }
}

// ════════════════════════ 상단바 ════════════════════════

class _TopBar extends StatelessWidget {
  final int step;
  final VoidCallback? onBack;
  final VoidCallback? onSkip;

  const _TopBar({required this.step, this.onBack, this.onSkip});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 20, 8),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            child: onBack != null
                ? IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
              color: const Color(0xFF4E5968),
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
                  backgroundColor: const Color(0xFFF2F4F6),
                  valueColor: const AlwaysStoppedAnimation(Color(0xFF3182F6)),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Text(
            '${step + 1} / 3',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF8B95A1),
            ),
          ),
          if (onSkip != null) ...[
            const SizedBox(width: 16),
            GestureDetector(
              onTap: onSkip,
              child: const Text(
                '건너뛰기',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF8B95A1),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ════════════════════════ 1단계: 소개 ════════════════════════

class _IntroPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFFC93C).withOpacity(0.2),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                )
              ],
            ),
            alignment: Alignment.center,
            child: const Text('🐷', style: TextStyle(fontSize: 44)),
          ),
          const SizedBox(height: 28),
          const Text(
            '잔소리 좀 하는\nAI 소비 코치, 땡그랑',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              height: 1.35,
              letterSpacing: -0.6,
              color: Color(0xFF191F28),
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            '지출을 기록하면 AI가 잔소리하고,\n또래와 비교해서 알려드려요.',
            style: TextStyle(
              fontSize: 15,
              height: 1.6,
              fontWeight: FontWeight.w500,
              color: Color(0xFF4E5968),
            ),
          ),
          const SizedBox(height: 48),
          const _FeatureTile(
            emoji: '🔔',
            bg: Color(0xFFFFF0F3),
            title: '오늘의 잔소리',
            desc: '과소비하면 바로 알려드려요',
          ),
          const _FeatureTile(
            emoji: '📊',
            bg: Color(0xFFEEF4FF),
            title: '또래 비교 통계',
            desc: '나만 이렇게 쓰는 건지 확인해요',
          ),
          const _FeatureTile(
            emoji: '🎯',
            bg: Color(0xFFE9F7F0),
            title: 'AI 맞춤 예산 추천',
            desc: '급여 기반으로 딱 맞게 짜드려요',
          ),
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

  const _FeatureTile({
    required this.emoji,
    required this.bg,
    required this.title,
    required this.desc,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Text(emoji, style: const TextStyle(fontSize: 22)),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF191F28),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                desc,
                style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500, color: Color(0xFF8B95A1)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ════════════════════════ 2단계: 정보 입력 ════════════════════════

class _InfoPage extends StatelessWidget {
  final TextEditingController salaryCtrl;
  final String? ageGroup;
  final String? selectedJob;
  final ValueChanged<String> onAge;
  final ValueChanged<String> onJob;
  final VoidCallback onChanged;
  final List<String> ages;
  final List<String> jobs;

  const _InfoPage({
    required this.salaryCtrl,
    required this.ageGroup,
    required this.selectedJob,
    required this.onAge,
    required this.onJob,
    required this.onChanged,
    required this.ages,
    required this.jobs,
  });

  // 🌟 바텀 시트 호출 함수 🌟
  void _showJobBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // 리스트가 길면 화면의 70%까지 올라오도록 설정
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // 바텀 시트 상단 손잡이(핸들)
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 20),
              width: 40,
              height: 5,
              decoration: BoxDecoration(
                color: const Color(0xFFE5E8EB),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const Text(
              '어떤 일을 하고 계신가요?',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Color(0xFF191F28),
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 16),
            // 직군 리스트 렌더링
            Expanded(
              child: ListView.builder(
                physics: const BouncingScrollPhysics(),
                itemCount: jobs.length,
                itemBuilder: (context, index) {
                  final job = jobs[index];
                  final isSelected = job == selectedJob;

                  return InkWell(
                    onTap: () {
                      onJob(job); // 직군 선택 업데이트
                      Navigator.pop(context); // 시트 자동으로 닫기
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                      color: isSelected ? const Color(0xFFF2F8FF) : Colors.white,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            job,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                              color: isSelected ? const Color(0xFF3182F6) : const Color(0xFF333D4B),
                            ),
                          ),
                          if (isSelected)
                            const Icon(Icons.check_circle_rounded, color: Color(0xFF3182F6), size: 22),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '거의 다 왔어요!\n딱 3가지만 알려주세요',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              height: 1.4,
              letterSpacing: -0.6,
              color: Color(0xFF191F28),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            '입력하신 정보는 예산 추천과 또래 비교에만 쓰여요.',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF8B95A1)),
          ),
          const SizedBox(height: 48),

          const _QuestionTitle(step: '1', title: '한 달에 얼마를 벌고 계신가요?'),
          const SizedBox(height: 16),
          TextField(
            controller: salaryCtrl,
            keyboardType: TextInputType.number,
            onChanged: (_) => onChanged(),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF191F28),
            ),
            decoration: InputDecoration(
              hintText: '예: 2,800,000',
              hintStyle: const TextStyle(color: Color(0xFFB0B8C1), fontWeight: FontWeight.w600),
              suffixText: '원',
              suffixStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF4E5968)),
              filled: true,
              fillColor: const Color(0xFFF2F4F6),
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Color(0xFF3182F6), width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 48),

          const _QuestionTitle(step: '2', title: '연령대가 어떻게 되시나요?'),
          const SizedBox(height: 16),
          _TossStyleChipGroup(items: ages, selected: ageGroup, onSelect: onAge),
          const SizedBox(height: 48),

          const _QuestionTitle(step: '3', title: '어떤 일을 하고 계신가요?'),
          const SizedBox(height: 16),

          // 🌟 어수선한 칩 그룹 대신, 클릭 시 바텀 시트를 띄우는 세련된 셀렉터 버튼 🌟
          GestureDetector(
            onTap: () => _showJobBottomSheet(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              decoration: BoxDecoration(
                color: const Color(0xFFF2F4F6),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: selectedJob != null ? const Color(0xFF3182F6) : Colors.transparent,
                  width: 1.5,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    selectedJob ?? '직군을 선택해주세요',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: selectedJob != null ? FontWeight.w700 : FontWeight.w600,
                      color: selectedJob != null ? const Color(0xFF191F28) : const Color(0xFFB0B8C1),
                    ),
                  ),
                  const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF8B95A1)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuestionTitle extends StatelessWidget {
  final String step;
  final String title;
  const _QuestionTitle({required this.step, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: const BoxDecoration(
            color: Color(0xFFE8F3FF),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            step,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF3182F6)),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF191F28), letterSpacing: -0.4),
        ),
      ],
    );
  }
}

class _TossStyleChipGroup extends StatelessWidget {
  final List<String> items;
  final String? selected;
  final ValueChanged<String> onSelect;

  const _TossStyleChipGroup({required this.items, required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 12,
      children: items.map((e) {
        final isSelected = e == selected;
        return GestureDetector(
          onTap: () => onSelect(e),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeInOut,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFFE8F3FF) : const Color(0xFFF2F4F6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              e,
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                color: isSelected ? const Color(0xFF1B64DA) : const Color(0xFF4E5968),
                letterSpacing: -0.3,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ════════════════════════ 3단계: 확인 + 코치 선택 ════════════════════════

class _ConfirmPage extends StatelessWidget {
  final int salary;
  final String ageGroup;
  final String job;
  final int budget;
  final CoachTone tone;
  final ValueChanged<CoachTone> onToneChange;

  const _ConfirmPage({
    required this.salary,
    required this.ageGroup,
    required this.job,
    required this.budget,
    required this.tone,
    required this.onToneChange,
  });

  String _won(int n) => n.toString().replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+$)'),
        (m) => '${m[1]},',
  );

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 30, 24, 40),
      child: Column(
        children: [
          const _AnimatedCheckMark(),
          const SizedBox(height: 20),
          const Text(
            '프로필 완성!',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.6, color: Color(0xFF191F28)),
          ),
          const SizedBox(height: 8),
          const Text(
            '입력하신 정보로 예산을 짜봤어요',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Color(0xFF8B95A1)),
          ),
          const SizedBox(height: 32),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                _SummaryRow('월 실수령액', '${_won(salary)}원'),
                const Divider(height: 1, color: Color(0xFFF2F4F6)),
                _SummaryRow('연령대', ageGroup),
                const Divider(height: 1, color: Color(0xFFF2F4F6)),
                _SummaryRow('직군', job),
              ],
            ),
          ),
          const SizedBox(height: 16),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF3182F6),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF3182F6).withOpacity(0.25),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.auto_awesome, size: 18, color: Color(0xFFFFC93C)),
                    const SizedBox(width: 6),
                    Text(
                      'AI 추천 이번 달 예산',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white.withOpacity(0.9)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _AnimatedCountText(
                  targetValue: budget,
                  style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w900, letterSpacing: -1, color: Colors.white),
                ),
                const SizedBox(height: 8),
                Text(
                  '수입의 70% 기준이에요. 나머지 30%는 저축!',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.white.withOpacity(0.85)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 48),

          Align(
            alignment: Alignment.centerLeft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '어떤 잔소리 코치를 원하시나요?',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF191F28), letterSpacing: -0.4),
                ),
                const SizedBox(height: 6),
                const Text(
                  '앱 설정에서 언제든 바꿀 수 있어요',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF8B95A1)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          Column(
            children: CoachTone.values.map((t) {
              final sel = t == tone;
              return GestureDetector(
                onTap: () => onToneChange(t),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: sel ? const Color(0xFFE8F3FF) : const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: sel ? Colors.white : const Color(0xFFF2F4F6),
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(t.emoji, style: const TextStyle(fontSize: 28)),
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
                                Text(t.label, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF191F28))),
                                const SizedBox(width: 8),
                                Text(t.title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF8B95A1))),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(t.desc, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF4E5968))),
                          ],
                        ),
                      ),
                      Icon(
                        sel ? Icons.check_circle_rounded : Icons.circle_outlined,
                        color: sel ? const Color(0xFF3182F6) : const Color(0xFFD1D6DB),
                        size: 26,
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
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
    padding: const EdgeInsets.symmetric(vertical: 14),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF8B95A1))),
        Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF191F28))),
      ],
    ),
  );
}

// ════════════════════════ 하단 버튼 ════════════════════════

class _BottomButton extends StatelessWidget {
  final String label;
  final bool enabled;
  final VoidCallback onTap;

  const _BottomButton({
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: enabled ? onTap : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF3182F6),
          disabledBackgroundColor: const Color(0xFFE5E8EB),
          foregroundColor: Colors.white,
          disabledForegroundColor: const Color(0xFFB0B8C1),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          transitionBuilder: (Widget child, Animation<double> animation) {
            return FadeTransition(opacity: animation, child: child);
          },
          child: Text(
            label,
            key: ValueKey<String>(label),
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, letterSpacing: -0.3),
          ),
        ),
      ),
    );
  }
}