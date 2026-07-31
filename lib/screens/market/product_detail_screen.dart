import 'package:ddaenggeurang/screens/market/seller_products_screen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/market_product_model.dart';
import '../../services/market_service.dart';
import '../../services/chat_service.dart';
import '../../models/chat_model.dart';
import '../../widgets/common/ddaeng_modal.dart';
import '../chat/chat_room_screen.dart';
import 'price_comparison_screen.dart';
import 'product_register_screen.dart';
import 'package:intl/intl.dart';

class ProductDetailScreen extends StatefulWidget {
  final MarketProduct product;
  const ProductDetailScreen({super.key, required this.product});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  static const _green = Color(0xFFFF9166);
  static const _greenLight = Color(0xFFFFF0E8);

  final String _myId = FirebaseAuth.instance.currentUser!.uid;
  static const _myName = '나';

  final _marketService = MarketService();
  bool _isFavorite = false;
  int _currentImageIndex = 0;

  @override
  void initState() {
    super.initState();
    _marketService.getFavoriteIds(_myId).listen((ids) {
      if (mounted) {
        setState(() => _isFavorite = ids.contains(widget.product.productId));
      }
    });
  }

  void _toggleFavorite() {
    _marketService.toggleFavorite(_myId, widget.product.productId, !_isFavorite);
  }

  Future<void> _startChat(BuildContext context, MarketProduct product) async {
    if (product.sellerId == _myId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('본인 상품에는 채팅을 시작할 수 없어요')),
      );
      return;
    }

    final chatService = ChatService();
    final chatId = await chatService.createOrGetChat(
      myId: _myId,
      otherId: product.sellerId,
      me: ChatParticipant(name: _myName, avatarUrl: ''),
      other: ChatParticipant(name: product.sellerName, avatarUrl: product.sellerAvatarUrl),
      productId: product.productId,
    );

    if (context.mounted) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => ChatRoomScreen(chatId: chatId)));
    }
  }

  Widget _tagBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.bold)),
    );
  }

  String _statusLabel(ProductStatus status) {
    switch (status) {
      case ProductStatus.selling:
        return '판매중';
      case ProductStatus.reserved:
        return '예약중';
      case ProductStatus.sold:
        return '판매완료';
    }
  }

  Widget _statusSelector(MarketProduct product) {
    final options = [
      (ProductStatus.selling, '판매중'),
      (ProductStatus.reserved, '거래중'),
      (ProductStatus.sold, '판매완료'),
    ];

    return Row(
      children: options.map((opt) {
        final selected = product.status == opt.$1;
        return Expanded(
          child: GestureDetector(
            onTap: () => _updateStatus(product, opt.$1),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: selected ? _green : Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                opt.$2,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: selected ? Colors.white : Colors.grey[600],
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  void _updateStatus(MarketProduct product, ProductStatus newStatus) async {
    if (newStatus == product.status) return;

    final confirmed = await DdaengModal.confirm(
      context,
      title: '${_statusLabel(newStatus)}(으)로 변경할까요?',
      type: newStatus == ProductStatus.sold ? ModalType.danger : ModalType.warning,
      confirmText: '변경',
    );
    if (!confirmed) return;

    await _marketService.updateProductStatus(product.productId, newStatus);
  }

  Future<void> _confirmDelete(BuildContext context, MarketProduct product) async {
    final confirmed = await DdaengModal.confirm(
      context,
      title: '상품을 삭제할까요?',
      message: '삭제하면 되돌릴 수 없어요.',
      type: ModalType.danger,
      confirmText: '삭제',
    );
    if (confirmed && context.mounted) {
      await _marketService.deleteProduct(product.productId, product.images);
      if (context.mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('marketProducts')
          .doc(widget.product.productId)
          .snapshots(),
      builder: (context, snapshot) {
        final product = (snapshot.hasData && snapshot.data!.exists)
            ? MarketProduct.fromFirestore(snapshot.data!)
            : widget.product;

        final isOwner = product.sellerId == FirebaseAuth.instance.currentUser!.uid;

        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            title: const Text('상품 상세', style: TextStyle(color: Colors.black)),
            actions: [
              if (isOwner)
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: Colors.black87),
                  onSelected: (value) {
                    if (value == 'edit') {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => ProductRegisterScreen(existingProduct: product)),
                      );
                    } else if (value == 'delete') {
                      _confirmDelete(context, product);
                    }
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'edit', child: Text('수정')),
                    const PopupMenuItem(value: 'delete', child: Text('삭제')),
                  ],
                ),
              IconButton(
                icon: const Icon(Icons.home_outlined, color: Colors.black87),
                onPressed: () => Navigator.popUntil(context, (route) => route.isFirst),
              ),
              IconButton(icon: const Icon(Icons.search, color: Colors.black87), onPressed: () {}),
            ],
          ),
          body: ListView(
            children: [
              // 이미지 슬라이드
              Stack(
                children: [
                  SizedBox(
                    height: 260,
                    width: double.infinity,
                    child: product.images.isEmpty
                        ? Container(
                      color: _greenLight,
                      child: Icon(Icons.image_outlined, size: 60, color: _green.withValues(alpha: 0.4)),
                    )
                        : PageView.builder(
                      itemCount: product.images.length,
                      onPageChanged: (i) => setState(() => _currentImageIndex = i),
                      itemBuilder: (context, i) =>
                          Image.network(product.images[i], fit: BoxFit.cover, width: double.infinity),
                    ),
                  ),
                  if (product.images.length > 1)
                    Positioned(
                      bottom: 12,
                      left: 0,
                      right: 0,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: product.images.asMap().entries.map((entry) {
                          return Container(
                            width: 6,
                            height: 6,
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _currentImageIndex == entry.key
                                  ? _green
                                  : Colors.white.withValues(alpha: 0.6),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                ],
              ),

              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: product.status == ProductStatus.selling ? _greenLight : Colors.grey[200],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _statusLabel(product.status),
                            style: TextStyle(
                              fontSize: 12,
                              color: product.status == ProductStatus.selling ? _green : Colors.grey[600],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (product.isUrgent) _tagBadge('급처', Colors.redAccent),
                        if (product.isNegotiable) _tagBadge('네고가능', const Color(0xFF5B9BD5)),
                        if (product.isDirectDeal) _tagBadge('직거래', const Color(0xFF4CAF87)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (isOwner) ...[
                      _statusSelector(product),
                      const SizedBox(height: 12),
                    ],

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(product.title,
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        ),
                        GestureDetector(
                          onTap: _toggleFavorite,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.grey[300]!, width: 1.2),
                            ),
                            child: Icon(
                              _isFavorite ? Icons.favorite : Icons.favorite_border,
                              color: _isFavorite ? Colors.redAccent : Colors.grey[400],
                              size: 18,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text('${NumberFormat('#,###').format(product.price)}원', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),

                    GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => SellerProductsScreen(
                              sellerId: product.sellerId,
                              sellerName: product.sellerName,
                            ),
                          ),
                        ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: _green,
                            backgroundImage:
                            product.sellerAvatarUrl.isNotEmpty ? NetworkImage(product.sellerAvatarUrl) : null,
                          ),
                          const SizedBox(width: 8),
                          Text(product.sellerName, style: const TextStyle(fontSize: 13)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Divider(height: 1, color: Colors.grey[200]),
                    const SizedBox(height: 16),

                    Text(product.description, style: const TextStyle(fontSize: 14, height: 1.6)),
                    const SizedBox(height: 16),

                    Text('#${product.category}', style: TextStyle(fontSize: 12, color: _green)),
                    if (product.verifiedDong != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.location_on, size: 13, color: Colors.grey[400]),
                          const SizedBox(width: 3),
                          Text(
                            product.verifiedDong!,
                            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                          ),
                        ],
                      ),
                    ],

                    if (product.priceComparisons.isNotEmpty) ...[
                      const Divider(height: 32),
                      GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => PriceComparisonScreen(product: product)),
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey[300]!),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.compare_arrows, size: 18, color: _green),
                              const SizedBox(width: 8),
                              const Expanded(child: Text('다른 쇼핑몰 가격 비교 보기', style: TextStyle(fontSize: 13))),
                              Icon(Icons.chevron_right, color: Colors.grey[400]),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          bottomNavigationBar: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: product.status == ProductStatus.selling ? () => _startChat(context, product) : null,
                  icon: const Icon(Icons.chat_bubble_outline, color: Colors.white),
                  label: Text(
                    product.status == ProductStatus.selling ? '채팅하기' : _statusLabel(product.status),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(backgroundColor: _green, padding: const EdgeInsets.symmetric(vertical: 14)),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}