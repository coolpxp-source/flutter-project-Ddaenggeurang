// lib/utils/formatters.dart
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

/// 금액 입력창용 천단위 콤마 자동 포맷터
/// (기존 currency_formatter.dart의 CurrencyFormatter를 여기로 통합)
class CurrencyFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return const TextEditingValue(text: '');

    final value = int.tryParse(digits);
    if (value == null || value > 999999999) return oldValue;

    final formatted = comma(value);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  /// 화면에 금액을 단순 표시할 때 사용 (예: CurrencyFormatter.format(12000) → "12,000")
  static String format(num amount) => comma(amount.toInt());
}

/// ThousandsFormatter로 이미 쓰고 있는 화면들과의 호환을 위한 별칭
class ThousandsFormatter extends CurrencyFormatter {}

/// 천단위 콤마 삽입 (예: 1234000 → "1,234,000")
String comma(int n) => n.toString().replaceAllMapped(
  RegExp(r'(\d)(?=(\d{3})+$)'),
      (m) => '${m[1]},',
);

/// "1,234,000원" 같은 문자열에서 콤마/문자 제거하고 숫자만 추출
int parseAmount(String s) =>
    int.tryParse(s.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;

/// 큰 금액을 한글 단위로 표시 (예: 12000000 → "1200만원", 120000000 → "1억 2000만원")
String koreanAmount(int n) {
  if (n <= 0) return '';
  if (n < 10000) return '${comma(n)}원';
  final man = n ~/ 10000;
  final rest = n % 10000;
  if (man >= 10000) {
    final eok = man ~/ 10000;
    final restMan = man % 10000;
    return restMan == 0 ? '$eok억원' : '$eok억 ${comma(restMan)}만원';
  }
  return rest == 0 ? '$man만원' : '$man만 ${comma(rest)}원';
}

class DateFormatter {
  // 예: "15일 금요일" 형태로 반환
  static String formatDayAndWeekday(DateTime date) {
    return DateFormat('d일 EEEE', 'ko_KR').format(date);
  }

  // 예: "15일 (금)" 형태로 짧게 반환하고 싶다면 아래 함수를 쓰시면 됩니다.
  static String formatDayAndShortWeekday(DateTime date) {
    return DateFormat('d일 (E)', 'ko_KR').format(date);
  }
}