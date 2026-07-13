import 'package:flutter/material.dart';

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

  // 다음 단계에서 실제 선택한 이미지 정보를 저장할 예정
  bool _hasSelectedImage = false;

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
      onTap: () {
        // 다음 단계에서 이미지 선택 기능 연결
        debugPrint('이미지 선택 버튼 클릭');
      },
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
        child: _hasSelectedImage
            ? const Center(
          child: Text('선택한 이미지 미리보기 영역'),
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