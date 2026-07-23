import 'package:flutter/material.dart';

/// 앱 전역 공용 디자인 토큰.
/// 각 화면에 흩어져 있던 private `_C` 클래스들을 여기로 통합했습니다.
/// 이후 모든 화면은 이 파일의 AppColors만 참조하세요.
class AppColors {
  AppColors._();

  // 배경 / 텍스트 기본
  static const bg = Color(0xFFFFF8F0);
  static const ink = Color(0xFF221A20);      // 제목/본문 (Colors.black 대체)
  static const inkSub = Color(0xFF8A8798);   // 보조 텍스트 (Colors.grey 대체)
  static const cardBorder = Color(0xFFF0E6D8);
  static const divider = Color(0xFFEEEEEE);

  // 지출 (expense_input, bulk_record 기준)
  static const expense = Color(0xFFFFA733);
  static const expenseDeep = Color(0xFF8A5200);
  static const expenseNegative = Color(0xFFF04438); // 금액 음수 강조용 (Colors.red 대체)

  // 수입 (income_input 기준)
  static const income = Color(0xFF12B76A);
  static const incomeSoft = Color(0xFFD9F1D8);

  // 저축 — 신규 통일 색상 (기존 6C5CE7 보라 / FF9166 주황 대체)
  static const saving = Color(0xFF14B8A6);
  static const savingSoft = Color(0xFFD7F3EF);

  // 공용 유틸 (날짜피커, 보조 강조 등 타입 무관 공통 요소)
  static const utility = Color(0xFF4F7DF3);
  static const utilitySoft = Color(0xFFE8EFFE);

  // 기타 (감정 태그 강조 등에서 필요시)
  static const pink = Color(0xFFFF6F91);
  static const pinkSoft = Color(0xFFFFE3EC);
  static const purple = Color(0xFF6C5CE7);
  static const purpleSoft = Color(0xFFEDE9FE);

  // 상태
  static const danger = Color(0xFFF04438);
  static const dangerSoft = Color(0xFFFFE3E3);

  /// 거래 타입('expense' | 'income' | 'saving')에 맞는 대표색
  static Color forType(String type) {
    switch (type) {
      case 'expense':
        return expense;
      case 'income':
        return income;
      case 'saving':
        return saving;
      default:
        return utility;
    }
  }

  /// 거래 타입에 맞는 금액 텍스트색 (지출은 ink, 수입/저축은 대표색 계열 유지하되
  /// 기존 transaction_detail/history의 시각적 톤을 최대한 보존)
  static Color amountColorForType(String type) {
    switch (type) {
      case 'expense':
        return ink;
      case 'saving':
        return Color(0xFF0D9488); // saving보다 살짝 진한 텍스트용 톤
      case 'income':
        return utility;
      default:
        return ink;
    }
  }
}