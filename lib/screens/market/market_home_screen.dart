import 'package:ddaenggeurang/services/chat_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:circular_menu/circular_menu.dart';
import '../../services/market_service.dart';
import '../../models/market_product_model.dart';
import '../../widgets/common/bottom_nav_bar.dart';
import '../chat/chat_list_screen.dart';
import 'product_detail_screen.dart';
import 'product_register_screen.dart';
import 'my_products_screen.dart';
import 'my_favorites_screen.dart';

class MarketHomeScreen extends StatefulWidget {
  const MarketHomeScreen({super.key});

  @override
  State<MarketHomeScreen> createState() => _MarketHomeScreenState();
}

class _MarketHomeScreenState extends State<MarketHomeScreen> {
  final _service = MarketService();
  int _tabIndex = 0;
  static const _green = Color(0xFFFF9166);
  static const _greenLight = Color(0xFFFFF0E8);
  static const _gradientStart = Color(0xFFFFA351);
  static const _gradientEnd = Color(0xFFFF6B1A);

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
      backgroundColor: const Color(0xFFF8F9FA),
      // 플리마켓 탭일 때만 원형 메뉴로 감싸고, 땡그랑마켓 탭이면 메뉴 없이 그대로 표시
      body: _tabIndex == 1
          ? CircularMenu(
        alignment: Alignment.bottomRight,
        radius: 80,
        toggleButtonColor: _green,
        toggleButtonIconColor: Colors.white,
        toggleButtonSize: 30,
        toggleButtonPadding: 18,
        toggleButtonMargin: 20,
        toggleButtonBoxShadow: [
          BoxShadow(
            color: _green.withOpacity(0.4),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        items: [
          CircularMenuItem(
            icon: Icons.add,
            color: _green,
            iconColor: Colors.white,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProductRegisterScreen()),
              );
            },
          ),
          CircularMenuItem(
            icon: Icons.inventory_2_outlined,
            color: const Color(0xFF9B7EDE),
            iconColor: Colors.white,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MyProductsScreen()),
              );
            },
          ),
          CircularMenuItem(
            icon: Icons.favorite_border,
            color: const Color(0xFFE5735A),
            iconColor: Colors.white,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MyFavoritesScreen()),
              );
            },
          ),
        ],
        backgroundWidget: _buildContent(),
      )
          : _buildContent(),
      bottomNavigationBar: BottomNavBar(
        currentTab: NavTab.community,
        onTabSelected: (tab) {
          if (tab == NavTab.community) return;
          Navigator.of(context).pop();
        },
      ),
    );
  }

  // 땡그랑마켓/플리마켓 공통 콘텐츠 — 원형 메뉴 유무와 상관없이 동일하게 재사용
  Widget _buildContent() {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 헤더 — 플리마켓 탭일 때만 우측에 채팅 아이콘(안읽음 뱃지) 노출
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: const Padding(
                      padding: EdgeInsets.only(right: 4),
                      child: Icon(Icons.arrow_back, color: Colors.black87),
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('땡그랑 마켓',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      SizedBox(height: 4),
                      Text('가격 비교부터 알뜰한 상품 추천까지',
                          style: TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ],
              ),
              if (_tabIndex == 1)
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
          const SizedBox(height: 16),

          // 탭
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2)),
              ],
            ),
            child: Row(
              children: [
                Expanded(child: _tabButton('땡그랑 마켓', 0)),
                Expanded(child: _tabButton('플리마켓', 1)),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 검색바
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2)),
              ],
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
    );
  }

  Widget _tagBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 9, color: color, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _tabButton(String label, int index) {
    final selected = _tabIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _tabIndex = index),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          gradient: selected
              ? const LinearGradient(colors: [_gradientStart, _gradientEnd])
              : null,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            color: selected ? Colors.white : Colors.grey[500],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildDdaengMarketTab() {
    final dummyItems = [
      {
        'id': 'ddaeng_1',
        'name': '무선 블루투스 이어폰',
        'price': '39,900원',
        'tag': '최저가',
        'url': 'https://www.coupang.com/np/search?q=무선+블루투스+이어폰',
      },
      {
        'id': 'ddaeng_2',
        'name': '캡슐 커피 세트',
        'price': '24,500원',
        'tag': '23% 할인',
        'url': 'https://www.coupang.com/np/search?q=캡슐+커피',
      },
      {
        'id': 'ddaeng_3',
        'name': '무선 키보드',
        'price': '31,800원',
        'tag': '가격 비교',
        'url': 'https://www.coupang.com/np/search?q=무선+키보드',
      },
      {
        'id': 'ddaeng_4',
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
          gradient: const LinearGradient(
            colors: [_gradientStart, _gradientEnd],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('오늘의 절약 추천',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white)),
            SizedBox(height: 4),
            Text('여러 쇼핑몰 가격을 비교해 더 저렴하게!',
                style: TextStyle(fontSize: 12, color: Colors.white70)),
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
    final itemId = item['id']!;
    final isFav = _favoriteIds.contains(itemId);

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
                  child: GestureDetector(
                    onTap: () => _toggleFavorite(itemId),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 4),
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
            return Padding(
              padding: const EdgeInsets.all(40),
              child: Center(
                child: Text('등록된 상품이 없어요', style: TextStyle(color: Colors.grey[500])),
              ),
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
      const SizedBox(height: 20),
    ];
  }

  Widget _productCard(MarketProduct product) {
    final isFav = _favoriteIds.contains(product.productId);
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
                    decoration: BoxDecoration(
                      color: _greenLight,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.image_outlined, color: _green.withOpacity(0.4)),
                  ),
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
            // 거래 옵션 뱃지 — 새로 추가
            if (product.isUrgent || product.isNegotiable || product.isDirectDeal)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                    if (product.isUrgent) _tagBadge('급처', Colors.redAccent),
                    if (product.isNegotiable) _tagBadge('네고가능', const Color(0xFF5B9BD5)),
                    if (product.isDirectDeal) _tagBadge('직거래', const Color(0xFF4CAF87)),
                  ],
                ),
              ),

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