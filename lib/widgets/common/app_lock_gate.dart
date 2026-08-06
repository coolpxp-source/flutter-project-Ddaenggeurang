import 'package:flutter/material.dart';
import '../../services/app_lock_service.dart';

const _accent = Color(0xFFF5A623);
const _ink = Color(0xFF221A16);
const _inkSub = Color(0xFF8A7E77);

/// 앱 최상단(main.dart)에서 AppGate를 감싸는 잠금 게이트.
/// 앱 잠금 설정이 켜져 있으면: (1) 콜드 스타트 시, (2) 백그라운드에 갔다가
/// 돌아왔을 때 인증을 요구한다. 자체 화면 라우팅이 아니라 Stack으로 기존
/// 화면 위에 덮어씌우는 방식이라, 잠금 로직이 로그인/홈 어느 화면 흐름과도
/// 얽히지 않는다.
class AppLockGate extends StatefulWidget {
  final Widget child;
  const AppLockGate({super.key, required this.child});

  @override
  State<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends State<AppLockGate> with WidgetsBindingObserver {
  bool _checked = false;
  bool _locked = false;
  bool _authenticating = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkLockOnStart();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _checkLockOnStart() async {
    final enabled = await AppLockService.instance.isEnabled();
    if (!mounted) return;
    setState(() {
      _locked = enabled;
      _checked = true;
    });
    if (enabled) _authenticate();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _armLockIfEnabled();
    } else if (state == AppLifecycleState.resumed && _locked) {
      _authenticate();
    }
  }

  Future<void> _armLockIfEnabled() async {
    final enabled = await AppLockService.instance.isEnabled();
    if (enabled && mounted) setState(() => _locked = true);
  }

  Future<void> _authenticate() async {
    if (_authenticating) return;
    _authenticating = true;
    final ok = await AppLockService.instance.authenticate();
    _authenticating = false;
    if (!mounted) return;
    if (ok) setState(() => _locked = false);
  }

  @override
  Widget build(BuildContext context) {
    if (!_checked) return const SizedBox.shrink();
    return Stack(
      children: [
        widget.child,
        if (_locked) _LockScreen(onUnlock: _authenticate),
      ],
    );
  }
}

class _LockScreen extends StatelessWidget {
  final VoidCallback onUnlock;
  const _LockScreen({required this.onUnlock});

  @override
  Widget build(BuildContext context) {
    return Material(
      child: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.white, Color(0xFFFFF3DE), Colors.white],
            stops: [0.0, 0.55, 1.0],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset('assets/images/Icon.png', width: 72, height: 72),
              const SizedBox(height: 20),
              const Text('잠겨 있어요',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: _ink)),
              const SizedBox(height: 6),
              const Text('인증하고 땡그랑을 계속 이용하세요',
                  style: TextStyle(fontSize: 12.5, color: _inkSub)),
              const SizedBox(height: 28),
              ElevatedButton.icon(
                onPressed: onUnlock,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                icon: const Icon(Icons.fingerprint_rounded, size: 20),
                label: const Text('인증하기',
                    style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
