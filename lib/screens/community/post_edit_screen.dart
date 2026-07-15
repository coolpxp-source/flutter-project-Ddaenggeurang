import 'dart:io';
import 'package:flutter/material.dart';
import '../../models/community_post_model.dart';
import '../../services/community_service.dart';
import '../../services/image_service.dart';

class PostEditScreen extends StatefulWidget {
  final CommunityPost post;
  const PostEditScreen({super.key, required this.post});

  @override
  State<PostEditScreen> createState() => _PostEditScreenState();
}

class _PostEditScreenState extends State<PostEditScreen> {
  final _service = CommunityService();
  final _imageService = ImageService();
  late final TextEditingController _contentController;
  final _tagInputController = TextEditingController();
  bool _saving = false;
  static const _green = Color(0xFFFF9166);
  static const _greenLight = Color(0xFFFFF0E8);

  // 기존에 이미 올라가 있던 이미지 URL (남아있는 것만 유지)
  late List<String> _existingImageUrls;
  // 새로 추가한 이미지 파일
  final List<File> _newImages = [];

  // 기존 해시태그를 그대로 불러와서 편집 가능하게
  late List<String> _hashtags;

  int get _totalImageCount => _existingImageUrls.length + _newImages.length;

  @override
  void initState() {
    super.initState();
    _contentController = TextEditingController(text: widget.post.content);
    _existingImageUrls = List<String>.from(widget.post.imageUrls);
    _hashtags = List<String>.from(widget.post.hashtags);
  }

  @override
  void dispose() {
    _contentController.dispose();
    _tagInputController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    if (_totalImageCount >= 5) return;
    final file = await _imageService.pickImage();
    if (file != null) {
      setState(() => _newImages.add(file));
    }
  }

  void _removeExisting(int index) {
    setState(() => _existingImageUrls.removeAt(index));
  }

  void _removeNew(int index) {
    setState(() => _newImages.removeAt(index));
  }

  // 해시태그 편집 바텀시트
  void _openTagEditor() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 28),
          child: StatefulBuilder(
            builder: (context, setSheetState) {
              void addTag() {
                var tag = _tagInputController.text.trim();
                if (tag.isEmpty) return;
                tag = tag.replaceAll('#', '');
                if (_hashtags.contains(tag) || _hashtags.length >= 5) {
                  _tagInputController.clear();
                  return;
                }
                setSheetState(() => _hashtags.add(tag));
                setState(() {});
                _tagInputController.clear();
              }

              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('태그 수정',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
                  const SizedBox(height: 4),
                  Text('최대 5개까지 추가할 수 있어요',
                      style: TextStyle(fontSize: 12, color: Colors.grey[400])),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: _greenLight,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: TextField(
                            controller: _tagInputController,
                            style: const TextStyle(fontSize: 13),
                            decoration: const InputDecoration(
                              hintText: '태그를 입력하고 추가를 눌러주세요',
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(vertical: 12),
                            ),
                            onSubmitted: (_) => addTag(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: addTag,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: _green,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text('추가',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  if (_hashtags.isNotEmpty)
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _hashtags.map((tag) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: _greenLight,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('#$tag', style: const TextStyle(fontSize: 12, color: _green, fontWeight: FontWeight.w500)),
                              const SizedBox(width: 4),
                              GestureDetector(
                                onTap: () {
                                  setSheetState(() => _hashtags.remove(tag));
                                  setState(() {});
                                },
                                child: const Icon(Icons.close, size: 14, color: _green),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _save() async {
    if (_contentController.text.trim().isEmpty) return;
    setState(() => _saving = true);

    try {
      // 새로 추가한 이미지만 Storage에 업로드
      final List<String> uploadedUrls = [];
      for (final file in _newImages) {
        final url = await _imageService.uploadImage(file, 'communityPosts');
        uploadedUrls.add(url);
      }

      final finalImageUrls = [..._existingImageUrls, ...uploadedUrls];

      await _service.updatePost(
        widget.post.postId,
        _contentController.text.trim(),
        imageUrls: finalImageUrls,
        hashtags: _hashtags,
      );

      if (context.mounted) Navigator.pop(context);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('수정 실패: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('게시글 수정', style: TextStyle(color: Colors.black)),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: Text(
              _saving ? '저장 중...' : '저장',
              style: const TextStyle(color: _green, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _contentController,
                      maxLines: 6,
                      decoration: InputDecoration(
                        hintText: '무슨 얘기를 나눠볼까요?',
                        border: InputBorder.none,
                        hintStyle: TextStyle(color: Colors.grey[400]),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // 해시태그 표시 및 편집
                    Row(
                      children: [
                        Expanded(
                          child: Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: _hashtags.map((tag) {
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _greenLight,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Text('#$tag',
                                    style: const TextStyle(fontSize: 11, color: _green, fontWeight: FontWeight.w500)),
                              );
                            }).toList(),
                          ),
                        ),
                        GestureDetector(
                          onTap: _openTagEditor,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: _greenLight,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.sell_outlined, size: 14, color: _green),
                                const SizedBox(width: 4),
                                Text('태그 편집', style: const TextStyle(fontSize: 11, color: _green)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // 기존 이미지 + 새 이미지 미리보기 (같이 표시)
                    if (_existingImageUrls.isNotEmpty || _newImages.isNotEmpty)
                      SizedBox(
                        height: 90,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: [
                            ..._existingImageUrls.asMap().entries.map((entry) {
                              return Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: Stack(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: Image.network(
                                        entry.value,
                                        width: 90,
                                        height: 90,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                    Positioned(
                                      right: 4,
                                      top: 4,
                                      child: GestureDetector(
                                        onTap: () => _removeExisting(entry.key),
                                        child: Container(
                                          padding: const EdgeInsets.all(2),
                                          decoration: const BoxDecoration(
                                            color: Colors.black54,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(Icons.close, size: 14, color: Colors.white),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                            ..._newImages.asMap().entries.map((entry) {
                              return Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: Stack(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: Image.file(
                                        entry.value,
                                        width: 90,
                                        height: 90,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                    Positioned(
                                      right: 4,
                                      top: 4,
                                      child: GestureDetector(
                                        onTap: () => _removeNew(entry.key),
                                        child: Container(
                                          padding: const EdgeInsets.all(2),
                                          decoration: const BoxDecoration(
                                            color: Colors.black54,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(Icons.close, size: 14, color: Colors.white),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),

            Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Colors.grey[200]!)),
              ),
              child: GestureDetector(
                onTap: _totalImageCount >= 5 ? null : _pickImage,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: _totalImageCount >= 5 ? Colors.grey[200] : _greenLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.image_outlined, size: 18,
                          color: _totalImageCount >= 5 ? Colors.grey : _green),
                      const SizedBox(width: 6),
                      Text(
                        _totalImageCount >= 5 ? '최대 5장' : '사진 추가 ($_totalImageCount/5)',
                        style: TextStyle(fontSize: 13, color: _totalImageCount >= 5 ? Colors.grey : _green),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}