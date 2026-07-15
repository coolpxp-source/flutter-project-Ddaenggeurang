import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../services/community_service.dart';
import '../../services/image_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PostWriteScreen extends StatefulWidget {
  final String initialCategory;
  const PostWriteScreen({super.key, this.initialCategory = '자유'});

  @override
  State<PostWriteScreen> createState() => _PostWriteScreenState();
}

class _PostWriteScreenState extends State<PostWriteScreen> {
  final _service = CommunityService();
  final _imageService = ImageService();
  final _contentController = TextEditingController();
  final _contentFocusNode = FocusNode();
  final _tagInputController = TextEditingController();
  late String _category = widget.initialCategory;
  bool _saving = false;

  static const _green = Color(0xFFFF8A3D);
  static const _greenLight = Color(0xFFFFF0E8);
  static const _gradientStart = Color(0xFFFFA351);
  static const _gradientEnd = Color(0xFFFF6B1A);

  static const _categories = ['절약팁', '소비고민', '자유', '거지방'];

  static const _quickEmojis = [
    '😊', '😂', '🥲', '😭', '😅', '😍', '🥹', '😤',
    '👍', '👏', '🙏', '🔥', '💸', '💰', '🐷', '💪',
    '❤️', '😢', '😱', '🤔', '✅', '❌', '⭐', '🎉',
  ];

  final String _myId = FirebaseAuth.instance.currentUser!.uid;
  Future<String> _getAuthorName() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(_myId).get();
      final nickname = doc.data()?['nickname'] as String?;
      if (nickname != null && nickname.trim().isNotEmpty) return nickname;
    } catch (_) {}
    return FirebaseAuth.instance.currentUser?.displayName ?? '나';
  }

  final List<File> _selectedImages = [];
  final List<String> _hashtags = [];

  IconData _categoryIcon(String cat) {
    switch (cat) {
      case '절약팁':
        return Icons.savings_outlined;
      case '소비고민':
        return Icons.psychology_alt_outlined;
      case '자유':
        return Icons.chat_bubble_outline;
      case '거지방':
        return Icons.money_off_rounded;
      default:
        return Icons.circle_outlined;
    }
  }

  Color _categoryColor(String cat) {
    switch (cat) {
      case '절약팁':
        return const Color(0xFF4CAF87);
      case '소비고민':
        return const Color(0xFF9B7EDE);
      case '자유':
        return const Color(0xFF5B9BD5);
      case '거지방':
        return const Color(0xFFE5735A);
      default:
        return _green;
    }
  }

  Color _categoryColorLight(String cat) {
    switch (cat) {
      case '절약팁':
        return const Color(0xFFE6F5EF);
      case '소비고민':
        return const Color(0xFFF1ECFA);
      case '자유':
        return const Color(0xFFEAF2FA);
      case '거지방':
        return const Color(0xFFFBECE9);
      default:
        return _greenLight;
    }
  }

  Future<void> _pickImage() async {
    if (_selectedImages.length >= 5) return;
    final file = await _imageService.pickImage();
    if (file != null) {
      setState(() => _selectedImages.add(file));
    }
  }

  void _removeImage(int index) {
    setState(() => _selectedImages.removeAt(index));
  }

  // 커서 위치에 이모지 삽입
  void _insertEmoji(String emoji) {
    final text = _contentController.text;
    final selection = _contentController.selection;

    final start = selection.start >= 0 ? selection.start : text.length;
    final end = selection.end >= 0 ? selection.end : text.length;

    final newText = text.replaceRange(start, end, emoji);
    final newCursorPos = start + emoji.length;

    _contentController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newCursorPos),
    );
  }

  void _openEmojiPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('이모지',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
              const SizedBox(height: 16),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _quickEmojis.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 8,
                  mainAxisSpacing: 4,
                  crossAxisSpacing: 4,
                ),
                itemBuilder: (context, index) {
                  final emoji = _quickEmojis[index];
                  return GestureDetector(
                    onTap: () {
                      _insertEmoji(emoji);
                      Navigator.pop(context);
                    },
                    child: Center(
                      child: Text(emoji, style: const TextStyle(fontSize: 22)),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // 게시판(카테고리) 선택 바텀시트
  void _openCategoryPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('게시판을 선택하세요',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
              const SizedBox(height: 16),
              ..._categories.map((cat) {
                final selected = cat == _category;
                final color = _categoryColor(cat);
                final colorLight = _categoryColorLight(cat);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: GestureDetector(
                    onTap: () {
                      setState(() => _category = cat);
                      Navigator.pop(context);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: selected ? colorLight : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: selected ? color.withOpacity(0.4) : Colors.grey[200]!,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                            alignment: Alignment.center,
                            child: Icon(_categoryIcon(cat), color: Colors.white, size: 16),
                          ),
                          const SizedBox(width: 12),
                          Text(cat,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                                color: selected ? color : Colors.black87,
                              )),
                          const Spacer(),
                          if (selected) Icon(Icons.check_circle, color: color, size: 20),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  // 해시태그 입력 바텀시트
  void _openTagInput() {
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
                  const Text('태그 추가',
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

  Future<void> _submit() async {
    if (_contentController.text.trim().isEmpty) return;
    setState(() => _saving = true);

    try {
      final authorName = await _getAuthorName();

      final List<String> imageUrls = [];
      for (final file in _selectedImages) {
        final url = await _imageService.uploadImage(file, 'communityPosts');
        imageUrls.add(url);
      }

      await _service.createPost(
        authorId: _myId,
        authorName: authorName,
        category: _category,
        content: _contentController.text.trim(),
        imageUrls: imageUrls,
        hashtags: _hashtags,
      );

      if (context.mounted) Navigator.pop(context);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('등록 실패: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _contentController.dispose();
    _contentFocusNode.dispose();
    _tagInputController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final catColor = _categoryColor(_category);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8F9FA),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('글쓰기', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: GestureDetector(
                onTap: _saving ? null : _submit,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: _saving
                          ? [Colors.grey[300]!, Colors.grey[300]!]
                          : const [_gradientStart, _gradientEnd],
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _saving ? '등록 중...' : '등록',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 게시판(카테고리) 선택
            GestureDetector(
              onTap: _openCategoryPicker,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(color: catColor, shape: BoxShape.circle),
                      alignment: Alignment.center,
                      child: Icon(_categoryIcon(_category), color: Colors.white, size: 15),
                    ),
                    const SizedBox(width: 10),
                    Text(_category,
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.bold, color: catColor)),
                    const Spacer(),
                    Icon(Icons.keyboard_arrow_down, color: Colors.grey[400]),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // 본문 입력 카드
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: _contentController,
                        focusNode: _contentFocusNode,
                        maxLines: null,
                        minLines: 6,
                        style: const TextStyle(fontSize: 14, height: 1.5),
                        decoration: InputDecoration(
                          hintText: '무슨 얘기를 나눠볼까요?',
                          border: InputBorder.none,
                          hintStyle: TextStyle(color: Colors.grey[400]),
                        ),
                      ),

                      if (_hashtags.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Wrap(
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
                      ],

                      if (_selectedImages.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 90,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: _selectedImages.length,
                            separatorBuilder: (_, __) => const SizedBox(width: 8),
                            itemBuilder: (context, index) {
                              return Stack(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: Image.file(
                                      _selectedImages[index],
                                      width: 90,
                                      height: 90,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  Positioned(
                                    right: 4,
                                    top: 4,
                                    child: GestureDetector(
                                      onTap: () => _removeImage(index),
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
                              );
                            },
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // 하단 툴바
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: _selectedImages.length >= 5 ? null : _pickImage,
                    child: Row(
                      children: [
                        Icon(
                          Icons.camera_alt_outlined,
                          size: 20,
                          color: _selectedImages.length >= 5 ? Colors.grey[300] : catColor,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _selectedImages.length >= 5
                              ? '최대 5장'
                              : '사진 (${_selectedImages.length}/5)',
                          style: TextStyle(
                            fontSize: 12,
                            color: _selectedImages.length >= 5 ? Colors.grey[400] : catColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: _openEmojiPicker,
                    child: Icon(Icons.emoji_emotions_outlined, size: 20, color: Colors.grey[600]),
                  ),
                  const SizedBox(width: 16),
                  GestureDetector(
                    onTap: _openTagInput,
                    child: Row(
                      children: [
                        Icon(Icons.sell_outlined, size: 20, color: Colors.grey[600]),
                        if (_hashtags.isNotEmpty) ...[
                          const SizedBox(width: 4),
                          Text('${_hashtags.length}', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}