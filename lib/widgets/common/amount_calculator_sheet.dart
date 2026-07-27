import 'package:flutter/material.dart';
import '../../utils/app_colors.dart';
import '../../utils/formatters.dart'; // comma() 재사용

/// 더치페이 등 금액을 계산해서 입력하고 싶을 때 쓰는 계산기 바텀시트.
/// [initialAmount]를 좌변 시작값으로 하여 사칙연산 후 "금액 변경"을 누르면
/// 계산된 정수 금액을 반환한다. 취소 시 null을 반환한다.
Future<int?> showAmountCalculatorSheet(
    BuildContext context, {
      required int initialAmount,
    }) {
  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _AmountCalculatorSheet(initialAmount: initialAmount),
  );
}

enum _Op { add, subtract, multiply, divide }

class _AmountCalculatorSheet extends StatefulWidget {
  final int initialAmount;
  const _AmountCalculatorSheet({required this.initialAmount});

  @override
  State<_AmountCalculatorSheet> createState() => _AmountCalculatorSheetState();
}

class _AmountCalculatorSheetState extends State<_AmountCalculatorSheet> {
  late double _left; // 좌변(시작 금액, 연산자를 누르면 확정됨)
  _Op? _op;
  String _rightInput = ''; // 연산자 입력 후 우변 숫자(콤마 없는 문자열)

  // 연산자를 누르기 전, 좌변(시작 금액)을 새로 고쳐 입력 중인지 여부.
  // true가 되면 숫자패드는 _leftInput을 채우고, _left는 그 값을 그대로 보여준다.
  bool _isEditingLeft = false;
  String _leftInput = '';

  @override
  void initState() {
    super.initState();
    _left = widget.initialAmount.toDouble();
  }

  double get _right => double.tryParse(_rightInput) ?? 0;

  // 좌변 편집 중이면 편집 중인 값, 아니면 확정된 _left를 보여준다.
  double get _displayedLeft =>
      _isEditingLeft ? (double.tryParse(_leftInput) ?? 0) : _left;

  double get _result {
    if (_op == null) return _displayedLeft;
    switch (_op!) {
      case _Op.add:
        return _left + _right;
      case _Op.subtract:
        return _left - _right;
      case _Op.multiply:
        return _left * _right;
      case _Op.divide:
        return _right == 0 ? _left : _left / _right;
    }
  }

  String get _opSymbol {
    switch (_op) {
      case _Op.add:
        return '+';
      case _Op.subtract:
        return '−';
      case _Op.multiply:
        return '×';
      case _Op.divide:
        return '÷';
      case null:
        return '';
    }
  }

  void _pressOp(_Op op) {
    setState(() {
      if (_op != null && _rightInput.isNotEmpty) {
        // 이미 연산자와 숫자가 입력되어 있으면 먼저 계산해서 좌변에 반영 (연속 계산 지원)
        _left = _result;
      } else if (_op == null) {
        // 좌변을 새로 편집했다면(혹은 그대로 두었다면) 그 값을 좌변으로 확정
        _left = _displayedLeft;
      }
      _isEditingLeft = false;
      _leftInput = '';
      _op = op;
      _rightInput = '';
    });
  }

  void _pressDigit(String d) {
    setState(() {
      if (_op == null) {
        // 연산자를 누르기 전: 좌변(시작 금액)을 직접 편집
        if (!_isEditingLeft) {
          // 처음 입력 시작하면 기존 값을 지우고 새로 입력
          _isEditingLeft = true;
          _leftInput = '';
        }
        if (_leftInput.isEmpty && d == '00') return; // 맨 앞에 00은 무시
        if (_leftInput.length >= 9) return; // 과도한 자릿수 방지
        _leftInput += d;
      } else {
        // 연산자를 누른 후: 우변 숫자 입력
        if (_rightInput.isEmpty && d == '00') return; // 맨 앞에 00은 무시
        if (_rightInput.length >= 9) return; // 과도한 자릿수 방지
        _rightInput += d;
      }
    });
  }

  void _pressBackspace() {
    setState(() {
      if (_op == null) {
        // 좌변 편집 중 지우기
        if (!_isEditingLeft) {
          // 아직 편집을 시작 안 했다면, 현재 보이는 초기값을 먼저 문자열로 읽어온 뒤
          // 편집 모드로 전환하고 마지막 한 글자를 지운다.
          final current = _displayedLeft.round().toString();
          _isEditingLeft = true;
          _leftInput = current;
        }
        if (_leftInput.isNotEmpty) {
          _leftInput = _leftInput.substring(0, _leftInput.length - 1);
        }
      } else if (_rightInput.isNotEmpty) {
        _rightInput = _rightInput.substring(0, _rightInput.length - 1);
      } else {
        _op = null; // 숫자가 없는 상태에서 지우면 연산자부터 취소
      }
    });
  }

  void _apply() {
    final result = _result.round();
    Navigator.of(context).pop(result < 0 ? 0 : result);
  }

  @override
  Widget build(BuildContext context) {
    final resultText = comma(_result.round());

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // ── 수식 표시줄 ──
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: RichText(
                      textAlign: TextAlign.left,
                      text: TextSpan(
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink,
                        ),
                        children: [
                          TextSpan(text: '₩ ${comma(_displayedLeft.round())}'),
                          if (_op != null) TextSpan(text: ' $_opSymbol '),
                          if (_rightInput.isNotEmpty)
                            TextSpan(text: comma(int.parse(_rightInput))),
                        ],
                      ),
                    ),
                  ),
                  if (_op != null) ...[
                    Text(
                      ' = ',
                      style: TextStyle(
                        fontSize: 22,
                        color: Colors.grey.shade400,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '₩ $resultText',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: AppColors.ink,
                      ),
                    ),
                  ],
                  IconButton(
                    onPressed: _pressBackspace,
                    icon: const Icon(Icons.backspace_outlined, size: 20),
                  ),
                ],
              ),
              const Divider(height: 24),
              Text(
                '수정할 금액을 입력하세요.',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
              ),
              const SizedBox(height: 12),
              // ── 숫자패드 + 연산자 ──
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: Column(
                      children: [
                        _numRow(['1', '2', '3']),
                        _numRow(['4', '5', '6']),
                        _numRow(['7', '8', '9']),
                        _numRow(['00', '0']),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 1,
                    child: Column(
                      children: [
                        _opButton('−', _Op.subtract),
                        _opButton('÷', _Op.divide),
                        _opButton('×', _Op.multiply),
                        _opButton('+', _Op.add),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('취소'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _apply,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.ink,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text(
                        '금액 변경',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _numRow(List<String> labels) {
    return Row(
      children: labels
          .map(
            (l) => Expanded(
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: OutlinedButton(
              onPressed: () => _pressDigit(l),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: BorderSide(color: Colors.grey.shade200),
              ),
              child: Text(l, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            ),
          ),
        ),
      )
          .toList(),
    );
  }

  Widget _opButton(String label, _Op op) {
    final active = _op == op;
    return Padding(
      padding: const EdgeInsets.all(4),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () => _pressOp(op),
          style: ElevatedButton.styleFrom(
            backgroundColor: active ? AppColors.ink : const Color(0xFFEAF2FF),
            foregroundColor: active ? Colors.white : AppColors.ink,
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          child: Text(label, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        ),
      ),
    );
  }
}