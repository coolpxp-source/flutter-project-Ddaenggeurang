import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../services/market_service.dart';
import '../../models/market_product_model.dart';
import 'product_detail_screen.dart';

class MyProductsScreen extends StatelessWidget {
  const MyProductsScreen({super.key});

  static const _green = Color(0xFFFF9166);
  static const _greenLight = Color(0xFFFFF0E8);

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
      body: StreamBuilder<List<MarketProduct>>(
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
          final products = snapshot.data!;
          if (products.isEmpty) {
            return Center(
              child: Text('아직 등록한 상품이 없어요', style: TextStyle(color: Colors.grey[500])),
            );
          }
          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.85,
            ),
            itemCount: products.length,
            itemBuilder: (context, index) => _productCard(context, products[index]),
          );
        },
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
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: hasImage
                  ? Image.network(
                product.images.first,
                height: 90,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  height: 90,
                  width: double.infinity,
                  color: _greenLight,
                  child: Icon(Icons.image_outlined, color: _green.withOpacity(0.4)),
                ),
              )
                  : Container(
                height: 90,
                width: double.infinity,
                decoration: BoxDecoration(color: _greenLight, borderRadius: BorderRadius.circular(10)),
                child: Icon(Icons.image_outlined, color: _green.withOpacity(0.4)),
              ),
            ),
            const SizedBox(height: 8),
            Text(product.title, style: const TextStyle(fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Text('${product.price}원', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          ],
        ),
      ),
    );
  }
}