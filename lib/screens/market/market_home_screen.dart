import 'package:ddaenggeurang/services/chat_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/market_service.dart';
import '../../models/market_product_model.dart';
import '../../widgets/common/bottom_nav_bar.dart';
import '../chat/chat_list_screen.dart';
import 'product_detail_screen.dart';

class MarketHomeScreen extends StatefulWidget {
  const MarketHomeScreen({super.key});

  @override
  State<MarketHomeScreen> createState() => _MarketHomeScreenState();
}

class _MarketHomeScreenState extends State<MarketHomeScreen> {
  final _service = MarketService();
  int _tabIndex = 0;
  static const _green = Color(0xFF3B8B5E);
  static const _greenLight = Color(0xFFE6F4EB);

  // TODO: 로그인 연결되면 교체
  final String _myId = FirebaseAuth.instance.currentUser!.uid;

  Set<String> _favoriteIds = {};

  @override
  void initState() {
    super.initState();
    _service.getFavoriteIds(_myId).listen((ids) {
      if (mounted) setState(() => _favoriteIds = ids);
    });
  }

  void _toggleFavorite(String productId) {
    final isFav = _favoriteIds.contains(productId);
    _service.toggleFavorite(_myId, productId, !isFav);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('땡그랑 마켓',
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                      SizedBox(height: 4),
                      Text('가격 비교부터 알뜰한 상품 추천까지',
                          style: TextStyle(fontSize: 13, color: Colors.grey)),
                    ],
                  ),
                ),
                StreamBuilder<int>(
                  stream: ChatService().getTotalUnreadCount(_myId),
                  builder: (context, snapshot) {
                    final unreadCount = snapshot.data ?? 0;

                    return SizedBox(
                      width: 40,
                      height: 40,
                      child: Stack(
                        clipBehavior: Clip.none,
                        alignment: Alignment.center,
                        children: [
                          GestureDetector(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => ChatListScreen()),
                            ),
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: _greenLight,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(Icons.chat_bubble_outline, color: _green, size: 20),
                            ),
                          ),
                          if (unreadCount > 0)
                            Positioned(
                              right: 2,
                              top: 2,
                              child: Container(
                                padding: const EdgeInsets.all(3),
                                decoration: const BoxDecoration(
                                  color: Colors.redAccent,
                                  shape: BoxShape.circle,
                                ),
                                constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
                                child: Text(
                                  unreadCount > 9 ? '9+' : '$unreadCount',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                _tabButton('땡그랑 마켓', 0),
                const SizedBox(width: 24),
                _tabButton('플리마켓', 1),
              ],
            ),
            const Divider(height: 24),

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
        currentTab: NavTab.community,
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
          Container(height: 2, width: 50, color: selected ? _green : Colors.transparent),
        ],
      ),
    );
  }

  List<Widget> _buildDdaengMarketTab() {
    final dummyItems = [
      {
        'name': '무선 블루투스 이어폰',
        'price': '39,900원',
        'tag': '최저가',
        'url': 'https://www.coupang.com/np/search?q=무선+블루투스+이어폰',
      },
      {
        'name': '캡슐 커피 세트',
        'price': '24,500원',
        'tag': '23% 할인',
        'url': 'https://www.coupang.com/np/search?q=캡슐+커피',
      },
      {
        'name': '무선 키보드',
        'price': '31,800원',
        'tag': '가격 비교',
        'url': 'https://www.coupang.com/np/search?q=무선+키보드',
      },
      {
        'name': '생활용품 묶음',
        'price': '19,900원',
        'tag': '추천',
        'url': 'https://www.coupang.com/np/search?q=생활용품',
      },
    ];

    return [
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _greenLight,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('오늘의 절약 추천', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            SizedBox(height: 4),
            Text('여러 쇼핑몰 가격을 비교해 더 저렴하게!',
                style: TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      ),
      const SizedBox(height: 20),
      const Text('지금 최저가 상품', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
      const SizedBox(height: 12),
      GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.85,
        children: dummyItems.map((item) => _dummyPriceCard(item)).toList(),
      ),
    ];
  }

  Widget _dummyPriceCard(Map<String, String> item) {
    return GestureDetector(
      onTap: () async {
        final url = Uri.parse(item['url']!);
        if (await canLaunchUrl(url)) {
          await launchUrl(url, mode: LaunchMode.externalApplication);
        }
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    height: 80,
                    width: double.infinity,
                    color: _greenLight,
                    child: Icon(Icons.image_outlined, color: _green.withOpacity(0.35), size: 28),
                  ),
                ),
                Positioned(
                  right: 6,
                  top: 6,
                  child: Icon(Icons.favorite_border, size: 18, color: Colors.grey[400]),
                ),
                Positioned(
                  left: 6,
                  bottom: 6,
                  child: Icon(Icons.open_in_new, size: 14, color: Colors.white70),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(item['name']!,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Text(item['price']!,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(color: _greenLight, borderRadius: BorderRadius.circular(6)),
              child: Text(item['tag']!,
                  style: TextStyle(fontSize: 10, color: _green, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

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
    final isFav = _favoriteIds.contains(product.productId);

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
            Stack(
              children: [
                Container(
                  height: 70,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: _greenLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.image_outlined, color: _green.withOpacity(0.4)),
                ),
                Positioned(
                  right: 8,
                  top: 8,
                  child: GestureDetector(
                    onTap: () => _toggleFavorite(product.productId),
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: Icon(
                        isFav ? Icons.favorite : Icons.favorite_border,
                        size: 15,
                        color: isFav ? Colors.redAccent : Colors.grey[400],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(product.title,
                style: const TextStyle(fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Text('${product.price}원',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          ],
        ),
      ),
    );
  }
}