import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/market_product_model.dart';
import '../../services/market_service.dart';
import '../../services/chat_service.dart';
import '../../models/chat_model.dart';
import '../chat/chat_room_screen.dart';
import 'price_comparison_screen.dart';

class ProductDetailScreen extends StatefulWidget {
  final MarketProduct product;
  const ProductDetailScreen({super.key, required this.product});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  static const _green = Color(0xFF3B8B5E);
  static const _greenLight = Color(0xFFE6F4EB);

  final String _myId = FirebaseAuth.instance.currentUser!.uid;
  static const _myName = '나';

  final _marketService = MarketService();
  bool _isFavorite = false;

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

  Future<void> _startChat(BuildContext context) async {
    final product = widget.product;
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
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ChatRoomScreen(chatId: chatId)),
      );
    }
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

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('상품 상세', style: TextStyle(color: Colors.black)),
        actions: [
          IconButton(
            icon: const Icon(Icons.home_outlined, color: Colors.black87),
            onPressed: () => Navigator.popUntil(context, (route) => route.isFirst),
          ),
          IconButton(
            icon: const Icon(Icons.search, color: Colors.black87),
            onPressed: () {
              // TODO: 마켓 검색 화면 연결
            },
          ),
        ],
      ),
      body: ListView(
        children: [
          Container(
            height: 260,
            width: double.infinity,
            color: _greenLight,
            child: product.images.isEmpty
                ? Icon(Icons.image_outlined, size: 60, color: _green.withOpacity(0.4))
                : Image.network(product.images.first, fit: BoxFit.cover),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: product.status == ProductStatus.selling
                        ? _greenLight
                        : Colors.grey[200],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _statusLabel(product.status),
                    style: TextStyle(
                      fontSize: 12,
                      color: product.status == ProductStatus.selling
                          ? _green
                          : Colors.grey[600],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 12),

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
                          border: Border.all(
                            color: Colors.grey[300]!,
                            width: 1.2,
                          ),
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
                Text('${product.price}원',
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),

                Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: _green,
                      backgroundImage: product.sellerAvatarUrl.isNotEmpty
                          ? NetworkImage(product.sellerAvatarUrl)
                          : null,
                    ),
                    const SizedBox(width: 8),
                    Text(product.sellerName, style: const TextStyle(fontSize: 13)),
                  ],
                ),
                const SizedBox(height: 16),
                Divider(height: 1, color: Colors.grey[200]),
                const SizedBox(height: 16),

                Text(product.description, style: const TextStyle(fontSize: 14, height: 1.6)),
                const SizedBox(height: 16),

                Text('#${product.category}',
                    style: TextStyle(fontSize: 12, color: _green)),

                if (product.priceComparisons.isNotEmpty) ...[
                  const Divider(height: 32),
                  GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PriceComparisonScreen(product: product),
                      ),
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
                          const Expanded(
                            child: Text('다른 쇼핑몰 가격 비교 보기', style: TextStyle(fontSize: 13)),
                          ),
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
              onPressed: product.status == ProductStatus.selling
                  ? () => _startChat(context)
                  : null,
              icon: const Icon(Icons.chat_bubble_outline, color: Colors.white),
              label: Text(
                product.status == ProductStatus.selling ? '채팅하기' : _statusLabel(product.status),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _green,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ),
      ),
    );
  }
}