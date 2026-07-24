// lib/utils/formatters.dart

import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

/// 금액 입력창에서 숫자를 입력하면 천 단위 쉼표를 자동으로 붙입니다.
///
/// 예:
/// 500000 입력 → 500,000
///
/// 최대 입력 금액은 999,999,999원입니다.
class CurrencyFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue,
      TextEditingValue newValue,
      ) {
    // 숫자가 아닌 문자는 모두 제거합니다.
    final String digits = newValue.text.replaceAll(
      RegExp(r'[^0-9]'),
      '',
    );

    // 입력값을 모두 지운 경우 빈 문자열을 반환합니다.
    if (digits.isEmpty) {
      return const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
    }

    final int? value = int.tryParse(digits);

    // 변환할 수 없거나 최대 금액을 넘으면 이전 입력값을 유지합니다.
    if (value == null || value > 999999999) {
      return oldValue;
    }

    final String formatted = comma(value);

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(
        offset: formatted.length,
      ),
    );
  }

  /// 화면에 금액을 단순 표시할 때 사용합니다.
  ///
  /// 예:
  /// CurrencyFormatter.format(12000) → 12,000
  static String format(num amount) {
    return comma(amount.toInt());
  }
}

/// 기존 화면에서 `ThousandsFormatter`를 사용하는 경우를 위한 호환 클래스입니다.
///
/// 사용 예:
///
/// ```dart
/// inputFormatters: [
///   ThousandsFormatter(),
/// ],
/// ```
class ThousandsFormatter extends CurrencyFormatter {}

/// 숫자에 천 단위 쉼표를 적용합니다.
///
/// 예:
/// 1234000 → 1,234,000
/// -500000 → -500,000
String comma(int amount) {
  final bool isNegative = amount < 0;

  final String formatted = amount.abs().toString().replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+$)'),
        (Match match) => '${match[1]},',
  );

  return isNegative ? '-$formatted' : formatted;
}

/// 쉼표와 문자가 포함된 금액 문자열에서 숫자를 추출합니다.
///
/// 예:
/// 1,234,000원 → 1234000
///
/// 음수 기호가 포함된 경우 음수로 변환합니다.
int parseAmount(String value) {
  final String trimmedValue = value.trim();
  final bool isNegative = trimmedValue.startsWith('-');

  final String digits = trimmedValue.replaceAll(
    RegExp(r'[^0-9]'),
    '',
  );

  if (digits.isEmpty) {
    return 0;
  }

  final int amount = int.tryParse(digits) ?? 0;

  return isNegative ? -amount : amount;
}

/// 숫자 금액을 한글로 읽어서 반환합니다.
///
/// 예:
/// 0 → 영 원
/// 500000 → 오십만 원
/// 123456789 → 일억 이천삼백사십오만 육천칠백팔십구 원
String koreanAmount(int amount) {
  if (amount == 0) {
    return '영 원';
  }

  if (amount < 0) {
    return '마이너스 ${koreanAmount(-amount)}';
  }

  const List<String> numberNames = <String>[
    '',
    '일',
    '이',
    '삼',
    '사',
    '오',
    '육',
    '칠',
    '팔',
    '구',
  ];

  const List<String> smallUnits = <String>[
    '천',
    '백',
    '십',
    '',
  ];

  const List<String> largeUnits = <String>[
    '',
    '만',
    '억',
    '조',
    '경',
  ];

  /// 네 자리 단위 숫자를 한글로 변환합니다.
  ///
  /// 예:
  /// 1234 → 천이백삼십사
  /// 5000 → 오천
  String readFourDigits(int group) {
    final String value = group.toString().padLeft(
      4,
      '0',
    );

    final StringBuffer result = StringBuffer();

    for (int index = 0; index < value.length; index++) {
      final int digit = int.parse(value[index]);

      // 현재 자릿수가 0이면 읽지 않습니다.
      if (digit == 0) {
        continue;
      }

      // 십·백·천 자리의 1은
      // '일십', '일백', '일천' 대신 '십', '백', '천'으로 표시합니다.
      if (!(digit == 1 && index < 3)) {
        result.write(numberNames[digit]);
      }

      result.write(smallUnits[index]);
    }

    return result.toString();
  }

  final List<String> groups = <String>[];

  int remainingAmount = amount;
  int largeUnitIndex = 0;

  // 숫자를 만 단위로 나누어 한글 금액을 생성합니다.
  while (remainingAmount > 0) {
    final int group = remainingAmount % 10000;

    if (group > 0) {
      // 지원 범위를 넘어가는 경우에도 오류가 발생하지 않도록 처리합니다.
      final String largeUnit = largeUnitIndex < largeUnits.length
          ? largeUnits[largeUnitIndex]
          : '';

      groups.add(
        '${readFourDigits(group)}$largeUnit',
      );
    }

    remainingAmount ~/= 10000;
    largeUnitIndex++;
  }

  return '${groups.reversed.join(' ')} 원';
}

/// 날짜 표시와 관련된 공용 함수입니다.
class DateFormatter {
  const DateFormatter._();

  /// 날짜를 `15일 금요일` 형태로 반환합니다.
  static String formatDayAndWeekday(DateTime date) {
    return DateFormat(
      'd일 EEEE',
      'ko_KR',
    ).format(date);
  }

  /// 날짜를 `15일 (금)` 형태로 반환합니다.
  static String formatDayAndShortWeekday(DateTime date) {
    return DateFormat(
      'd일 (E)',
      'ko_KR',
    ).format(date);
  }
}