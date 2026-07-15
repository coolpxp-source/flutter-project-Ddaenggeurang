import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../widgets/common/ddaeng_modal.dart';

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

  void _comingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature 화면은 준비 중이에요'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: _ink,
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
                  onTap: () => _comingSoon('이용약관')),
              _Row(
                  icon: Icons.privacy_tip_outlined,
                  title: '개인정보 처리방침',
                  onTap: () => _comingSoon('개인정보 처리방침')),
              _Row(
                  icon: Icons.mail_outline_rounded,
                  title: '문의하기',
                  onTap: () => _comingSoon('문의하기'),
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

            const _SectionLabel('계정'),
            const SizedBox(height: 10),
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
          ],
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
            decoration: const BoxDecoration(color: _accentSoft, shape: BoxShape.circle),
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
      border: Border.all(color: _line),
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
                  decoration: const BoxDecoration(color: _accentSoft, shape: BoxShape.circle),
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
