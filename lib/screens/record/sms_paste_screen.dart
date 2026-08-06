import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../utils/app_colors.dart';
import '../../widgets/common/ddaeng_modal.dart';
import '../../services/ai_service.dart';
import 'category_matcher.dart';
import 'draft_mapper.dart';
import 'draft_review_screen.dart';
import 'point_detector.dart';

/// "문자내역 붙여넣기" 전용 진입 화면.
/// 카드/은행 알림 문자를 복사해서 붙여넣으면 AI 파싱 → 확인 화면으로 진행됩니다.
class SmsPasteScreen extends StatefulWidget {
  const SmsPasteScreen({super.key});

  @override
  State<SmsPasteScreen> createState() => _SmsPasteScreenState();
}

class _SmsPasteScreenState extends State<SmsPasteScreen> {
  final _textController = TextEditingController();
  final _aiService = AiService();
  bool _isParsing = false;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text == null || data!.text!.trim().isEmpty) {
      if (mounted) {
        await DdaengModal.alert(context,
            title: '클립보드가 비어있어요', message: '문자 앱에서 내용을 먼저 복사해주세요.', type: ModalType.info);
      }
      return;
    }
    setState(() {
      final prefix = _textController.text.trim().isEmpty ? '' : '${_textController.text.trim()}\n';
      _textController.text = '$prefix${data.text!.trim()}';
    });
  }

  Future<void> _onTapParse() async {
    final User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      await DdaengModal.alert(context, title: '로그인이 필요해요', message: '로그인 후 이용 가능합니다.', type: ModalType.warning);
      return;
    }

    if (_textController.text.trim().isEmpty) {
      await DdaengModal.alert(context,
          title: '입력을 확인해주세요', message: '문자 내용을 붙여넣어주세요.', type: ModalType.warning);
      return;
    }

    setState(() => _isParsing = true);

    try {
      final text = _textController.text.trim();

      // 1. 카테고리 먼저 로드
      final categories = await loadAllCategoryOptions(userId: currentUser.uid);

      // 2. 유저 커스텀 지출 카테고리 이름만 추출
      final userExpenseCategoryNames = categories.expense.map((e) => e.name).toList();

      // 3. AI 파싱 시 userCategories 전달
      final parsedList = await _aiService.parseBulkText(
        text,
        userCategories: userExpenseCategoryNames,
      );

      final drafts = await mapParsedExpensesToDrafts(
        parsedList,
        categories: categories,
      );

      final points = detectPoints(_textController.text);

      if (!mounted) return;
      setState(() => _isParsing = false);

      final saved = await Navigator.push<bool>(
        context,
        MaterialPageRoute(builder: (_) => DraftReviewScreen(
            initialDrafts: drafts,
            categories: categories,
            detectedPoints: points // 포인트 전달
        )),
      );
      if (saved == true && mounted) {
        _textController.clear();
      }
    } catch (e) {
      debugPrint('AI 파싱 에러: $e');
      setState(() => _isParsing = false);
      if (mounted) {
        await DdaengModal.alert(context, title: 'AI 분석에 실패했어요', message: '$e', type: ModalType.danger);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('문자내역 붙여넣기',
            style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.ink)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: AppColors.cardShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: AppColors.expense.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: const Icon(Icons.sms_outlined, size: 14, color: AppColors.expenseDeep),
                      ),
                      const SizedBox(width: 8),
                      const Text('카드/은행 알림 문자 붙여넣기',
                          style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: AppColors.ink)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Padding(
                    padding: EdgeInsets.only(left: 34),
                    child: Text(
                      '문자 앱에서 내용을 복사한 뒤 아래에 붙여넣어주세요',
                      style: TextStyle(fontSize: 12, color: AppColors.inkSub),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _textController,
                    maxLines: 6,
                    style: const TextStyle(fontSize: 13.5, color: AppColors.ink),
                    decoration: InputDecoration(
                      hintText: '예: [Web발신] 신한카드 승인 12,000원 스타벅스 07/28 14:22',
                      hintStyle: const TextStyle(fontSize: 12.5, color: AppColors.inkSub),
                      filled: true,
                      fillColor: AppColors.bg,
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
                        borderSide: const BorderSide(color: AppColors.expense, width: 1.6),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: _pasteFromClipboard,
                      icon: const Icon(Icons.content_paste_rounded, size: 16),
                      label: const Text('클립보드에서 붙여넣기'),
                      style: TextButton.styleFrom(foregroundColor: AppColors.expenseDeep),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: _isParsing ? null : _onTapParse,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.ink,
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
          ],
        ),
      ),
    );
  }
}