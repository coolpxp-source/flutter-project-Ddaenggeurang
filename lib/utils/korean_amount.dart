/// 숫자 금액을 "1만 원", "20만 원", "1억 2,345만 원" 같은
/// 한글 단위 표기로 변환합니다.
///
/// 예)
///   koreanAmountText(10000)      -> "1만 원"
///   koreanAmountText(200000)     -> "20만 원"
///   koreanAmountText(12345)      -> "1만 2,345 원"
///   koreanAmountText(100000000)  -> "1억 원"
///   koreanAmountText(5000)       -> "5,000 원"
///   koreanAmountText(0)          -> "" (표시 안 함)
String koreanAmountText(int amount) {
  if (amount <= 0) return '';

  final eok = amount ~/ 100000000;
  final remainAfterEok = amount % 100000000;
  final man = remainAfterEok ~/ 10000;
  final remain = remainAfterEok % 10000;

  final parts = <String>[];
  if (eok > 0) parts.add('$eok억');
  if (man > 0) parts.add('${_comma(man)}만');
  if (remain > 0) parts.add(_comma(remain));

  if (parts.isEmpty) return '';
  return '${parts.join(' ')} 원';
}

String _comma(int n) {
  final s = n.toString();
  final buffer = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buffer.write(',');
    buffer.write(s[i]);
  }
  return buffer.toString();
}