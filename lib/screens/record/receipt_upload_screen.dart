import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../utils/app_colors.dart';
import '../../widgets/common/ddaeng_modal.dart';
import '../../services/ai_service.dart';
import '../../services/receipt_ocr_service.dart';
import 'draft_mapper.dart';
import 'draft_review_screen.dart';

/// "영수증 촬영 업로드" 전용 진입 화면.
/// 카메라/갤러리로 영수증을 고르면 OCR → AI 파싱 → 확인 화면(DraftReviewScreen) 순으로 진행됩니다.
class ReceiptUploadScreen extends StatefulWidget {
  const ReceiptUploadScreen({super.key});

  @override
  State<ReceiptUploadScreen> createState() => _ReceiptUploadScreenState();
}

class _ReceiptUploadScreenState extends State<ReceiptUploadScreen> {
  final _picker = ImagePicker();
  final _ocrService = ReceiptOcrService();
  final _aiService = AiService();

  File? _previewImage;
  String? _extractedText;
  bool _isProcessing = false;

  @override
  void dispose() {
    _ocrService.dispose();
    super.dispose();
  }

  Future<void> _pickAndExtract(ImageSource source) async {
    final User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      await DdaengModal.alert(context, title: '로그인이 필요해요', message: '로그인 후 이용 가능합니다.', type: ModalType.warning);
      return;
    }

    final XFile? picked = await _picker.pickImage(source: source, imageQuality: 85);
    if (picked == null) return;

    setState(() {
      _previewImage = File(picked.path);
      _isProcessing = true;
      _extractedText = null;
    });

    try {
      final text = await _ocrService.extractText(File(picked.path));
      if (!mounted) return;

      if (text.trim().isEmpty) {
        setState(() => _isProcessing = false);
        await DdaengModal.alert(context,
            title: '텍스트를 못 읽었어요', message: '더 밝은 곳에서 다시 찍어주세요.', type: ModalType.warning);
        return;
      }

      setState(() {
        _extractedText = text;
        _isProcessing = false;
      });
    } catch (e) {
      debugPrint('OCR 에러: $e');
      if (mounted) {
        setState(() => _isProcessing = false);
        await DdaengModal.alert(context, title: '이미지를 처리하지 못했어요', message: '$e', type: ModalType.danger);
      }
    }
  }

  Future<void> _parseAndReview() async {
    if (_extractedText == null || _extractedText!.trim().isEmpty) return;

    setState(() => _isProcessing = true);
    try {
      final parsedList = await _aiService.parseBulkText(_extractedText!);
      final drafts = mapParsedExpensesToDrafts(parsedList);

      if (!mounted) return;
      setState(() => _isProcessing = false);

      final saved = await Navigator.push<bool>(
        context,
        MaterialPageRoute(builder: (_) => DraftReviewScreen(initialDrafts: drafts)),
      );
      if (saved == true && mounted) {
        setState(() {
          _previewImage = null;
          _extractedText = null;
        });
      }
    } catch (e) {
      debugPrint('AI 파싱 에러: $e');
      if (mounted) {
        setState(() => _isProcessing = false);
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
        title: const Text('영수증 촬영 업로드',
            style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.ink)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_previewImage == null) ...[
              // ── 안내 + 촬영/갤러리 버튼 ──
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: AppColors.bg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    Icon(Icons.receipt_long_rounded, size: 44, color: AppColors.expenseDeep.withValues(alpha: 0.7)),
                    const SizedBox(height: 14),
                    const Text('영수증을 촬영하거나\n갤러리에서 선택해주세요',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.ink)),
                    const SizedBox(height: 6),
                    const Text('AI가 항목별로 자동 정리해드려요',
                        style: TextStyle(fontSize: 12, color: AppColors.inkSub)),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton.icon(
                  onPressed: () => _pickAndExtract(ImageSource.camera),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.ink,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  icon: const Icon(Icons.camera_alt_rounded, size: 18),
                  label: const Text('카메라로 촬영', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: OutlinedButton.icon(
                  onPressed: () => _pickAndExtract(ImageSource.gallery),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.ink,
                    side: const BorderSide(color: Color(0xFFE8ECF3), width: 1.4),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  icon: const Icon(Icons.photo_library_outlined, size: 18),
                  label: const Text('갤러리에서 선택', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                ),
              ),
            ] else ...[
              // ── 선택된 이미지 미리보기 + OCR 결과 ──
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.file(_previewImage!, height: 220, width: double.infinity, fit: BoxFit.cover),
              ),
              const SizedBox(height: 16),
              if (_isProcessing)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator(color: AppColors.expense)),
                )
              else if (_extractedText != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.bg,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('인식된 텍스트 (틀린 부분은 아래에서 직접 수정 가능)',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.inkSub)),
                      const SizedBox(height: 10),
                      TextField(
                        controller: TextEditingController(text: _extractedText)
                          ..selection = TextSelection.collapsed(offset: _extractedText!.length),
                        maxLines: 6,
                        style: const TextStyle(fontSize: 13, color: AppColors.ink),
                        onChanged: (v) => _extractedText = v,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.all(12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton.icon(
                    onPressed: _parseAndReview,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.ink,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                    label: const Text('AI로 분리하기', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => setState(() {
                    _previewImage = null;
                    _extractedText = null;
                  }),
                  child: const Text('다시 찍기', style: TextStyle(color: AppColors.inkSub)),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}