import 'package:flutter/material.dart';

/// 모달 타입 — 아이콘과 색상을 결정
enum ModalType {
  info(Color(0xFF2F6BFF), Color(0xFFEEF4FF), Icons.info_outline),
  success(Color(0xFF12B76A), Color(0xFFE6F7EF), Icons.check_circle_outline),
  warning(Color(0xFFF5A623), Color(0xFFFFF7E6), Icons.warning_amber_rounded),
  danger(Color(0xFFF04438), Color(0xFFFEF0EF), Icons.error_outline),
  coin(Color(0xFFFFC93C), Color(0xFFFFF9E8), Icons.savings_outlined);

  final Color main;
  final Color bg;
  final IconData icon;
  const ModalType(this.main, this.bg, this.icon);
}

class DdaengModal {
  /// 알림 모달 (확인 버튼 하나)
  static Future<void> alert(
      BuildContext context, {
        required String title,
        String? message,
        ModalType type = ModalType.info,
        String confirmText = '확인',
        String? emoji, // 코치 이모지 등 — 지정 시 아이콘 대신 표시
      }) {
    return _show(
      context,
      title: title,
      message: message,
      type: type,
      emoji: emoji,
      actions: (ctx) => [
        Expanded(
          child: _FilledBtn(
            label: confirmText,
            color: type.main,
            onTap: () => Navigator.pop(ctx),
          ),
        ),
      ],
    );
  }

  /// 확인 모달 (취소 / 확인) — true 반환 시 사용자가 확인 누름
  static Future<bool> confirm(
      BuildContext context, {
        required String title,
        String? message,
        ModalType type = ModalType.warning,
        String cancelText = '취소',
        String confirmText = '확인',
        String? emoji,
      }) async {
    final result = await _show<bool>(
      context,
      title: title,
      message: message,
      type: type,
      emoji: emoji,
      barrierDismissible: type != ModalType.danger,
      actions: (ctx) => [
        Expanded(
          child: _OutlinedBtn(
            label: cancelText,
            onTap: () => Navigator.pop(ctx, false),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _FilledBtn(
            label: confirmText,
            color: type.main,
            onTap: () => Navigator.pop(ctx, true),
          ),
        ),
      ],
    );
    return result ?? false;
  }

  /// 커스텀 바디를 넣는 모달 (AI 판정, 리워드 등)
  static Future<T?> custom<T>(
      BuildContext context, {
        required Widget child,
        bool barrierDismissible = true,
      }) {
    return showGeneralDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      barrierLabel: 'modal',
      barrierColor: Colors.black.withOpacity(0.45),
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (_, __, ___) => const SizedBox.shrink(),
      transitionBuilder: (ctx, anim, __, ___) {
        final curved =
        CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween(begin: 0.92, end: 1.0).animate(curved),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.18),
                          blurRadius: 32,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: child,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ─── 내부 구현 ───
  static Future<T?> _show<T>(
      BuildContext context, {
        required String title,
        String? message,
        required ModalType type,
        String? emoji,
        bool barrierDismissible = true,
        required List<Widget> Function(BuildContext) actions,
      }) {
    return custom<T>(
      context,
      barrierDismissible: barrierDismissible,
      child: Builder(
        builder: (ctx) => Padding(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 아이콘 / 이모지
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: type.bg,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: emoji != null
                    ? Text(emoji, style: const TextStyle(fontSize: 32))
                    : Icon(type.icon, size: 32, color: type.main),
              ),
              const SizedBox(height: 18),

              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                  color: Color(0xFF101828),
                ),
              ),

              if (message != null) ...[
                const SizedBox(height: 10),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14.5,
                    height: 1.6,
                    color: Color(0xFF667085),
                  ),
                ),
              ],

              const SizedBox(height: 26),
              Row(children: actions(ctx)),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════ 버튼 ══════════

class _FilledBtn extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _FilledBtn({
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 50,
    child: ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700),
      ),
    ),
  );
}

class _OutlinedBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _OutlinedBtn({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 50,
    child: OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF667085),
        side: const BorderSide(color: Color(0xFFE8ECF3), width: 1.4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700),
      ),
    ),
  );
}