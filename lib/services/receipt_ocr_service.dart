import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// 영수증 이미지에서 텍스트만 추출하는 역할까지만 담당합니다.
/// (상호명/금액 등 구조화는 AiService.parseBulkText가 담당 — 책임 분리)
class ReceiptOcrService {
  final _recognizer = TextRecognizer(script: TextRecognitionScript.korean);

  Future<String> extractText(File imageFile) async {
    final inputImage = InputImage.fromFile(imageFile);
    final result = await _recognizer.processImage(inputImage);
    return result.text;
  }

  void dispose() => _recognizer.close();
}