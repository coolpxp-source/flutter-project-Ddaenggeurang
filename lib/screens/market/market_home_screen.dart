import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ddaenggeurang/screens/profile/neighborhood_verify_screen.dart';
import 'package:ddaenggeurang/widgets/common/app_drawer.dart';
import 'package:ddaenggeurang/widgets/common/app_header.dart';
import 'package:ddaenggeurang/widgets/common/ddaeng_modal.dart';

import '../../services/chat_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
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

  final PageController _adController = PageController();
  int _adIndex = 0;

  static const _adBanners = [
    (
    imagePath: 'assets/images/ad_banner_sale.png',
    title: '이번 주 특가 상품',
    subtitle: '',
    icon: Icons.local_fire_department_rounded,
    url: 'https://example.com/promo2',
    ),
    (
    imagePath: 'assets/images/ad_banner_pick.png',
    title: '땡그랑 픽 아이템',
    subtitle: '',
    icon: Icons.star_rounded,
    url: 'https://example.com/promo3',
    ),
  ];

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

  /// 앱바 우측 채팅 아이콘 (플리마켓 탭에서만 노출, 탭 전환 시 깜빡임 방지를 위해 Visibility로 유지)
  /// 헤더 우측 커뮤니티로 돌아가는 알약 배너 (커뮤니티 헤더의 "마켓 바로가기!" 칩과 동일한 스타일)
  ///
  /// X를 누르면 세션 동안 숨김, 배너 자체를 탭하면 커뮤니티로 이동
  Widget _buildCommunityBackAction() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_showCommunityPill) ...[
          GestureDetector(
            onTap: () => Navigator.of(context).maybePop(),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.only(left: 10, right: 6, top: 5, bottom: 5),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [_gradientStart, _gradientEnd]),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('커뮤니티 홈',
                          style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 4),
                      GestureDetector(
                        onTap: () => setState(() => _showCommunityPill = false),
                        child: const Icon(Icons.close, size: 12, color: Colors.white70),
                      ),
                    ],
                  ),
                ),
                Transform.translate(
                  offset: const Offset(-2, 0),
                  child: ClipPath(
                    clipper: _RightTailClipper(),
                    child: Container(width: 6, height: 12, color: _gradientEnd),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
        ],
        IconButton(
          icon: const Icon(Icons.groups_rounded),
          tooltip: '커뮤니티로 돌아가기',
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ],
    );
  }

  Widget _buildChatAction() {
    return Visibility(
      visible: _tabIndex == 1,
      maintainState: true,
      maintainAnimation: true,
      maintainSize: false,
      child: IconButton(
        icon: StreamBuilder<int>(
          stream: ChatService().getTotalUnreadCount(_myId),
          builder: (context, snapshot) {
            final unreadCount = snapshot.data ?? 0;
            return Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.chat_bubble_outline_rounded, size: 24),
                if (unreadCount > 0)
                  Positioned(
                    top: -4,
                    right: -4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE5735A),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white, width: 1.4),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        unreadCount > 9 ? '9+' : '$unreadCount',
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          height: 1.2,
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
        tooltip: '채팅',
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ChatListScreen()),
        ),
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
  String _priceFilter = '전체';
  bool _showCommunityPill = true;

  static const _priceFilters = ['전체', '1만원 이하', '1~2만원', '2~3만원', '3~4만원', '5만원 이상'];

  bool _matchesPriceFilter(num price) {
    switch (_priceFilter) {
      case '1만원 이하':
        return price <= 10000;
      case '1~2만원':
        return price > 10000 && price <= 20000;
      case '2~3만원':
        return price > 20000 && price <= 30000;
      case '3~4만원':
        return price > 30000 && price <= 40000;
      case '5만원 이상':
        return price >= 50000;
      default:
        return true;
    }
  }

  static const _categories = ['전체', '전자기기', '의류', '도서', '가구', '생활용품', '기타'];

  static const Map<String, IconData> _categoryIcons = {
    '전체': Icons.apps_rounded,
    '전자기기': Icons.devices_rounded,
    '의류': Icons.checkroom_rounded,
    '도서': Icons.menu_book_rounded,
    '가구': Icons.weekend_rounded,
    '생활용품': Icons.local_cafe_rounded,
    '기타': Icons.category_rounded,
  };

  @override
  void dispose() {
    _searchController.dispose();
    _adController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      drawer: const AppDrawer(),
      appBar: buildDdaengHeader(
        context,
        _myId,
        inkColor: Colors.black87,
        extraActions: [_buildCommunityBackAction(), _buildChatAction()],
      ),
        body: Stack(
          children: [
            _buildContent(),
            if (_tabIndex == 1)
              Positioned(
                right: 16,
                bottom: 16,
                child: FloatingActionButton(
                  backgroundColor: const Color(0xFFFFA733),
                  onPressed: _openFleaMarketSheet,
                  child: const Icon(Icons.add, color: Colors.white),
                ),
              ),
          ],
        ),
      bottomNavigationBar: BottomNavBar(
        currentTab: NavTab.community,
        onTabSelected: (tab) {
          if (tab == NavTab.community) return;
          Navigator.of(context).pop();
        },
      ),
    );
  }

  void _openFleaMarketSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(12, 4, 12, 12),
                  child: Text('무엇을 하시겠어요?',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                ),
                ListTile(
                  leading: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(color: _greenLight, shape: BoxShape.circle),
                    child: Icon(Icons.add, color: _green, size: 18),
                  ),
                  title: const Text('상품 등록', style: TextStyle(fontWeight: FontWeight.w600)),
                  onTap: () async {
                    Navigator.pop(sheetContext);
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
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const ProductRegisterScreen()));
                    }
                  },
                ),
                ListTile(
                  leading: Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(color: Color(0xFFF1ECFA), shape: BoxShape.circle),
                    child: const Icon(Icons.inventory_2_outlined, color: Color(0xFF9B7EDE), size: 18),
                  ),
                  title: const Text('내 상품', style: TextStyle(fontWeight: FontWeight.w600)),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const MyProductsScreen()));
                  },
                ),
                ListTile(
                  leading: Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(color: Color(0xFFFBECE9), shape: BoxShape.circle),
                    child: const Icon(Icons.favorite_border, color: Color(0xFFE5735A), size: 18),
                  ),
                  title: const Text('내 찜', style: TextStyle(fontWeight: FontWeight.w600)),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const MyFavoritesScreen()));
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // 땡그랑마켓/플리마켓 공통 콘텐츠 — 원형 메뉴 유무와 상관없이 동일하게 재사용
  Widget _buildContent() {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        children: [
          // 탭 (하단에 각 탭 설명 캡션 포함)
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
                Expanded(child: _tabButton('땡그랑 마켓', 0, hint: '최저가 보러가기')),
                Expanded(child: _tabButton('플리마켓', 1, hint: '내 동네 보러가기')),
              ],
            ),
          ),
          const SizedBox(height: 10),

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
          const SizedBox(height: 12),
          if (_tabIndex == 0) ..._buildDdaengMarketTab(),
          if (_tabIndex == 1) ..._buildFleaMarketTab(),
        ],
      ),
    );
  }

  Widget _tabButton(String label, int index, {String? hint}) {
    final selected = _tabIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _tabIndex = index),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          gradient: selected
              ? const LinearGradient(colors: [_gradientStart, _gradientEnd])
              : null,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                color: selected ? Colors.white : Colors.grey[500],
              ),
            ),
            if (hint != null) ...[
              const SizedBox(height: 1),
              Text(
                hint,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.white : _green,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _statusFilterBar() {
    final filters = ['전체', '판매중', '예약중', '판매완료'];
    return SizedBox(
      height: 28,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: filters.map((label) {
          final selected = _statusFilter == label;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => setState(() => _statusFilter = label),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
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
      height: 28,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: _categories.map((label) {
          final selected = _categoryFilter == label;
          final icon = _categoryIcons[label] ?? Icons.category_rounded;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => setState(() => _categoryFilter = label),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: selected ? _greenLight : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: selected ? _green : Colors.grey[300]!),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      icon,
                      size: 14,
                      color: selected ? _green : Colors.grey[500],
                    ),
                    const SizedBox(width: 4),
                    Text(label,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                          color: selected ? _green : Colors.grey[600],
                        )),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _priceFilterBar() {
    return SizedBox(
      height: 28,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: _priceFilters.map((label) {
          final selected = _priceFilter == label;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => setState(() => _priceFilter = label),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: selected ? _greenLight : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: selected ? _green : Colors.grey[300]!),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (label == '전체')
                      Icon(Icons.sell_outlined, size: 13, color: selected ? _green : Colors.grey[500])
                    else
                      Icon(Icons.attach_money_rounded, size: 13, color: selected ? _green : Colors.grey[500]),
                    const SizedBox(width: 3),
                    Text(label,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                          color: selected ? _green : Colors.grey[600],
                        )),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  /// 카테고리/가격대/상태 필터 중 하나라도 기본값이 아니면 노출되는 초기화 버튼
  Widget _buildFilterResetRow() {
    final bool anyActive =
        _categoryFilter != '전체' || _priceFilter != '전체' || _statusFilter != '전체';

    if (!anyActive) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Align(
        alignment: Alignment.centerRight,
        child: GestureDetector(
          onTap: () => setState(() {
            _categoryFilter = '전체';
            _priceFilter = '전체';
            _statusFilter = '전체';
          }),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.refresh_rounded, size: 12, color: Colors.grey[600]),
                const SizedBox(width: 3),
                Text('필터 초기화',
                    style: TextStyle(fontSize: 11, color: Colors.grey[600], fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _myDongToggle() {
    if (_myVerifiedDong == null) return const SizedBox.shrink();
    return GestureDetector(
      onTap: () => setState(() => _myDongOnly = !_myDongOnly),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _myDongOnly ? Icons.check_box : Icons.check_box_outline_blank,
            size: 18,
            color: _myDongOnly ? _green : Colors.grey[400],
          ),
          const SizedBox(width: 6),
          Text('내 동네만 보기',
              style: TextStyle(fontSize: 12, color: _myDongOnly ? _green : Colors.grey[600])),
        ],
      ),
    );
  }

  List<Widget> _buildDdaengMarketTab() {
    return [
      AspectRatio(
        aspectRatio: 4.5,
        child: PageView.builder(
          controller: _adController,
          itemCount: _adBanners.length,
          onPageChanged: (i) => setState(() => _adIndex = i),
          itemBuilder: (context, i) {
            final ad = _adBanners[i];
            return GestureDetector(
              onTap: () async {
                final url = Uri.parse(ad.url);
                if (await canLaunchUrl(url)) {
                  await launchUrl(url, mode: LaunchMode.externalApplication);
                }
              },
              child: ad.imagePath != null
                  ? ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  width: double.infinity,
                  child: Image.asset(ad.imagePath!, fit: BoxFit.cover),
                ),
              )
                  : Container(
                margin: const EdgeInsets.symmetric(horizontal: 2),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [_gradientStart, _gradientEnd],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                clipBehavior: Clip.hardEdge,
                child: Stack(
                  children: [
                    Positioned(
                      right: -20,
                      top: -20,
                      child: Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.14),
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: const BoxDecoration(color: Colors.white24, shape: BoxShape.circle),
                          child: Icon(ad.icon, color: Colors.white, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(ad.title,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white)),
                              const SizedBox(height: 4),
                              Text(ad.subtitle,
                                  style: const TextStyle(fontSize: 12, color: Colors.white70)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
      const SizedBox(height: 8),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(_adBanners.length, (i) {
          return Container(
            width: _adIndex == i ? 16 : 6,
            height: 6,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
              color: _adIndex == i ? _gradientEnd : Colors.grey[300],
              borderRadius: BorderRadius.circular(3),
            ),
          );
        }),
      ),
      const SizedBox(height: 14),
      _categoryFilterBar(),
      const SizedBox(height: 6),
      _priceFilterBar(),
      _buildFilterResetRow(),
      const SizedBox(height: 12),
      Row(
        children: [
          const Expanded(
            child: Text('지금 최저가 상품', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          ),
          GestureDetector(
            onTap: _openDdaengFavoritesSheet,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: _greenLight,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.favorite_rounded, size: 13, color: _green),
                  const SizedBox(width: 4),
                  Text('내 찜', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _green)),
                ],
              ),
            ),
          ),
        ],
      ),
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
            final matchesPrice = _matchesPriceFilter(_lowestPriceOf(data));
            return matchesCategory && matchesSearch && matchesPrice;
          }).toList();

          if (filteredDocs.isEmpty) {
            return Padding(
              padding: const EdgeInsets.all(40),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.sentiment_dissatisfied_rounded, size: 30, color: Colors.grey[350]),
                    const SizedBox(height: 8),
                    Text('조건에 맞는 상품이 없어요', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                  ],
                ),
              ),
            );
          }

          return GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.72,
            children: filteredDocs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return _dummyPriceCard(doc.id, data);
            }).toList(),
          );
        },
      ),
    ];
  }

  /// ddaengMarketItems 문서에서 최저가를 계산
  num _lowestPriceOf(Map<String, dynamic> data) {
    final comparisons = (data['priceComparisons'] as List<dynamic>? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    if (comparisons.isEmpty) return 0;

    comparisons.sort((a, b) => (a['price'] as num).compareTo(b['price'] as num));
    return comparisons.first['price'] as num;
  }

  /// 땡그랑마켓 찜한 상품 모아보기 (플리마켓의 "내 찜"에 대응하는 화면이 없어서 바텀시트로 대체)
  void _openDdaengFavoritesSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(sheetContext).size.height * 0.75,
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('내 찜 상품', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 14),
                  Flexible(
                    child: StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('ddaengMarketItems')
                          .orderBy('order')
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const Padding(
                            padding: EdgeInsets.all(30),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }

                        final favoriteDocs = snapshot.data!.docs
                            .where((doc) => _favoriteIds.contains(doc.id))
                            .toList();

                        if (favoriteDocs.isEmpty) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 40),
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.favorite_border_rounded, size: 30, color: Colors.grey[350]),
                                  const SizedBox(height: 8),
                                  Text('찜한 상품이 없어요',
                                      style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                                ],
                              ),
                            ),
                          );
                        }

                        return GridView.count(
                          crossAxisCount: 2,
                          shrinkWrap: true,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 0.72,
                          children: favoriteDocs.map((doc) {
                            final data = doc.data() as Map<String, dynamic>;
                            return _dummyPriceCard(doc.id, data);
                          }).toList(),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
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
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  child: AspectRatio(
                    aspectRatio: 4 / 3,
                    child: Container(
                      width: double.infinity,
                      color: _greenLight,
                      child: item['image'] != null
                          ? Image.network(
                        item['image'] as String,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            Icon(Icons.image_outlined, color: _green.withValues(alpha: 0.35), size: 30),
                      )
                          : Icon(Icons.image_outlined, color: _green.withValues(alpha: 0.35), size: 30),
                    ),
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
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${NumberFormat('#,###').format(lowestPrice)}원',
                      style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 3),
                  Text(item['name'] as String,
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 7),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: _greenLight, borderRadius: BorderRadius.circular(6)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.compare_arrows_rounded, size: 11, color: _green),
                        const SizedBox(width: 3),
                        Text('${comparisons.length}개 쇼핑몰 비교',
                            style: TextStyle(fontSize: 10, color: _green, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ],
              ),
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
                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
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
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _myDongBanner(),
          _myDongToggle(),
        ],
      ),
      const SizedBox(height: 6),
      _statusFilterBar(),
      const SizedBox(height: 6),
      _categoryFilterBar(),
      const SizedBox(height: 6),
      _priceFilterBar(),
      _buildFilterResetRow(),
      const SizedBox(height: 10),
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

            final matchesPrice = _matchesPriceFilter(p.price);

            return matchesStatus && matchesCategory && matchesSearch && matchesDong && matchesPrice;
          }).toList();

          if (products.isEmpty) {
            return Padding(
              padding: const EdgeInsets.all(40),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.sentiment_dissatisfied_rounded, size: 30, color: Colors.grey[350]),
                    const SizedBox(height: 8),
                    Text('조건에 맞는 상품이 없어요', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                  ],
                ),
              ),
            );
          }
          return GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.62,
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

    // 파스텔 배지 — 진한 단색 대신 연한 배경 + 진한 텍스트로 톤 다운
    Color statusBg(ProductStatus status) {
      switch (status) {
        case ProductStatus.selling:
          return const Color(0xFFFFE9DC);
        case ProductStatus.reserved:
          return const Color(0xFFFFF3D6);
        case ProductStatus.sold:
          return const Color(0xFFEDEDED);
      }
    }

    Color statusText(ProductStatus status) {
      switch (status) {
        case ProductStatus.selling:
          return _green;
        case ProductStatus.reserved:
          return const Color(0xFFC98A00);
        case ProductStatus.sold:
          return Colors.grey[600]!;
      }
    }

    IconData statusIcon(ProductStatus status) {
      switch (status) {
        case ProductStatus.selling:
          return Icons.local_fire_department_rounded;
        case ProductStatus.reserved:
          return Icons.schedule_rounded;
        case ProductStatus.sold:
          return Icons.check_circle_rounded;
      }
    }

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
                    child: Container(
                      width: double.infinity,
                      color: _greenLight,
                      child: product.images.isEmpty
                          ? Icon(Icons.image_outlined, color: _green.withOpacity(0.4), size: 30)
                          : TappableProductImage(
                        imageUrl: product.images.first,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => ProductDetailScreen(product: product)),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 6,
                  top: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: statusBg(product.status),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(statusIcon(product.status), size: 10, color: statusText(product.status)),
                        const SizedBox(width: 3),
                        Text(
                          statusLabel(product.status),
                          style: TextStyle(
                            fontSize: 9,
                            color: statusText(product.status),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
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

                  // 급처/네고가능/직거래 태그
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
                  const SizedBox(height: 8),
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
                  if (product.verifiedDong != null) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(Icons.location_on, size: 10, color: Colors.grey[400]),
                        const SizedBox(width: 1),
                        Text(
                          product.verifiedDong!,
                          style: TextStyle(fontSize: 10, color: Colors.grey[400]),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
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

  Widget _tagChip(String label, Color color, [IconData? icon]) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 9, color: color),
            const SizedBox(width: 2),
          ],
          Text(label, style: TextStyle(fontSize: 9, color: color, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}


/// 커뮤니티 배너 알약 오른쪽에 붙는 뾰족한 말풍선 꼬리
class _RightTailClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.moveTo(0, 0);
    path.lineTo(size.width, size.height / 2);
    path.lineTo(0, size.height);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}