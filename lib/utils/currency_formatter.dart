// lib/utils/currency_formatter.dart
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

// 숫자 천단위 포멧 기능입니다~~
// 클래스 이름 앞에 밑줄(_)을 지워서 Public으로
class CurrencyFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) return newValue;

    final digitsOnly = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digitsOnly.isEmpty) return newValue.copyWith(text: '');

    final intValue = int.parse(digitsOnly);
    final newString = NumberFormat('#,###').format(intValue);

    return TextEditingValue(
      text: newString,
      selection: TextSelection.collapsed(offset: newString.length),
    );
  }
}