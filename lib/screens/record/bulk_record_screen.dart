import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/category_model.dart' show TransactionType;
import '../../models/expense_model.dart';
import '../../services/expense_service.dart';
import '../../services/income_service.dart';
import '../../services/saving_service.dart';
import '../../services/ai_service.dart';
import 'parsed_record_draft.dart';

/// 다른 입력 화면들과 통일한 팔레트.
class _C {
  static const bg = Color(0xFFF7F7F9);
  static const ink = Color(0xFF221A20);
  static const inkSub = Color(0xFF8A8798);

  static const amber = Color(0xFFFFA733);
  static const amberDeep = Color(0xFF8A5200);

  static const cardBorder = Color(0xFFF0E6D8);

  static const expenseColor = Color(0xFFF04438);
  static const incomeColor = Color(0xFF4F7DF3);
  static const savingColor = Color(0xFFFF9166);
}

class BulkRecordScreen extends StatefulWidget {
  const BulkRecordScreen({super.key});

  @override
  State<BulkRecordScreen> createState() => _BulkRecordScreenState();
}

class _BulkRecordScreenState extends State<BulkRecordScreen> {
  final _textController = TextEditingController();
  final _expenseService = ExpenseService();
  final _incomeService = IncomeService();
  final _savingService = SavingService();
  final _aiService = AiService();

  List<ParsedRecordDraft> _drafts = [];
  bool _isParsing = false;
  int _attachedPhotoCount = 0;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _onTapAddPhoto() {
    setState(() => _attachedPhotoCount++);
  }

  Future<void> _onTapParse() async {
    final User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그인 후 이용 가능합니다.')),
      );
      return;
    }

    if (_textController.text.trim().isEmpty && _attachedPhotoCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('텍스트를 입력하거나 사진을 첨부해주세요')),
      );
      return;
    }

    setState(() => _isParsing = true);

    try {
      final text = _textController.text.trim();
      final parsedList = await _aiService.parseBulkText(text);

      final now = DateTime.now();
      final drafts = parsedList.map((item) {

        DateTime itemDate = now;
        if (item.date != null && item.date!.isNotEmpty) {
          try { itemDate = DateTime.parse(item.date!); } catch (_) {}
        }

        // 💡 라벨로 뭉치지 않고 memo와 categoryName을 따로따로 넘겨줍니다!
        if (item.transactionType == '수입') {
          return ParsedRecordDraft.income(
            date: itemDate,
            memo: item.merchant,
            categoryName: item.category,
            amount: item.amount,
            categoryId: 'etc',
          );
        } else if (item.transactionType == '저축') {
          return ParsedRecordDraft.saving(
            date: itemDate,
            memo: item.merchant,
            categoryName: item.category,
            amount: item.amount,
            categoryId: 'deposit',
          );
        } else {
          return ParsedRecordDraft.expense(
            date: itemDate,
            memo: item.merchant,
            categoryName: item.category,
            amount: item.amount,
            nature: item.type == '고정비' ? ExpenseNature.fixed : ExpenseNature.variable,
          );
        }
      }).toList();

      setState(() {
        _drafts = drafts;
        _isParsing = false;
      });
    } catch (e) {
      debugPrint('AI 파싱 에러: $e');
      setState(() => _isParsing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('AI 분석 실패: $e')),
        );
      }
    }
  }

  int get _selectedCount => _drafts.where((d) => d.isSelected).length;

  Future<void> _saveAll() async {
    final User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그인된 사용자가 없습니다.')),
      );
      return;
    }

    final selected = _drafts.where((d) => d.isSelected).toList();
    if (selected.isEmpty) return;

    final String userId = currentUser.uid;

    try {
      for (final draft in selected) {

        // 💡 콘솔에서 어떻게 저장되는지 테스트용으로 확인!
        debugPrint('==== 저장 테스트 ====');
        debugPrint('타입: ${draft.type}');
        debugPrint('메모(내용): ${draft.memo}');
        debugPrint('금액: ${draft.amount}');
        debugPrint('카테고리ID: ${draft.categoryId}');
        debugPrint('====================');

        // 🚨 실제 파이어베이스 DB에 저장하는 로직은 테스트를 위해 차단(주석 처리)했습니다.
        /*
        switch (draft.type) {
          case TransactionType.expense:
            await _expenseService.addExpense(ExpenseModel(
              expenseId: '',
              userId: userId,
              amount: draft.amount,
              date: draft.date,
              categoryId: draft.categoryId ?? 'uncategorized',
              nature: draft.nature ?? ExpenseNature.variable,
              emotionTag: draft.emotionTag,
              memo: draft.memo,
              isQuickInput: true,
            ));
            break;
          case TransactionType.income:
            await _incomeService.addIncome(IncomeModel(
              incomeId: '',
              userId: userId,
              amount: draft.amount,
              categoryId: draft.categoryId ?? 'uncategorized',
              date: draft.date,
              memo: draft.memo,
            ));
            break;
          case TransactionType.saving:
            await _savingService.addSaving(SavingModel(
              savingId: '',
              userId: userId,
              date: draft.date,
              categoryId: draft.categoryId ?? 'deposit',
              accountName: draft.accountName,
              amount: draft.amount,
              memo: draft.memo,
            ));
            break;
        }
        */
      }

      if (mounted) {
        // 💡 테스트 후 결과만 확인할 수 있게 화면은 닫지 않음
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('테스트 완료! DB 저장은 차단되었으니 콘솔(Run) 창을 확인하세요.')),
        );
        // Navigator.pop(context, true);
      }
    } catch (e) {
      debugPrint('🔥 일괄 저장 에러: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('저장 실패: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // ─────────────────────── 스타일 헬퍼 ───────────────────────

  Widget _sectionCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _C.cardBorder, width: 1.2),
      ),
      child: child,
    );
  }

  Widget _sectionLabel(String text, {IconData? icon, Color? iconColor, Color? iconBg}) {
    return Row(
      children: [
        if (icon != null) ...[
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: iconBg ?? _C.amber.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 14, color: iconColor ?? _C.amberDeep),
          ),
          const SizedBox(width: 8),
        ],
        Text(
          text,
          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: _C.ink),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: _C.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('한번에 기록하기',
            style: TextStyle(fontWeight: FontWeight.w800, color: _C.ink)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── 입력 카드 ──
            _sectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionLabel('밀린 내역 붙여넣기',
                      icon: Icons.auto_awesome_rounded,
                      iconColor: _C.amberDeep,
                      iconBg: _C.amber.withValues(alpha: 0.15)),
                  const SizedBox(height: 4),
                  const Padding(
                    padding: EdgeInsets.only(left: 34),
                    child: Text(
                      '밀린 지출을 한꺼번에 입력하면 AI가 정리해드려요',
                      style: TextStyle(fontSize: 12, color: _C.inkSub),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _textController,
                    maxLines: 4,
                    style: const TextStyle(fontSize: 13.5, color: _C.ink),
                    decoration: InputDecoration(
                      hintText: '예: 7월12일 편의점 3,400 메모 계란이랑 마이쮸\n7월13일 카페 5,600 메모 할리스\n7월14일 택시 11,000',
                      hintStyle: const TextStyle(fontSize: 12.5, color: _C.inkSub),
                      filled: true,
                      fillColor: _C.bg,
                      contentPadding: const EdgeInsets.all(14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: _C.amber, width: 1.6),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      for (int i = 0; i < _attachedPhotoCount; i++) ...[
                        _buildPhotoThumb(),
                        const SizedBox(width: 8),
                      ],
                      _buildAddPhotoButton(),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── AI 분리하기 버튼 ──
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: _isParsing ? null : _onTapParse,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _C.ink,
                  disabledBackgroundColor: const Color(0xFFE5E8EB),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: _isParsing
                    ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                )
                    : const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.auto_awesome_rounded, size: 18, color: Colors.white),
                    SizedBox(width: 8),
                    Text('AI로 분리하기',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white)),
                  ],
                ),
              ),
            ),

            if (_drafts.isNotEmpty) ...[
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('인식된 항목 ${_drafts.length}개',
                      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: _C.ink)),
                  const Text('틀린 부분은 눌러서 수정',
                      style: TextStyle(fontSize: 11.5, color: _C.inkSub)),
                ],
              ),
              const SizedBox(height: 10),
              ..._drafts.map((d) => _buildDraftRow(d)),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _selectedCount == 0 ? null : _saveAll,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _C.ink,
                    disabledBackgroundColor: const Color(0xFFE5E8EB),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text('$_selectedCount개 항목 전체 저장',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAddPhotoButton() {
    return InkWell(
      onTap: _onTapAddPhoto,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: _C.amber.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _C.amber.withValues(alpha: 0.4)),
        ),
        child: const Icon(Icons.add_rounded, color: _C.amberDeep),
      ),
    );
  }

  Widget _buildPhotoThumb() {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: _C.amber.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
      ),
      alignment: Alignment.center,
      child: const Text('receipt', style: TextStyle(fontSize: 10.5, color: _C.amberDeep)),
    );
  }

  Widget _buildDraftRow(ParsedRecordDraft draft) {
    final typeColor = switch (draft.type) {
      TransactionType.expense => _C.expenseColor,
      TransactionType.income => _C.incomeColor,
      TransactionType.saving => _C.savingColor,
    };
    final typeLabel = switch (draft.type) {
      TransactionType.expense => '지출',
      TransactionType.income => '수입',
      TransactionType.saving => '저축',
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _C.cardBorder, width: 1.2),
        borderRadius: BorderRadius.circular(14),
      ),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.fromLTRB(8, 0, 8, 14),
        collapsedIconColor: _C.inkSub,
        iconColor: _C.amberDeep,
        leading: Checkbox(
          value: draft.isSelected,
          activeColor: _C.amber,
          onChanged: (v) => setState(() => draft.isSelected = v ?? true),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: typeColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(typeLabel,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: typeColor)),
            ),
            const SizedBox(width: 8),
            // 💡 화면에 띄울 때만 memo와 categoryName을 가운데 점(·)으로 이어붙여 줍니다!
            Expanded(
                child: Text('${draft.memo} · ${draft.categoryName}',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13.5, color: _C.ink))),
          ],
        ),
        subtitle: Text(_formatDate(draft.date),
            style: const TextStyle(fontSize: 11.5, color: _C.inkSub)),
        trailing: Text('${draft.amount}원',
            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: _C.ink)),
        children: [_buildDraftEditor(draft)],
      ),
    );
  }

  Widget _buildDraftEditor(ParsedRecordDraft draft) {
    switch (draft.type) {
      case TransactionType.expense:
        return Wrap(
          spacing: 6,
          runSpacing: 6,
          children: ExpenseNature.values.map((n) {
            final selected = draft.nature == n;
            return _draftChip(
              label: n.label,
              selected: selected,
              color: _C.expenseColor,
              onSelected: () => setState(() => draft.nature = n),
            );
          }).toList(),
        );
      case TransactionType.income:
        const incomeOptions = [
          ('salary', '월급'),
          ('freelance', '프리랜서'),
          ('allowance', '용돈'),
          ('etc', '기타'),
        ];
        return Wrap(
          spacing: 6,
          runSpacing: 6,
          children: incomeOptions.map((o) {
            final selected = draft.categoryId == o.$1;
            return _draftChip(
              label: o.$2,
              selected: selected,
              color: _C.incomeColor,
              onSelected: () => setState(() => draft.categoryId = o.$1),
            );
          }).toList(),
        );
      case TransactionType.saving:
        const savingOptions = [
          ('housing_subscription', '청약'),
          ('installment_saving', '적금'),
          ('deposit', '예금'),
          ('parking_account', '파킹통장'),
          ('investment', '투자'),
        ];
        return Wrap(
          spacing: 6,
          runSpacing: 6,
          children: savingOptions.map((o) {
            final selected = draft.categoryId == o.$1;
            return _draftChip(
              label: o.$2,
              selected: selected,
              color: _C.savingColor,
              onSelected: () => setState(() => draft.categoryId = o.$1),
            );
          }).toList(),
        );
    }
  }

  Widget _draftChip({
    required String label,
    required bool selected,
    required Color color,
    required VoidCallback onSelected,
  }) {
    return ChoiceChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      selected: selected,
      onSelected: (_) => onSelected(),
      selectedColor: color,
      backgroundColor: color.withValues(alpha: 0.1),
      labelStyle: TextStyle(
        color: selected ? Colors.white : color,
        fontWeight: FontWeight.w700,
      ),
      side: BorderSide.none,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide.none,
      ),
      showCheckmark: false,
      elevation: 0,
      pressElevation: 0,
    );
  }

  String _formatDate(DateTime date) {
    final today = DateTime.now();
    if (date.year == today.year && date.month == today.month && date.day == today.day) {
      return '오늘';
    }
    return '${date.month}/${date.day}';
  }
}