import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/market_service.dart';
import '../../models/market_product_model.dart';
import 'product_detail_screen.dart';

class MyProductsScreen extends StatefulWidget {
  const MyProductsScreen({super.key});

  @override
  State<MyProductsScreen> createState() => _MyProductsScreenState();
}

class _MyProductsScreenState extends State<MyProductsScreen> {
  static const _green = Color(0xFFFF9166);
  static const _greenLight = Color(0xFFFFF0E8);

  String _statusFilter = '전체';
  static const _filters = ['전체', '판매중', '거래중', '판매완료'];

  @override
  Widget build(BuildContext context) {
    final myId = FirebaseAuth.instance.currentUser!.uid;
    final service = MarketService();

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8F9FA),
        elevation: 0,
        title: const Text('내 상품 목록', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: SizedBox(
              height: 32,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: _filters.map((label) {
                  final selected = _statusFilter == label;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => setState(() => _statusFilter = label),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: selected ? _green : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: selected ? _green : Colors.grey[300]!),
                        ),
                        child: Text(label,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                              color: selected ? Colors.white : Colors.grey[600],
                            )),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<MarketProduct>>(
              stream: service.getMyProducts(myId),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(
                        '오류: ${snapshot.error}',
                        style: TextStyle(color: Colors.red[400], fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final products = snapshot.data!.where((p) {
                  if (_statusFilter == '전체') return true;
                  if (_statusFilter == '판매중') return p.status == ProductStatus.selling;
                  if (_statusFilter == '거래중') return p.status == ProductStatus.reserved;
                  return p.status == ProductStatus.sold;
                }).toList();

                if (products.isEmpty) {
                  return Center(
                    child: Text(
                      _statusFilter == '전체' ? '아직 등록한 상품이 없어요' : '해당 상태의 상품이 없어요',
                      style: TextStyle(color: Colors.grey[500]),
                    ),
                  );
                }
                return GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.72,
                  ),
                  itemCount: products.length,
                  itemBuilder: (context, index) => _productCard(context, products[index]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _statusLabel(ProductStatus status) {
    switch (status) {
      case ProductStatus.selling:
        return '판매중';
      case ProductStatus.reserved:
        return '거래중';
      case ProductStatus.sold:
        return '판매완료';
    }
  }

  Color _statusBg(ProductStatus status) {
    switch (status) {
      case ProductStatus.selling:
        return const Color(0xFFFFE9DC);
      case ProductStatus.reserved:
        return const Color(0xFFFFF3D6);
      case ProductStatus.sold:
        return const Color(0xFFEDEDED);
    }
  }

  Color _statusText(ProductStatus status) {
    switch (status) {
      case ProductStatus.selling:
        return _green;
      case ProductStatus.reserved:
        return const Color(0xFFC98A00);
      case ProductStatus.sold:
        return Colors.grey[600]!;
    }
  }

  IconData _statusIcon(ProductStatus status) {
    switch (status) {
      case ProductStatus.selling:
        return Icons.local_fire_department_rounded;
      case ProductStatus.reserved:
        return Icons.schedule_rounded;
      case ProductStatus.sold:
        return Icons.check_circle_rounded;
    }
  }

  String _timeAgo(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inMinutes < 1) return '방금 전';
    if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
    if (diff.inHours < 24) return '${diff.inHours}시간 전';
    if (diff.inDays < 7) return '${diff.inDays}일 전';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}주 전';
    return '${dateTime.year}.${dateTime.month.toString().padLeft(2, '0')}.${dateTime.day.toString().padLeft(2, '0')}';
  }

  Widget _tagChip(String label, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 9, color: color),
          const SizedBox(width: 2),
          Text(label, style: TextStyle(fontSize: 9, color: color, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _productCard(BuildContext context, MarketProduct product) {
    final hasImage = product.images.isNotEmpty;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ProductDetailScreen(product: product)),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.grey[200]!),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  child: AspectRatio(
                    aspectRatio: 4 / 3,
                    child: hasImage
                        ? Image.network(
                      product.images.first,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: _greenLight,
                        child: Icon(Icons.image_outlined, color: _green.withOpacity(0.4), size: 30),
                      ),
                    )
                        : Container(
                      color: _greenLight,
                      child: Icon(Icons.image_outlined, color: _green.withOpacity(0.4), size: 30),
                    ),
                  ),
                ),
                Positioned(
                  left: 6,
                  top: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: _statusBg(product.status),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_statusIcon(product.status), size: 10, color: _statusText(product.status)),
                        const SizedBox(width: 3),
                        Text(
                          _statusLabel(product.status),
                          style: TextStyle(fontSize: 9, color: _statusText(product.status), fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${NumberFormat('#,###').format(product.price)}원',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                  const SizedBox(height: 3),
                  Text(product.title,
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  if (product.isUrgent || product.isNegotiable || product.isDirectDeal) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: [
                        if (product.isUrgent) _tagChip('급처', Colors.redAccent, Icons.bolt_rounded),
                        if (product.isNegotiable) _tagChip('네고가능', _green, Icons.sell_rounded),
                        if (product.isDirectDeal) _tagChip('직거래', Colors.blueGrey, Icons.handshake_rounded),
                      ],
                    ),
                  ],
                  const SizedBox(height: 6),
                  Text(
                    _timeAgo(product.createdAt),
                    style: TextStyle(fontSize: 10, color: Colors.grey[400]),
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