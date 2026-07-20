import 'dart:io';
import '../../models/market_product_model.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../services/market_service.dart';
import '../../services/image_service.dart';

class ProductRegisterScreen extends StatefulWidget {
  final MarketProduct? existingProduct;

  const ProductRegisterScreen({super.key, this.existingProduct});

  @override
  State<ProductRegisterScreen> createState() => _ProductRegisterScreenState();
}

class _ProductRegisterScreenState extends State<ProductRegisterScreen> {
  final _service = MarketService();
  final _imageService = ImageService();
  final _titleController = TextEditingController();
  final _priceController = TextEditingController();
  final _descController = TextEditingController();

  @override
  void initState() {
    super.initState();

    if (widget.existingProduct != null) {
      final product = widget.existingProduct!;
      _titleController.text = product.title;
      _priceController.text = product.price.toString();
      _descController.text = product.description;
      _category = product.category;
      _isUrgent = product.isUrgent;
      _isNegotiable = product.isNegotiable;
      _isDirectDeal = product.isDirectDeal;
      _existingImageUrls = List<String>.from(product.images);
    }
  }

  String _category = '기타';
  bool _saving = false;

  bool _isUrgent = false;
  bool _isNegotiable = false;
  bool _isDirectDeal = false;

  static const _green = Color(0xFFFF9166);
  static const _greenLight = Color(0xFFFFF0E8);
  static const _gradientStart = Color(0xFFFFA351);
  static const _gradientEnd = Color(0xFFFF6B1A);

  static const _categories = ['전자기기', '의류', '도서', '가구', '생활용품', '기타'];

  final String _myId = FirebaseAuth.instance.currentUser!.uid;
  final List<File> _selectedImages = [];
  List<String> _existingImageUrls = [];

  IconData _categoryIcon(String cat) {
    switch (cat) {
      case '전자기기':
        return Icons.devices_other_outlined;
      case '의류':
        return Icons.checkroom_outlined;
      case '도서':
        return Icons.menu_book_outlined;
      case '가구':
        return Icons.chair_outlined;
      case '생활용품':
        return Icons.home_outlined;
      default:
        return Icons.category_outlined;
    }
  }

  Widget _optionChip(String label, bool selected, ValueChanged<bool> onChanged) {
    return GestureDetector(
      onTap: () => onChanged(!selected),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? _green : _greenLight,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? _green : _green.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              selected ? Icons.check_circle : Icons.circle_outlined,
              size: 15,
              color: selected ? Colors.white : _green,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                color: selected ? Colors.white : _green,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<String> _getSellerName() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(_myId).get();
      final nickname = doc.data()?['nickname'] as String?;
      if (nickname != null && nickname.trim().isNotEmpty) return nickname;
    } catch (_) {}
    return FirebaseAuth.instance.currentUser?.displayName ?? '판매자';
  }

  Future<void> _pickImage() async {
    if (_existingImageUrls.length + _selectedImages.length >= 5) return;
    final file = await _imageService.pickImage();
    if (file != null) {
      setState(() => _selectedImages.add(file));
    }
  }

  void _removeImage(int index) {
    setState(() => _selectedImages.removeAt(index));
  }

  void _removeExistingImage(int index) {
    setState(() => _existingImageUrls.removeAt(index));
  }

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
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('카테고리를 선택하세요',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
                const SizedBox(height: 16),
                ..._categories.map((cat) {
                  final selected = cat == _category;
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
                          color: selected ? _greenLight : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: selected ? _green.withOpacity(0.4) : Colors.grey[200]!,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(color: _green, shape: BoxShape.circle),
                              alignment: Alignment.center,
                              child: Icon(_categoryIcon(cat), color: Colors.white, size: 16),
                            ),
                            const SizedBox(width: 12),
                            Text(cat,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                                  color: selected ? _green : Colors.black87,
                                )),
                            const Spacer(),
                            if (selected) const Icon(Icons.check_circle, color: _green, size: 20),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _submit() async {
    final title = _titleController.text.trim();
    final priceText = _priceController.text.trim().replaceAll(',', '');
    final desc = _descController.text.trim();

    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('상품명을 입력해주세요')));
      return;
    }
    final price = num.tryParse(priceText);
    if (price == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('가격을 숫자로 입력해주세요')));
      return;
    }
    if (_existingImageUrls.isEmpty && _selectedImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('사진을 최소 1장 등록해주세요')));
      return;
    }

    setState(() => _saving = true);
    try {
      final sellerName = await _getSellerName();

      // 새로 고른 파일들만 업로드
      final List<String> newUrls = [];
      for (final file in _selectedImages) {
        final url = await _imageService.uploadImage(file, 'marketProducts');
        newUrls.add(url);
      }

      // 기존에 유지된 URL + 새로 업로드된 URL 합치기
      final allImageUrls = [..._existingImageUrls, ...newUrls];

      if (widget.existingProduct != null) {
        // 수정 모드
        await _service.updateProduct(widget.existingProduct!.productId, {
          'title': title,
          'price': price,
          'description': desc,
          'images': allImageUrls,
          'category': _category,
          'isUrgent': _isUrgent,
          'isNegotiable': _isNegotiable,
          'isDirectDeal': _isDirectDeal,
        });
      } else {
        // 신규 등록
        await _service.addProduct(
          sellerId: _myId,
          sellerName: sellerName,
          title: title,
          price: price,
          description: desc,
          images: allImageUrls,
          category: _category,
          isUrgent: _isUrgent,
          isNegotiable: _isNegotiable,
          isDirectDeal: _isDirectDeal,
        );
      }

      if (context.mounted) Navigator.pop(context);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${widget.existingProduct != null ? "수정" : "등록"} 실패: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _priceController.dispose();
    _descController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8F9FA),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.existingProduct != null ? '상품 수정' : '상품 등록',
          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
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
                    _saving
                        ? (widget.existingProduct != null ? '수정 중...' : '등록 중...')
                        : (widget.existingProduct != null ? '수정' : '등록'),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 사진 등록
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 3)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('사진 (${_existingImageUrls.length + _selectedImages.length}/5)',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 12),
                SizedBox(
                  height: 90,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      GestureDetector(
                        onTap: (_existingImageUrls.length + _selectedImages.length) >= 5 ? null : _pickImage,
                        child: Container(
                          width: 90,
                          height: 90,
                          decoration: BoxDecoration(
                            color: _greenLight,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: _green.withOpacity(0.3)),
                          ),
                          child: Icon(Icons.add_a_photo_outlined, color: _green, size: 24),
                        ),
                      ),
                      // 기존 업로드된 이미지 (네트워크 이미지)
                      ..._existingImageUrls.asMap().entries.map((entry) {
                        return Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.network(entry.value, width: 90, height: 90, fit: BoxFit.cover),
                              ),
                              Positioned(
                                right: 4,
                                top: 4,
                                child: GestureDetector(
                                  onTap: () => _removeExistingImage(entry.key),
                                  child: Container(
                                    padding: const EdgeInsets.all(2),
                                    decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                                    child: const Icon(Icons.close, size: 14, color: Colors.white),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                      // 새로 고른 로컬 이미지
                      ..._selectedImages.asMap().entries.map((entry) {
                        return Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.file(entry.value, width: 90, height: 90, fit: BoxFit.cover),
                              ),
                              Positioned(
                                right: 4,
                                top: 4,
                                child: GestureDetector(
                                  onTap: () => _removeImage(entry.key),
                                  child: Container(
                                    padding: const EdgeInsets.all(2),
                                    decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
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
          const SizedBox(height: 12),

          // 카테고리 선택
          GestureDetector(
            onTap: _openCategoryPicker,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2)),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: const BoxDecoration(color: _green, shape: BoxShape.circle),
                    alignment: Alignment.center,
                    child: Icon(_categoryIcon(_category), color: Colors.white, size: 15),
                  ),
                  const SizedBox(width: 10),
                  Text(_category, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: _green)),
                  const Spacer(),
                  Icon(Icons.keyboard_arrow_down, color: Colors.grey[400]),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // 상품명 + 가격 + 설명
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 3)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _titleController,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    hintText: '상품명을 입력해주세요',
                    hintStyle: TextStyle(color: Colors.grey[400], fontWeight: FontWeight.normal),
                    border: InputBorder.none,
                    isDense: true,
                  ),
                ),
                Divider(height: 24, color: Colors.grey[200]),
                TextField(
                  controller: _priceController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(fontSize: 14),
                  decoration: InputDecoration(
                    hintText: '가격 (원)',
                    hintStyle: TextStyle(color: Colors.grey[400]),
                    border: InputBorder.none,
                    isDense: true,
                    suffixText: '원',
                  ),
                ),
                Divider(height: 24, color: Colors.grey[200]),
                TextField(
                  controller: _descController,
                  maxLines: 5,
                  style: const TextStyle(fontSize: 14, height: 1.5),
                  decoration: InputDecoration(
                    hintText: '상품 상태, 거래 방식 등을 자세히 적어주세요',
                    hintStyle: TextStyle(color: Colors.grey[400]),
                    border: InputBorder.none,
                    isDense: true,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

// 거래 옵션
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 3)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('거래 옵션', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _optionChip('급처', _isUrgent, (v) => setState(() => _isUrgent = v)),
                    _optionChip('네고 가능', _isNegotiable, (v) => setState(() => _isNegotiable = v)),
                    _optionChip('직거래', _isDirectDeal, (v) => setState(() => _isDirectDeal = v)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}