import 'package:flutter/material.dart';
import '../../models/category_model.dart' show TransactionType;
import '../../models/expense_model.dart';
import '../../models/income_model.dart';
import '../../models/saving_model.dart';
import '../../services/expense_service.dart';
import '../../services/income_service.dart';
import '../../services/saving_service.dart';
import 'parsed_record_draft.dart';

/// "한번에 기록하기" / 퉁치기 화면
/// 자유 텍스트 한 번(또는 사진 여러 장)으로 여러 건을 한꺼번에 인식 → 확인/수정 → 전체 저장
///
/// TODO: _parseStub()을 실제 파싱 로직으로 교체
///   - 텍스트: 로컬 AI에 프롬프트로 넘겨서 JSON 리스트로 항목 추출
///   - 사진: OCR(ML Kit 등)로 각 이미지에서 항목 추출
///   두 경로 모두 최종적으로는 List<ParsedRecordDraft>만 만들어주면 이 화면은 그대로 재사용 가능
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

  List<ParsedRecordDraft> _drafts = [];
  bool _isParsing = false;

  // TODO: image_picker로 실제 여러 장 첨부 연결. 지금은 개수만 카운트하는 자리표시자.
  int _attachedPhotoCount = 0;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _onTapAddPhoto() {
    // TODO: image_picker(멀티 선택) 연결
    setState(() => _attachedPhotoCount++);
  }

  Future<void> _onTapParse() async {
    if (_textController.text.trim().isEmpty && _attachedPhotoCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('텍스트를 입력하거나 사진을 첨부해주세요')),
      );
      return;
    }

    setState(() => _isParsing = true);

    // ── 스텁: 실제로는 로컬 AI/OCR 결과가 여기 채워짐 ──
    await Future.delayed(const Duration(milliseconds: 600));
    final now = DateTime.now();
    final stubResult = [
      ParsedRecordDraft.expense(
        date: now.subtract(const Duration(days: 1)),
        label: '스타벅스 · 카페',
        amount: 4500,
      ),
      ParsedRecordDraft.expense(
        date: now,
        label: '편의점 · 식비',
        amount: 3200,
      ),
      ParsedRecordDraft.income(
        date: now.subtract(const Duration(days: 2)),
        label: '용돈',
        amount: 50000,
        incomeSource: IncomeSource.allowance,
      ),
      ParsedRecordDraft.saving(
        date: now,
        label: '정기적금',
        amount: 300000,
        categoryId: 'installment_saving',
      ),
    ];

    setState(() {
      _drafts = stubResult;
      _isParsing = false;
    });
  }

  int get _selectedCount => _drafts.where((d) => d.isSelected).length;

  Future<void> _saveAll() async {
    final selected = _drafts.where((d) => d.isSelected).toList();
    if (selected.isEmpty) return;

    // TODO: userId는 실제 로그인 유저 uid로 교체 (FirebaseAuth.instance.currentUser?.uid)
    const userId = 'TODO_USER_ID';

    for (final draft in selected) {
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
            isQuickInput: true, // 퉁치기로 들어온 건 표시해둠
          ));
          break;
        case TransactionType.income:
          await _incomeService.addIncome(IncomeModel(
            incomeId: '',
            userId: userId,
            amount: draft.amount,
            incomeSource: draft.incomeSource ?? IncomeSource.etc,
            date: draft.date,
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
          ));
          break;
      }
    }

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('한번에 기록하기'),
        centerTitle: true,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '밀린 지출을 한꺼번에 입력하면 AI가 정리해드려요',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _textController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: '예: 7월12일 편의점 3,400 메모 계란이랑 마이쮸\n'
                    '7월13일 카페 5,600 메모 할리스\n7월14일 택시 11,000',
                hintStyle: const TextStyle(fontSize: 13, color: Colors.grey),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
            const SizedBox(height: 12),

            // 사진 여러 장 첨부
            Row(
              children: [
                for (int i = 0; i < _attachedPhotoCount; i++) ...[
                  _buildPhotoThumb(),
                  const SizedBox(width: 8),
                ],
                _buildAddPhotoButton(),
              ],
            ),
            const SizedBox(height: 16),

            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton(
                onPressed: _isParsing ? null : _onTapParse,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                child: _isParsing
                    ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
                    : const Text('AI로 분리하기', style: TextStyle(color: Colors.white)),
              ),
            ),

            if (_drafts.isNotEmpty) ...[
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('인식된 항목 ${_drafts.length}개',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  const Text('틀린 부분은 눌러서 수정',
                      style: TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
              const SizedBox(height: 8),
              ..._drafts.map((d) => _buildDraftRow(d)),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _selectedCount == 0 ? null : _saveAll,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  child: Text(
                    '$_selectedCount개 항목 전체 저장',
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
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
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.green, style: BorderStyle.solid),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.add, color: Colors.green),
      ),
    );
  }

  Widget _buildPhotoThumb() {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      alignment: Alignment.center,
      child: const Text('receipt', style: TextStyle(fontSize: 11, color: Colors.green)),
    );
  }

  Widget _buildDraftRow(ParsedRecordDraft draft) {
    final typeColor = switch (draft.type) {
      TransactionType.expense => Colors.redAccent,
      TransactionType.income => Colors.blueAccent,
      TransactionType.saving => Colors.orangeAccent,
    };
    final typeLabel = switch (draft.type) {
      TransactionType.expense => '지출',
      TransactionType.income => '수입',
      TransactionType.saving => '저축',
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE8ECF3)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
        leading: Checkbox(
          value: draft.isSelected,
          onChanged: (v) => setState(() => draft.isSelected = v ?? true),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: typeColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(typeLabel, style: TextStyle(fontSize: 11, color: typeColor)),
            ),
            const SizedBox(width: 6),
            Expanded(child: Text(draft.label, overflow: TextOverflow.ellipsis)),
          ],
        ),
        subtitle: Text(_formatDate(draft.date), style: const TextStyle(fontSize: 12)),
        trailing: Text('${draft.amount}원', style: const TextStyle(fontWeight: FontWeight.w600)),
        children: [_buildDraftEditor(draft)],
      ),
    );
  }

  /// type별로 다른 빠른 수정 UI (nature/emotionTag or incomeSource or 저축 카테고리)
  Widget _buildDraftEditor(ParsedRecordDraft draft) {
    switch (draft.type) {
      case TransactionType.expense:
        return Wrap(
          spacing: 6,
          children: ExpenseNature.values.map((n) {
            final selected = draft.nature == n;
            return ChoiceChip(
              label: Text(n.label, style: const TextStyle(fontSize: 12)),
              selected: selected,
              onSelected: (_) => setState(() => draft.nature = n),
            );
          }).toList(),
        );
      case TransactionType.income:
        return Wrap(
          spacing: 6,
          children: IncomeSource.values.map((s) {
            final selected = draft.incomeSource == s;
            return ChoiceChip(
              label: Text(s.label, style: const TextStyle(fontSize: 12)),
              selected: selected,
              onSelected: (_) => setState(() => draft.incomeSource = s),
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
          children: savingOptions.map((o) {
            final selected = draft.categoryId == o.$1;
            return ChoiceChip(
              label: Text(o.$2, style: const TextStyle(fontSize: 12)),
              selected: selected,
              onSelected: (_) => setState(() => draft.categoryId = o.$1),
            );
          }).toList(),
        );
    }
  }

  String _formatDate(DateTime date) {
    final today = DateTime.now();
    if (date.year == today.year && date.month == today.month && date.day == today.day) {
      return '오늘';
    }
    return '${date.month}/${date.day}';
  }
}