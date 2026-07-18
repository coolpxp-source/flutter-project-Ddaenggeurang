import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/app_lock_service.dart';
import '../../services/auth_service.dart';
import '../../widgets/common/ddaeng_modal.dart';
import 'change_password_screen.dart';
import 'contact_screen.dart';
import 'legal_doc_screen.dart';
import 'login_history_screen.dart';

const _accent = Color(0xFFF5A623);
const _accentSoft = Color(0xFFFFF0A6);
const _ink = Color(0xFF221A16);
const _inkSub = Color(0xFF8A7E77);
const _bg = Color(0xFFFAF8F6);
const _line = Color(0xFFF0E9E4);
const _dangerColor = Color(0xFFF04438);
const _dangerSoft = Color(0xFFFEF0EF);

class SettingScreen extends StatefulWidget {
  const SettingScreen({super.key});

  @override
  State<SettingScreen> createState() => _SettingScreenState();
}

class _SettingScreenState extends State<SettingScreen> {
  final _auth = AuthService();
  bool _busy = false;
  bool? _appLockEnabled; // null이면 아직 로딩 중

  /// 이메일/비밀번호로 가입한 계정만 비밀번호를 갖고 있다.
  /// 소셜 로그인(카카오/네이버/구글/애플) 계정은 변경할 비밀번호가 없으므로 숨긴다.
  bool get _hasPasswordProvider =>
      _auth.currentUser?.providerData.any((p) => p.providerId == 'password') ?? false;

  @override
  void initState() {
    super.initState();
    _loadAppLockState();
  }

  Future<void> _loadAppLockState() async {
    final enabled = await AppLockService.instance.isEnabled();
    if (mounted) setState(() => _appLockEnabled = enabled);
  }

  Future<void> _toggleAppLock(bool value) async {
    if (value) {
      final supported = await AppLockService.instance.isDeviceSupported();
      if (!supported) {
        if (!mounted) return;
        await DdaengModal.alert(
          context,
          title: '기기 잠금이 필요해요',
          message: '지문·PIN·패턴 등 기기 자체 잠금이 설정돼 있어야 앱 잠금을 쓸 수 있어요',
          type: ModalType.warning,
        );
        return;
      }
      // 켜기 전에 본인 확인 — 잠금을 걸어놓고 정작 본인이 인증을 못 하는
      // 상황(다른 사람 지문 등록 등)을 미리 걸러낸다.
      final verified = await AppLockService.instance.authenticate();
      if (!verified) return;
    }
    await AppLockService.instance.setEnabled(value);
    if (mounted) setState(() => _appLockEnabled = value);
  }

  /// 홈 화면 첫 방문자 전용 스팟라이트 투어를 다시 보고 싶을 때 — 홈 화면
  /// _HomeDashboardState는 탭을 벗어났다 돌아오면 새로 만들어지므로(홈 탭
  /// 바디가 switch문으로 매번 새로 그려짐), 여기서는 "다시 보여줘도 되는 상태"로
  /// 되돌려놓고 홈 탭으로 안내만 하면 기존 로직이 알아서 다시 틀어준다.
  Future<void> _replayTour() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('homeTourShown');
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('홈 탭으로 이동하면 튜토리얼이 다시 시작돼요'),
        backgroundColor: _ink,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _logout() async {
    final ok = await DdaengModal.confirm(
      context,
      title: '로그아웃 하시겠어요?',
      message: '다시 로그인하면 이어서 사용할 수 있어요',
      type: ModalType.warning,
      confirmText: '로그아웃',
    );
    if (ok) await _auth.signOut();
  }

  Future<void> _deleteAccount() async {
    final ok = await DdaengModal.confirm(
      context,
      title: '정말 탈퇴하시겠어요?',
      message: '작성한 모든 기록이 삭제되고 되돌릴 수 없어요',
      type: ModalType.danger,
      confirmText: '탈퇴하기',
    );
    if (!ok) return;
    setState(() => _busy = true);
    try {
      await _auth.deleteAccount();
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      await DdaengModal.alert(
        context,
        title: '탈퇴에 실패했어요',
        message: '보안을 위해 재로그인이 필요할 수 있어요. 다시 로그인 후 시도해주세요',
        type: ModalType.danger,
      );
    }
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
        title: const Text('설정', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: AbsorbPointer(
        absorbing: _busy,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const _SectionLabel('고객지원'),
            const SizedBox(height: 10),
            _Group(children: [
              _Row(
                  icon: Icons.description_outlined,
                  title: '이용약관',
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => LegalDocScreen(
                          title: '이용약관',
                          updatedAt: kLegalUpdatedAt,
                          sections: kTermsOfService)))),
              _Row(
                  icon: Icons.privacy_tip_outlined,
                  title: '개인정보 처리방침',
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => LegalDocScreen(
                          title: '개인정보 처리방침',
                          updatedAt: kLegalUpdatedAt,
                          sections: kPrivacyPolicy)))),
              _Row(
                  icon: Icons.mail_outline_rounded,
                  title: '문의하기',
                  onTap: () => Navigator.of(context)
                      .push(MaterialPageRoute(builder: (_) => const ContactScreen())),
                  showDivider: false),
            ]),
            const SizedBox(height: 22),

            const _SectionLabel('정보'),
            const SizedBox(height: 10),
            _Group(children: [
              _Row(
                  icon: Icons.info_outline_rounded,
                  title: '앱 버전',
                  trailing: 'v1.0.0',
                  onTap: null,
                  showDivider: false),
            ]),
            const SizedBox(height: 22),

            const _SectionLabel('도움말'),
            const SizedBox(height: 10),
            _Group(children: [
              _Row(
                  icon: Icons.replay_rounded,
                  title: '튜토리얼 다시보기',
                  onTap: _replayTour,
                  showDivider: false),
            ]),
            const SizedBox(height: 22),

            const _SectionLabel('보안'),
            const SizedBox(height: 10),
            _Group(children: [
              _SwitchRow(
                  icon: Icons.fingerprint_rounded,
                  title: '앱 잠금',
                  subtitle: '생체인증 또는 기기 잠금으로 앱을 보호해요',
                  value: _appLockEnabled ?? false,
                  onChanged: _appLockEnabled == null ? null : _toggleAppLock),
              const Divider(height: 1, indent: 16, endIndent: 16, color: _line),
              _Row(
                  icon: Icons.history_rounded,
                  title: '로그인 활동',
                  onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const LoginHistoryScreen())),
                  showDivider: false),
            ]),
            const SizedBox(height: 22),

            const _SectionLabel('계정'),
            const SizedBox(height: 10),
            if (_hasPasswordProvider) ...[
              _Group(children: [
                _Row(
                    icon: Icons.password_rounded,
                    title: '비밀번호 변경',
                    onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const ChangePasswordScreen())),
                    showDivider: false),
              ]),
              const SizedBox(height: 10),
            ],
            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton.icon(
                onPressed: _busy ? null : _logout,
                style: OutlinedButton.styleFrom(
                  foregroundColor: _ink,
                  backgroundColor: Colors.white,
                  side: const BorderSide(color: _line),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                icon: const Icon(Icons.logout_rounded, size: 18),
                label: const Text('로그아웃',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: _dangerSoft,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                      color: _dangerColor.withValues(alpha: 0.08),
                      blurRadius: 10,
                      offset: const Offset(0, 4)),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton(
                    onPressed: _busy ? null : _deleteAccount,
                    style: TextButton.styleFrom(foregroundColor: _dangerColor),
                    child: _busy
                        ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: _dangerColor))
                        : const Text('회원탈퇴',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),

            const _BrandFooter(),
          ]
              .animate(interval: 55.ms)
              .fadeIn(duration: 340.ms, curve: Curves.easeOut)
              .slideY(begin: 0.06, end: 0, curve: Curves.easeOutCubic),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 4),
    child: Text(text,
        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: _inkSub)),
  );
}

class _BrandFooter extends StatelessWidget {
  const _BrandFooter();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [_accentSoft, Color.lerp(_accentSoft, Colors.white, 0.15)!],
              ),
              boxShadow: [
                BoxShadow(
                    color: _accent.withValues(alpha: 0.14),
                    blurRadius: 10,
                    offset: const Offset(0, 4)),
              ],
            ),
            padding: const EdgeInsets.all(8),
            child: Image.asset('assets/images/Icon.png'),
          ),
          const SizedBox(height: 8),
          const Text('땡그랑',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: _ink)),
          const SizedBox(height: 2),
          const Text('가계부는 똑똑하게, 소비는 똑바르게!',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: _inkSub)),
        ],
      ),
    );
  }
}

class _Group extends StatelessWidget {
  final List<Widget> children;
  const _Group({required this.children});

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
            color: _ink.withValues(alpha: 0.045), blurRadius: 14, offset: const Offset(0, 5)),
      ],
    ),
    child: Column(children: children),
  );
}

class _Row extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? trailing;
  final VoidCallback? onTap;
  final bool showDivider;

  const _Row({
    required this.icon,
    required this.title,
    this.trailing,
    required this.onTap,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [_accentSoft, Color.lerp(_accentSoft, Colors.white, 0.15)!],
                    ),
                    boxShadow: [
                      BoxShadow(
                          color: _accent.withValues(alpha: 0.16),
                          blurRadius: 6,
                          offset: const Offset(0, 2)),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Icon(icon, size: 17, color: _accent),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(title,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600, color: _ink)),
                ),
                if (trailing != null)
                  Text(trailing!,
                      style: const TextStyle(
                          fontSize: 12.5, fontWeight: FontWeight.w600, color: _inkSub))
                else if (onTap != null)
                  const Icon(Icons.chevron_right_rounded, size: 20, color: _inkSub),
              ],
            ),
          ),
        ),
        if (showDivider) const Divider(height: 1, indent: 16, endIndent: 16, color: _line),
      ],
    );
  }
}

class _SwitchRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  const _SwitchRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [_accentSoft, Color.lerp(_accentSoft, Colors.white, 0.15)!],
              ),
              boxShadow: [
                BoxShadow(
                    color: _accent.withValues(alpha: 0.16), blurRadius: 6, offset: const Offset(0, 2)),
              ],
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 17, color: _accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _ink)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: const TextStyle(
                        fontSize: 11.5, fontWeight: FontWeight.w500, color: _inkSub)),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged, activeThumbColor: _accent),
        ],
      ),
    );
  }
}
