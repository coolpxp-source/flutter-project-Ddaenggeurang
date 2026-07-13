import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class MissionProofUploadScreen extends StatefulWidget {
  const MissionProofUploadScreen({
    super.key,
    this.missionTitle = '절약 인증 사진 올리기',
  });

  final String missionTitle;

  @override
  State<MissionProofUploadScreen> createState() =>
      _MissionProofUploadScreenState();
}

class _MissionProofUploadScreenState
    extends State<MissionProofUploadScreen> {
  final TextEditingController _descriptionController =
  TextEditingController();

  final ImagePicker _imagePicker = ImagePicker();

  XFile? _selectedImage;

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: source,
        imageQuality: 85,
      );

      if (image == null || !mounted) {
        return;
      }

      setState(() {
        _selectedImage = image;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            source == ImageSource.camera
                ? '카메라를 실행하지 못했습니다.'
                : '이미지를 불러오지 못했습니다.',
          ),
        ),
      );

      debugPrint('이미지 선택 오류: $error');
    }
  }

  void _showImageSourceSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) {
        return SafeArea(
          child: Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 18,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD9D9D9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  '인증 사진 추가',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: _buildImageSourceButton(
                        icon: Icons.camera_alt_rounded,
                        label: '사진 촬영',
                        onTap: () {
                          Navigator.pop(bottomSheetContext);
                          _pickImage(ImageSource.camera);
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildImageSourceButton(
                        icon: Icons.photo_library_rounded,
                        label: '갤러리 선택',
                        onTap: () {
                          Navigator.pop(bottomSheetContext);
                          _pickImage(ImageSource.gallery);
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildImageSourceButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF1F6),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: const Color(0xFFFFD3E2),
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: const Color(0xFFE66A9F),
              size: 30,
            ),
            const SizedBox(height: 9),
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFF4B4146),
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.white,
        leading: IconButton(
          onPressed: () {
            Navigator.pop(context);
          },
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          hoverColor: Colors.transparent,
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Color(0xFF333333),
          ),
        ),
        title: const Text(
          '사진 인증',
          style: TextStyle(
            color: Color(0xFF222222),
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildMissionInformation(),
              const SizedBox(height: 28),

              const Text(
                '인증 사진',
                style: TextStyle(
                  color: Color(0xFF222222),
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),

              _buildImageArea(),
              const SizedBox(height: 28),

              const Text(
                '인증 설명',
                style: TextStyle(
                  color: Color(0xFF222222),
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),

              _buildDescriptionField(),
              const SizedBox(height: 8),

              const Align(
                alignment: Alignment.centerRight,
                child: Text(
                  '최대 200자',
                  style: TextStyle(
                    color: Color(0xFF999999),
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(height: 28),

              _buildGuideBox(),
              const SizedBox(height: 32),

              _buildSubmitButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMissionInformation() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFFFFE1EC),
            Color(0xFFF0E4FF),
          ],
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.savings_rounded,
              color: Color(0xFFE66A9F),
              size: 29,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '진행 중인 미션',
                  style: TextStyle(
                    color: Color(0xFF8B6B79),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  widget.missionTitle,
                  style: const TextStyle(
                    color: Color(0xFF332A30),
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                const Text(
                  '절약한 내용을 사진으로 인증해 주세요.',
                  style: TextStyle(
                    color: Color(0xFF786C72),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageArea() {
    return InkWell(
      onTap: _showImageSourceSheet,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: double.infinity,
        height: 220,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFFFFB8D0),
            width: 1.5,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: _selectedImage != null
              ? Stack(
            fit: StackFit.expand,
            children: [
              Image.file(
                File(_selectedImage!.path),
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return const Center(
                    child: Text('이미지를 표시할 수 없습니다.'),
                  );
                },
              ),
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    onPressed: _showImageSourceSheet,
                    tooltip: '사진 변경',
                    icon: const Icon(
                      Icons.edit_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ],
          )
              : const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.add_photo_alternate_outlined,
                color: Color(0xFFE66A9F),
                size: 46,
              ),
              SizedBox(height: 12),
              Text(
                '사진을 선택해 주세요',
                style: TextStyle(
                  color: Color(0xFF4B4146),
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 6),
              Text(
                '갤러리에서 인증 사진을 가져올 수 있어요.',
                style: TextStyle(
                  color: Color(0xFF999096),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDescriptionField() {
    return TextField(
      controller: _descriptionController,
      maxLength: 200,
      maxLines: 5,
      decoration: InputDecoration(
        counterText: '',
        hintText: '어떤 절약을 실천했는지 간단히 작성해 주세요.',
        hintStyle: const TextStyle(
          color: Color(0xFFB5ADB1),
          fontSize: 14,
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.all(16),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(
            color: Color(0xFFFFD8E5),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(
            color: Color(0xFFE66A9F),
            width: 1.5,
          ),
        ),
      ),
    );
  }

  Widget _buildGuideBox() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF0F5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            color: Color(0xFFE66A9F),
            size: 20,
          ),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              '제출한 인증은 관리자 확인 후 승인됩니다. '
                  '미션과 관계없는 사진은 승인이 거절될 수 있습니다.',
              style: TextStyle(
                color: Color(0xFF755B66),
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: () {
          // 다음 단계에서 Mock 제출 기능 연결
          debugPrint('인증 제출 버튼 클릭');
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFE66A9F),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        child: const Text(
          '인증 제출하기',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}