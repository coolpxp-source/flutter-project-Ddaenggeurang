import 'package:flutter/material.dart';

enum AppSnackBarType {
  success,
  error,
  info,
  warning,
}

class AppSnackBar {
  const AppSnackBar._();

  // 앱 공통 스낵바 표시 메서드
  static void show(
      BuildContext context, {
        required String message,
        AppSnackBarType type = AppSnackBarType.info,
        double bottomMargin = 24,
      }) {
    final snackBarStyle = _getStyle(type);

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.fromLTRB(
            20,
            0,
            20,
            bottomMargin,
          ),
          padding: EdgeInsets.zero,
          elevation: 0,
          backgroundColor: Colors.transparent,
          duration: const Duration(seconds: 3),
          content: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            decoration: BoxDecoration(
              color: snackBarStyle.backgroundColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: snackBarStyle.borderColor,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: snackBarStyle.iconBackgroundColor,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    snackBarStyle.icon,
                    color: snackBarStyle.iconColor,
                    size: 21,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    message,
                    style: TextStyle(
                      color: snackBarStyle.textColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
  }

  // 스낵바 유형별 디자인 반환 메서드
  static _AppSnackBarStyle _getStyle(
      AppSnackBarType type,
      ) {
    switch (type) {
      case AppSnackBarType.success:
        return const _AppSnackBarStyle(
          backgroundColor: Color(0xFFF1FFF7),
          borderColor: Color(0xFF72D6A0),
          iconBackgroundColor: Color(0xFFD6F7E4),
          iconColor: Color(0xFF259B61),
          textColor: Color(0xFF167246),
          icon: Icons.check_circle_outline_rounded,
        );

      case AppSnackBarType.error:
        return const _AppSnackBarStyle(
          backgroundColor: Color(0xFFFFF1F3),
          borderColor: Color(0xFFFF8FA3),
          iconBackgroundColor: Color(0xFFFFD8DF),
          iconColor: Color(0xFFE94B67),
          textColor: Color(0xFFB52842),
          icon: Icons.error_outline_rounded,
        );

      case AppSnackBarType.warning:
        return const _AppSnackBarStyle(
          backgroundColor: Color(0xFFFFFAEB),
          borderColor: Color(0xFFF4C95D),
          iconBackgroundColor: Color(0xFFFFEDB8),
          iconColor: Color(0xFFD89400),
          textColor: Color(0xFF8A6200),
          icon: Icons.warning_amber_rounded,
        );

      case AppSnackBarType.info:
        return const _AppSnackBarStyle(
          backgroundColor: Color(0xFFF4F1FF),
          borderColor: Color(0xFFA894F5),
          iconBackgroundColor: Color(0xFFE2DAFF),
          iconColor: Color(0xFF7458D8),
          textColor: Color(0xFF55409E),
          icon: Icons.info_outline_rounded,
        );
    }
  }
}

class _AppSnackBarStyle {
  final Color backgroundColor;
  final Color borderColor;
  final Color iconBackgroundColor;
  final Color iconColor;
  final Color textColor;
  final IconData icon;

  const _AppSnackBarStyle({
    required this.backgroundColor,
    required this.borderColor,
    required this.iconBackgroundColor,
    required this.iconColor,
    required this.textColor,
    required this.icon,
  });
}