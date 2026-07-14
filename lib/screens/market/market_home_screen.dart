import 'package:flutter/material.dart';
import '../../services/market_service.dart';
import '../../models/market_product_model.dart';
import '../../widgets/common/bottom_nav_bar.dart';
import 'product_detail_screen.dart';

class MarketHomeScreen extends StatefulWidget {
  const MarketHomeScreen({super.key});

  @override
  State<MarketHomeScreen> createState() => _MarketHomeScreenState();
}

class _MarketHomeScreenState extends State<MarketHomeScreen> {
  final _service = MarketService();
  int _tabIndex = 0; // 0: 땡그랑 마켓, 1: 플리마켓
  static const _green = Color(0xFF3B8B5E);
  static const _greenLight = Color(0xFFE6F4EB);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text('땡그랑 마켓',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('가격 비교부터 알뜰한 상품 추천까지',
                style: TextStyle(fontSize: 13, color: Colors.grey[600])),
            const SizedBox(height: 20),

            // 탭 전환
            Row(
              children: [
                _tabButton('땡그랑 마켓', 0),
                const SizedBox(width: 24),
                _tabButton('플리마켓', 1),
              ],
            ),
            const Divider(height: 24),

            // 검색바
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.search, color: Colors.grey[500], size: 20),
                  const SizedBox(width: 8),
                  Text('상품명 또는 카테고리를 검색하세요',
                      style: TextStyle(color: Colors.grey[500], fontSize: 13)),
                ],
              ),
            ),
            const SizedBox(height: 20),

            if (_tabIndex == 0) ..._buildDdaengMarketTab(),
            if (_tabIndex == 1) ..._buildFleaMarketTab(),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavBar(
        currentTab: NavTab.community, // TODO: NavTab에 market 추가되면 교체
        onTabSelected: (tab) {},
      ),
    );
  }

  Widget _tabButton(String label, int index) {
    final selected = _tabIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _tabIndex = index),
      child: Column(
        children: [
          Text(label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                color: selected ? Colors.black : Colors.grey[400],
              )),
          const SizedBox(height: 6),
          Container(
            height: 2,
            width: 50,
            color: selected ? _green : Colors.transparent,
          ),
        ],
      ),
    );
  }

  // 땡그랑 마켓 탭 — 최저가 비교 (임시 더미)
  List<Widget> _buildDdaengMarketTab() {
    final dummyItems = [
      {'name': '무선 블루투스 이어폰', 'price': '39,900원', 'tag': '최저가'},
      {'name': '캡슐 커피 세트', 'price': '24,500원', 'tag': '23% 할인'},
      {'name': '무선 키보드', 'price': '31,800원', 'tag': '가격 비교'},
      {'name': '생활용품 묶음', 'price': '19,900원', 'tag': '추천'},
    ];

    return [
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _greenLight,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('오늘의 절약 추천',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 4),
            Text('여러 쇼핑몰 가격을 비교해 더 저렴하게!',
                style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          ],
        ),
      ),
      const SizedBox(height: 20),
      const Text('지금 최저가 상품',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
      const SizedBox(height: 12),
      GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.85,
        children: dummyItems.map((item) => _priceCard(item)).toList(),
      ),
    ];
  }

  Widget _priceCard(Map<String, String> item) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey[200]!),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 70,
            decoration: BoxDecoration(
              color: _greenLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.image_outlined, color: _green.withOpacity(0.4)),
          ),
          const SizedBox(height: 8),
          Text(item['name']!, style: const TextStyle(fontSize: 12)),
          const SizedBox(height: 4),
          Text(item['price']!,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: _greenLight,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(item['tag']!,
                style: TextStyle(fontSize: 10, color: _green)),
          ),
        ],
      ),
    );
  }

  // 플리마켓 탭 — 실제 marketProducts 연동
  List<Widget> _buildFleaMarketTab() {
    return [
      StreamBuilder<List<MarketProduct>>(
        stream: _service.getProducts(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Padding(
              padding: EdgeInsets.all(40),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final products = snapshot.data!;
          if (products.isEmpty) {
            return const Padding(
              padding: EdgeInsets.all(40),
              child: Center(child: Text('등록된 상품이 없어요')),
            );
          }
          return GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.85,
            children: products.map((p) => _productCard(p)).toList(),
          );
        },
      ),
    ];
  }

  Widget _productCard(MarketProduct product) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ProductDetailScreen(product: product)),
      ),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.grey[200]!),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 70,
              decoration: BoxDecoration(
                color: _greenLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.image_outlined, color: _green.withOpacity(0.4)),
            ),
            const SizedBox(height: 8),
            Text(product.title, style: const TextStyle(fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Text('${product.price}원',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          ],
        ),
      ),
    );
  }
}