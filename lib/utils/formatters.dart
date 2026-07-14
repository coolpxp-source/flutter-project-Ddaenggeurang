import 'package:flutter/services.dart';

class ThousandsFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return const TextEditingValue(text: '');
    final value = int.tryParse(digits);
    if (value == null || value > 999999999) return oldValue;
    final formatted = comma(int.parse(digits));
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

String comma(int n) => n.toString().replaceAllMapped(
  RegExp(r'(\d)(?=(\d{3})+$)'),
      (m) => '${m[1]},',
);

int parseAmount(String s) =>
    int.tryParse(s.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;

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