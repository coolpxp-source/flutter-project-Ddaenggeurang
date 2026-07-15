import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../services/community_service.dart';

class PostWriteScreen extends StatefulWidget {
  const PostWriteScreen({super.key});

  @override
  State<PostWriteScreen> createState() => _PostWriteScreenState();
}

class _PostWriteScreenState extends State<PostWriteScreen> {
  final _service = CommunityService();
  final _contentController = TextEditingController();
  String _category = '자유';
  bool _saving = false;
  static const _green = Color(0xFFFF9166);

  // TODO: 로그인 연결되면 교체
  final String _myId = FirebaseAuth.instance.currentUser!.uid;
  final String _myName = FirebaseAuth.instance.currentUser?.displayName ?? '나';

  Future<void> _submit() async {
    if (_contentController.text.trim().isEmpty) return;
    setState(() => _saving = true);

    await _service.createPost(
      authorId: _myId,
      authorName: _myName,
      category: _category,
      content: _contentController.text.trim(),
    );

    setState(() => _saving = false);
    if (context.mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('글쓰기', style: TextStyle(color: Colors.black)),
        actions: [
          TextButton(
            onPressed: _saving ? null : _submit,
            child: Text(
              _saving ? '등록 중...' : '등록',
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
            Wrap(
              spacing: 8,
              children: ['절약팁', '소비고민', '자유', '거지방'].map((cat) {
                final selected = cat == _category;
                return ChoiceChip(
                  label: Text(cat),
                  selected: selected,
                  onSelected: (_) => setState(() => _category = cat),
                  selectedColor: _green,
                  labelStyle: TextStyle(color: selected ? Colors.white : Colors.black87),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _contentController,
              maxLines: 10,
              decoration: InputDecoration(
                hintText: '무슨 얘기를 나눠볼까요?',
                border: InputBorder.none,
                hintStyle: TextStyle(color: Colors.grey[400]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}