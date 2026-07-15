import 'package:flutter/material.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/user_model.dart';
import '../../services/user_service.dart';
import '../../utils/formatters.dart';
import '../../widgets/common/ddaeng_modal.dart';

const _accent = Color(0xFFF5A623);
const _accentSoft = Color(0xFFFFF0A6);
const _ink = Color(0xFF221A16);
const _inkSub = Color(0xFF8A7E77);
const _bg = Color(0xFFFAF8F6);
const _line = Color(0xFFF0E9E4);
const _errorColor = Color(0xFFF04438);
const _okColor = Color(0xFF12B76A);

class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  final _userService = UserService();
  final _nicknameCtrl = TextEditingController();
  final _salaryCtrl = TextEditingController();

  UserModel? _user;
  String? _originalNickname;
  String _ageGroup = '';
  String? _job;
  List<String> _ageGroups = ['10대', '20대', '30대', '40대', '50대', '60대 이상'];
  List<String> _jobs = [];
  Map<String, String> _jobIcons = {};

  bool _loading = true;
  bool _saving = false;
  bool? _nicknameAvailable; // null = 원래값과 동일 혹은 미확인
  bool _checkingNickname = false;
  Timer? _debounce;

  String get _uid => FirebaseAuth.instance.currentUser!.uid;
  int get _nicknameLength => _nicknameCtrl.text.trim().length;

  bool get _canSave =>
      !_saving &&
      _nicknameLength >= 2 &&
      _nicknameLength <= 10 &&
      _nicknameAvailable != false &&
      _ageGroup.isNotEmpty &&
      _job != null;

  @override
  void initState() {
    super.initState();
    _load();
    _nicknameCtrl.addListener(_onNicknameChanged);
    _salaryCtrl.addListener(() => setState(() {}));
  }

  Future<void> _load() async {
    final user = await _userService.getUser(_uid);
    final optionsDoc =
    await FirebaseFirestore.instance.collection('metadata').doc('options').get();
    final options = optionsDoc.data();
    if (options != null) {
      if (options['ageGroups'] != null) {
        _ageGroups = List<String>.from(options['ageGroups']);
      }
      if (options['jobs'] != null) {
        _jobs = List<String>.from(options['jobs']);
        if (!_jobs.contains('기타')) _jobs.add('기타');
      }
      if (options['jobIcons'] != null) {
        _jobIcons = Map<String, String>.from(options['jobIcons']);
      }
    }
    if (user != null) {
      _user = user;
      _originalNickname = user.nickname;
      _nicknameCtrl.text = user.nickname;
      _salaryCtrl.text = comma(user.salary);
      _ageGroup = user.ageGroup;
      _job = user.job.isEmpty ? null : user.job;
    }
    if (mounted) setState(() => _loading = false);
  }

  void _onNicknameChanged() {
    final text = _nicknameCtrl.text.trim();
    _debounce?.cancel();
    setState(() => _nicknameAvailable = null);
    if (text == _originalNickname) return; // 원래 닉네임이면 검사 불필요
    if (text.length < 2 || text.length > 10) return;
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      setState(() => _checkingNickname = true);
      final taken = await _userService.isNicknameTaken(text, exceptUid: _uid);
      if (!mounted || text != _nicknameCtrl.text.trim()) return;
      setState(() {
        _nicknameAvailable = !taken;
        _checkingNickname = false;
      });
    });
  }

  Future<void> _save() async {
    if (!_canSave) return;
    setState(() => _saving = true);
    try {
      await _userService.updateProfile(
        _uid,
        nickname: _nicknameCtrl.text.trim(),
        salary: parseAmount(_salaryCtrl.text),
        ageGroup: _ageGroup,
        job: _job,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('프로필이 저장됐어요'),
          backgroundColor: _accent,
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      await DdaengModal.alert(context,
          title: '저장에 실패했어요', message: '잠시 후 다시 시도해주세요', type: ModalType.danger);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _nicknameCtrl.dispose();
    _salaryCtrl.dispose();
    super.dispose();
  }

  void _openAgeSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                width: 40,
                height: 4,
                decoration:
                BoxDecoration(color: _line, borderRadius: BorderRadius.circular(10)),
              ),
              ..._ageGroups.map((age) => ListTile(
                title: Text(age,
                    style: TextStyle(
                        fontWeight: age == _ageGroup ? FontWeight.w800 : FontWeight.w500,
                        color: age == _ageGroup ? _accent : _ink)),
                trailing:
                age == _ageGroup ? const Icon(Icons.check, color: _accent) : null,
                onTap: () {
                  setState(() => _ageGroup = age);
                  Navigator.pop(context);
                },
              )),
            ],
          ),
        ),
      ),
    );
  }

  void _openJobSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _JobPickerSheet(
        jobs: _jobs,
        jobIcons: _jobIcons,
        selected: _job,
        onSelect: (j) {
          setState(() => _job = j);
          Navigator.pop(context);
        },
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
        title: const Text('프로필 수정', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _accent))
          : SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _PreviewCard(user: _user, nickname: _nicknameCtrl.text),
            const SizedBox(height: 26),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const _FieldLabel('닉네임', icon: Icons.badge_outlined),
                Text('$_nicknameLength/10',
                    style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: _nicknameLength > 10 ? _errorColor : _inkSub)),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _nicknameCtrl,
              maxLength: 10,
              style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: _ink),
              decoration: InputDecoration(
                counterText: '',
                filled: true,
                fillColor: Colors.white,
                contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                suffixIcon: _checkingNickname
                    ? const Padding(
                  padding: EdgeInsets.all(14),
                  child: SizedBox(
                      width: 16,
                      height: 16,
                      child:
                      CircularProgressIndicator(strokeWidth: 2, color: _accent)),
                )
                    : _nicknameAvailable == true
                    ? const Icon(Icons.check_circle_rounded, color: _okColor)
                    : _nicknameAvailable == false
                    ? const Icon(Icons.cancel_rounded, color: _errorColor)
                    : null,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: _line)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: _line)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: _accent, width: 1.6)),
              ),
            ),
            if (_nicknameAvailable == false)
              const Padding(
                padding: EdgeInsets.only(top: 6, left: 4),
                child: Text('이미 사용 중인 닉네임이에요',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _errorColor)),
              )
            else if (_nicknameAvailable == true)
              const Padding(
                padding: EdgeInsets.only(top: 6, left: 4),
                child: Text('✓ 사용 가능한 닉네임이에요',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _okColor)),
              ),
            const SizedBox(height: 22),

            const _FieldLabel('월 실수령액', icon: Icons.savings_outlined),
            const SizedBox(height: 8),
            TextField(
              controller: _salaryCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [ThousandsFormatter()],
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _ink),
              decoration: InputDecoration(
                suffixText: '원',
                filled: true,
                fillColor: Colors.white,
                contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: _line)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: _line)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: _accent, width: 1.6)),
              ),
            ),
            if (parseAmount(_salaryCtrl.text) > 0)
              Padding(
                padding: const EdgeInsets.only(top: 6, left: 4),
                child: Text(koreanAmount(parseAmount(_salaryCtrl.text)),
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w700, color: _accent)),
              ),
            const SizedBox(height: 22),

            const _FieldLabel('연령대', icon: Icons.cake_outlined),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _openAgeSheet,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _line),
                ),
                child: Row(
                  children: [
                    Expanded(
                        child: Text(_ageGroup.isEmpty ? '선택해주세요' : _ageGroup,
                            style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w600,
                                color: _ageGroup.isEmpty ? _inkSub : _ink))),
                    const Icon(Icons.keyboard_arrow_down_rounded, color: _inkSub),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 22),

            const _FieldLabel('직군', icon: Icons.work_outline_rounded),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _openJobSheet,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _line),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration:
                      const BoxDecoration(color: _accentSoft, shape: BoxShape.circle),
                      alignment: Alignment.center,
                      child: Text(_job != null ? (_jobIcons[_job] ?? '✨') : '💭',
                          style: const TextStyle(fontSize: 16)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                        child: Text(_job ?? '직군을 선택해주세요',
                            style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w600,
                                color: _job == null ? _inkSub : _ink))),
                    const Icon(Icons.keyboard_arrow_down_rounded, color: _inkSub),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: _canSave ? _save : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _accent,
                  disabledBackgroundColor: const Color(0xFFFFE9A8),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: _saving
                    ? const SizedBox(
                    width: 22,
                    height: 22,
                    child:
                    CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                    : const Text('저장하기',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────── 상단 프로필 미리보기 ───────────────────────

class _PreviewCard extends StatelessWidget {
  final UserModel? user;
  final String nickname;
  const _PreviewCard({required this.user, required this.nickname});

  @override
  Widget build(BuildContext context) {
    final displayName = nickname.trim().isEmpty ? (user?.nickname ?? '') : nickname.trim();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: _accentSoft, borderRadius: BorderRadius.circular(20)),
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: Colors.white,
            child: Text(user?.coachTone.emoji ?? '🐭', style: const TextStyle(fontSize: 24)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(displayName,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 16.5, fontWeight: FontWeight.w800, color: _ink)),
                const SizedBox(height: 2),
                Text(user?.email ?? '',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 11.5, fontWeight: FontWeight.w500, color: _inkSub)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  final IconData? icon;
  const _FieldLabel(this.text, {this.icon});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      if (icon != null) ...[
        Icon(icon, size: 15, color: _inkSub),
        const SizedBox(width: 5),
      ],
      Text(text,
          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: _ink)),
    ],
  );
}

// ─────────────────────── 직군 검색 그리드 바텀시트 ───────────────────────

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
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.92,
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
                decoration:
                BoxDecoration(color: _line, borderRadius: BorderRadius.circular(10)),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(24, 18, 24, 0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('어떤 일을 하고 계신가요?',
                      style: TextStyle(
                          fontSize: 19, fontWeight: FontWeight.w800, color: _ink)),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 14, 24, 6),
                child: TextField(
                  onChanged: (v) => setState(() => _query = v),
                  decoration: InputDecoration(
                    hintText: '직군 검색',
                    hintStyle: const TextStyle(color: _inkSub),
                    prefixIcon: const Icon(Icons.search, color: _inkSub, size: 20),
                    filled: true,
                    fillColor: _bg,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                  ),
                ),
              ),
              Expanded(
                child: filtered.isEmpty
                    ? const Center(
                    child: Text('검색 결과가 없어요', style: TextStyle(color: _inkSub, fontSize: 14)))
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
                            color: sel ? _accentSoft : _bg,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: sel ? _accent : Colors.transparent, width: 1.4),
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
                                    fontWeight: sel ? FontWeight.w700 : FontWeight.w600,
                                    color: sel ? _accent : const Color(0xFF333D4B),
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
