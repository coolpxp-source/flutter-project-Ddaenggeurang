import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/category_model.dart' show TransactionType;
import '../../models/expense_model.dart';
import '../../models/income_model.dart';
import '../../models/saving_model.dart';
import '../../services/expense_service.dart';
import '../../services/income_service.dart';
import '../../services/saving_service.dart';
import '../../services/ai_service.dart';
import 'parsed_record_draft.dart';

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
                hintText: '예: 7월12일 편의점 3,400 메모 계란이랑 마이쮸\n7월13일 카페 5,600 메모 할리스\n7월14일 택시 11,000',
                hintStyle: const TextStyle(fontSize: 13, color: Colors.grey),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
            const SizedBox(height: 12),
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
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                )
                    : const Text('AI로 분리하기', style: TextStyle(color: Colors.white)),
              ),
            ),
            if (_drafts.isNotEmpty) ...[
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('인식된 항목 ${_drafts.length}개', style: const TextStyle(fontWeight: FontWeight.bold)),
                  const Text('틀린 부분은 눌러서 수정', style: TextStyle(fontSize: 12, color: Colors.grey)),
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
                  child: Text('$_selectedCount개 항목 전체 저장', style: const TextStyle(color: Colors.white, fontSize: 16)),
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
            // 💡 화면에 띄울 때만 memo와 categoryName을 가운데 점(·)으로 이어붙여 줍니다!
            Expanded(child: Text('${draft.memo} · ${draft.categoryName}', overflow: TextOverflow.ellipsis)),
          ],
        ),
        subtitle: Text(_formatDate(draft.date), style: const TextStyle(fontSize: 12)),
        trailing: Text('${draft.amount}원', style: const TextStyle(fontWeight: FontWeight.w600)),
        children: [_buildDraftEditor(draft)],
      ),
    );
  }

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
        const incomeOptions = [
          ('salary', '월급'),
          ('freelance', '프리랜서'),
          ('allowance', '용돈'),
          ('etc', '기타'),
        ];
        return Wrap(
          spacing: 6,
          children: incomeOptions.map((o) {
            final selected = draft.categoryId == o.$1;
            return ChoiceChip(
              label: Text(o.$2, style: const TextStyle(fontSize: 12)),
              selected: selected,
              onSelected: (_) => setState(() => draft.categoryId = o.$1),
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