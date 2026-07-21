import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ddaenggeurang/screens/profile/neighborhood_verify_screen.dart';
import 'package:ddaenggeurang/widgets/common/app_drawer.dart';
import 'package:ddaenggeurang/widgets/common/app_header.dart';
import 'package:ddaenggeurang/widgets/common/ddaeng_modal.dart';

import '../../services/chat_service.dart';
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
import '../../widgets/market/tappable_product_image.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
  String _statusFilter = '전체';

  String? _myVerifiedDong;
  bool _myDongOnly = false;

  @override
  void initState() {
    super.initState();
    _service.getFavoriteIds(_myId).listen((ids) {
      if (mounted) setState(() => _favoriteIds = ids);
    });
    _loadMyDong();
  }

  Future<void> _loadMyDong() async {
    final doc = await FirebaseFirestore.instance.collection('users').doc(_myId).get();
    if (mounted) {
      setState(() => _myVerifiedDong = doc.data()?['verifiedDong'] as String?);
    }
  }

  Widget _myDongBanner() {
    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const NeighborhoodVerifyScreen()),
        );
        _loadMyDong(); // 인증 화면 다녀온 뒤 새로고침
      },
      child: Row(
        children: [
          Icon(Icons.location_on, size: 14, color: _myVerifiedDong != null ? _green : Colors.grey[400]),
          const SizedBox(width: 4),
          Text(
            _myVerifiedDong ?? '동네 인증하기',
            style: TextStyle(
              fontSize: 12,
              color: _myVerifiedDong != null ? _green : Colors.grey[500],
              fontWeight: FontWeight.w500,
            ),
          ),
          if (_myVerifiedDong != null) ...[
            const SizedBox(width: 2),
            Icon(Icons.chevron_right, size: 14, color: Colors.grey[400]),
          ],
        ],
      ),
    );
  }

  void _toggleFavorite(String productId) {
    final isFav = _favoriteIds.contains(productId);
    _service.toggleFavorite(_myId, productId, !isFav);
  }

  final _searchController = TextEditingController();
  String _searchQuery = '';
  String _categoryFilter = '전체';

  static const _categories = ['전체', '전자기기', '의류', '도서', '가구', '생활용품', '기타'];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      drawer: const AppDrawer(),
      appBar: buildDdaengHeader(context, _myId, inkColor: Colors.black87),
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
            onTap: () async {
              final uid = FirebaseAuth.instance.currentUser!.uid;
              final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
              final verifiedDong = userDoc.data()?['verifiedDong'] as String?;

              if (verifiedDong == null) {
                final confirmed = await DdaengModal.confirm(
                  context,
                  title: '동네 인증이 필요해요',
                  message: '직거래 상품 등록을 위해 동네 인증을 먼저 해주세요.',
                  type: ModalType.warning,
                  confirmText: '인증하기',
                );
                if (confirmed && context.mounted) {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const NeighborhoodVerifyScreen()));
                }
                return;
              }

              if (context.mounted) {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ProductRegisterScreen()),
                );
              }
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
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2)),
              ],
            ),
            child: Row(
              children: [
                Icon(Icons.search, color: Colors.grey[500], size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) => setState(() => _searchQuery = value.trim()),
                    decoration: InputDecoration(
                      hintText: '상품명 또는 카테고리를 검색하세요',
                      hintStyle: TextStyle(color: Colors.grey[500], fontSize: 13),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
                if (_searchQuery.isNotEmpty)
                  GestureDetector(
                    onTap: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                    child: Icon(Icons.close, size: 16, color: Colors.grey[400]),
                  ),
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

  Widget _statusFilterBar() {
    final filters = ['전체', '판매중', '예약중', '판매완료'];
    return SizedBox(
      height: 34,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: filters.map((label) {
          final selected = _statusFilter == label;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => setState(() => _statusFilter = label),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: selected ? _green : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: selected ? _green : Colors.grey[300]!),
                ),
                child: Text(label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                      color: selected ? Colors.white : Colors.grey[600],
                    )),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _categoryFilterBar() {
    return SizedBox(
      height: 34,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: _categories.map((label) {
          final selected = _categoryFilter == label;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => setState(() => _categoryFilter = label),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: selected ? _greenLight : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: selected ? _green : Colors.grey[300]!),
                ),
                child: Text(label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                      color: selected ? _green : Colors.grey[600],
                    )),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _myDongToggle() {
    if (_myVerifiedDong == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: () => setState(() => _myDongOnly = !_myDongOnly),
        child: Row(
          children: [
            Icon(
              _myDongOnly ? Icons.check_box : Icons.check_box_outline_blank,
              size: 18,
              color: _myDongOnly ? _green : Colors.grey[400],
            ),
            const SizedBox(width: 6),
            Text('내 동네만 보기 ($_myVerifiedDong)',
                style: TextStyle(fontSize: 12, color: _myDongOnly ? _green : Colors.grey[600])),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildDdaengMarketTab() {
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
      _categoryFilterBar(),
      const SizedBox(height: 16),
      const Text('지금 최저가 상품', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
      const SizedBox(height: 12),
      StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('ddaengMarketItems')
            .orderBy('order')
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()));
          }

          final filteredDocs = snapshot.data!.docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final matchesCategory = _categoryFilter == '전체' || data['category'] == _categoryFilter;
            final matchesSearch = _searchQuery.isEmpty ||
                (data['name'] as String).toLowerCase().contains(_searchQuery.toLowerCase()) ||
                (data['category'] as String).toLowerCase().contains(_searchQuery.toLowerCase());
            return matchesCategory && matchesSearch;
          }).toList();

          if (filteredDocs.isEmpty) {
            return Padding(
              padding: const EdgeInsets.all(40),
              child: Center(child: Text('조건에 맞는 상품이 없어요', style: TextStyle(color: Colors.grey[500]))),
            );
          }

          return GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.85,
            children: filteredDocs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return _dummyPriceCard(doc.id, data);
            }).toList(),
          );
        },
      ),
    ];
  }

  Widget _dummyPriceCard(String itemId, Map<String, dynamic> item) {
    final isFav = _favoriteIds.contains(itemId);
    final comparisons = (item['priceComparisons'] as List<dynamic>? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList()
      ..sort((a, b) => (a['price'] as num).compareTo(b['price'] as num));

    final lowestPrice = comparisons.isNotEmpty ? comparisons.first['price'] as num : 0;

    return GestureDetector(
      onTap: () => _showPriceComparisonSheet(context, item['name'] as String, comparisons),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2)),
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
                    child: item['image'] != null
                        ? Image.network(
                      item['image'] as String,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          Icon(Icons.image_outlined, color: _green.withValues(alpha: 0.35), size: 28),
                    )
                        : Icon(Icons.image_outlined, color: _green.withValues(alpha: 0.35), size: 28),
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
                          BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 4),
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
                const Positioned(
                  left: 6,
                  bottom: 6,
                  child: Icon(Icons.open_in_new, size: 14, color: Colors.white70),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(item['name'] as String,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Text('${NumberFormat('#,###').format(lowestPrice)}원',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(color: _greenLight, borderRadius: BorderRadius.circular(6)),
              child: Text('${comparisons.length}개 쇼핑몰 비교',
                  style: TextStyle(fontSize: 10, color: _green, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  void _showPriceComparisonSheet(
      BuildContext context, String productName, List<Map<String, dynamic>> comparisons) {
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
              Text(productName,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('${comparisons.length}개 쇼핑몰 가격 비교',
                  style: TextStyle(fontSize: 12, color: Colors.grey[500])),
              const SizedBox(height: 16),
              ...comparisons.asMap().entries.map((entry) {
                final isLowest = entry.key == 0; // 이미 가격순 정렬되어 있음
                final item = entry.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: GestureDetector(
                    onTap: () async {
                      final url = Uri.parse(item['url'] as String);
                      if (await canLaunchUrl(url)) {
                        await launchUrl(url, mode: LaunchMode.externalApplication);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isLowest ? _greenLight : Colors.grey[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: isLowest ? _green : Colors.grey[200]!),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(item['source'] as String,
                                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                    if (isLowest) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(color: _green, borderRadius: BorderRadius.circular(4)),
                                        child: const Text('최저가',
                                            style: TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold)),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text('${NumberFormat('#,###').format(item['price'])}원',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: isLowest ? _green : Colors.black87,
                                    )),
                              ],
                            ),
                          ),
                          Icon(Icons.chevron_right, color: Colors.grey[400]),
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


  List<Widget> _buildFleaMarketTab() {
    return [
      _myDongBanner(),
      const SizedBox(height: 6),
      _myDongToggle(),
      const SizedBox(height: 8),
      _statusFilterBar(),
      const SizedBox(height: 8),
      _categoryFilterBar(),
      const SizedBox(height: 12),
      StreamBuilder<List<MarketProduct>>(
        stream: _service.getProducts(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()));
          }
          final products = snapshot.data!.where((p) {
            final matchesStatus = _statusFilter == '전체'
                ? true
                : _statusFilter == '판매중'
                ? p.status == ProductStatus.selling
                : _statusFilter == '예약중'
                ? p.status == ProductStatus.reserved
                : p.status == ProductStatus.sold;

            final matchesCategory = _categoryFilter == '전체' || p.category == _categoryFilter;

            final matchesSearch = _searchQuery.isEmpty ||
                p.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                p.category.toLowerCase().contains(_searchQuery.toLowerCase());

            final matchesDong = !_myDongOnly || p.verifiedDong == _myVerifiedDong;

            return matchesStatus && matchesCategory && matchesSearch && matchesDong;
          }).toList();

          if (products.isEmpty) {
            return Padding(
              padding: const EdgeInsets.all(40),
              child: Center(child: Text('조건에 맞는 상품이 없어요', style: TextStyle(color: Colors.grey[500]))),
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

    String statusLabel(ProductStatus status) {
      switch (status) {
        case ProductStatus.selling:
          return '판매중';
        case ProductStatus.reserved:
          return '예약중';
        case ProductStatus.sold:
          return '판매완료';
      }
    }

    Color statusColor(ProductStatus status) {
      switch (status) {
        case ProductStatus.selling:
          return _green;
        case ProductStatus.reserved:
          return Colors.orange;
        case ProductStatus.sold:
          return Colors.grey;
      }
    }

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
                  child: product.images.isEmpty
                      ? Icon(Icons.image_outlined, color: _green.withOpacity(0.4))
                      : TappableProductImage(
                    imageUrl: product.images.first,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => ProductDetailScreen(product: product)),
                    ),
                  ),
                ),
                Positioned(
                  left: 6,
                  top: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: statusColor(product.status),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      statusLabel(product.status),
                      style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                Positioned(
                  right: 4,
                  top: 4,
                  child: GestureDetector(
                    onTap: () => _toggleFavorite(product.productId),
                    child: Container(
                      padding: const EdgeInsets.all(5),
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
              ],
            ),
            const SizedBox(height: 8),
            Text(product.title,
                style: const TextStyle(fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Text('${NumberFormat('#,###').format(product.price)}원',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),

            // 급처/네고가능/직거래 태그
            if (product.isUrgent || product.isNegotiable || product.isDirectDeal) ...[
              const SizedBox(height: 4),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: [
                  if (product.isUrgent) _tagChip('급처', Colors.redAccent),
                  if (product.isNegotiable) _tagChip('네고가능', _green),
                  if (product.isDirectDeal) _tagChip('직거래', Colors.blueGrey),
                ],
              ),
            ],
            const SizedBox(height: 6),
            // 판매자 닉네임 + 아바타
            Row(
              children: [
                CircleAvatar(
                  radius: 7,
                  backgroundColor: Colors.grey[200],
                  backgroundImage: product.sellerAvatarUrl.isNotEmpty
                      ? NetworkImage(product.sellerAvatarUrl)
                      : null,
                  child: product.sellerAvatarUrl.isEmpty
                      ? Icon(Icons.person_outline, size: 9, color: Colors.grey[400])
                      : null,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(product.sellerName,
                      style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              _timeAgo(product.createdAt),
              style: TextStyle(fontSize: 10, color: Colors.grey[400]),
            ),
          ],
        ),
      ),
    );
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

  Widget _tagChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label, style: TextStyle(fontSize: 9, color: color, fontWeight: FontWeight.w500)),
    );
  }
}