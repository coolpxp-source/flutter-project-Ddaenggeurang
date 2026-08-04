import 'package:flutter/material.dart';
import '../../utils/app_colors.dart';
import '../../widgets/common/ddaeng_modal.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/ai_service.dart';
import 'category_matcher.dart';
import 'draft_mapper.dart';
import 'draft_review_screen.dart';

/// "한번에 기록하기" 전용 화면.
/// (영수증 촬영은 receipt_upload_screen, 문자 붙여넣기는 sms_paste_screen으로 분리됨)
class BulkRecordScreen extends StatefulWidget {
  const BulkRecordScreen({super.key});

  @override
  State<BulkRecordScreen> createState() => _BulkRecordScreenState();
}

class _BulkRecordScreenState extends State<BulkRecordScreen> {
  final _textController = TextEditingController();
  final _aiService = AiService();

  bool _isParsing = false;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _onTapParse() async {
    final User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      await DdaengModal.alert(context, title: '로그인이 필요해요', message: '로그인 후 이용 가능합니다.', type: ModalType.warning);
      return;
    }

    if (_textController.text.trim().isEmpty) {
      await DdaengModal.alert(context,
          title: '입력을 확인해주세요', message: '내역 텍스트를 입력해주세요.', type: ModalType.warning);
      return;
    }

    setState(() => _isParsing = true);

    try {
      final text = _textController.text.trim();
      final parsedList = await _aiService.parseBulkText(text);
      final categories = await loadAllCategoryOptions(userId: currentUser.uid);
      final drafts = await mapParsedExpensesToDrafts(
        parsedList,
        categories: categories,
      );

      if (!mounted) return;
      setState(() => _isParsing = false);

      final saved = await Navigator.push<bool>(
        context,
        MaterialPageRoute(builder: (_) => DraftReviewScreen(
          initialDrafts: drafts,
          categories: categories,
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

  // ─────────────────────── 스타일 헬퍼 ───────────────────────

  Widget _sectionCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppColors.cardShadow,
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
              color: iconBg ?? AppColors.expense.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 14, color: iconColor ?? AppColors.expenseDeep),
          ),
          const SizedBox(width: 8),
        ],
        Text(
          text,
          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: AppColors.ink),
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
        foregroundColor: AppColors.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('한번에 기록하기',
            style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.ink)),
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
                  _sectionLabel('밀린 내역 직접 입력',
                      icon: Icons.auto_awesome_rounded,
                      iconColor: AppColors.expenseDeep,
                      iconBg: AppColors.expense.withValues(alpha: 0.15)),
                  const SizedBox(height: 4),
                  const Padding(
                    padding: EdgeInsets.only(left: 34),
                    child: Text(
                      '밀린 지출을 한꺼번에 입력하면 AI가 정리해드려요',
                      style: TextStyle(fontSize: 12, color: AppColors.inkSub),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _textController,
                    maxLines: 6,
                    style: const TextStyle(fontSize: 13.5, color: AppColors.ink),
                    decoration: InputDecoration(
                      hintText: '예: 7월12일 편의점 3,400 메모 계란이랑 마이쮸\n7월13일 카페 5,600 메모 할리스\n7월14일 택시 11,000',
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