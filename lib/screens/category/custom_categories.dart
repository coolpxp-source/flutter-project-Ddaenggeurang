import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CustomCategoriesScreen extends StatefulWidget {
  const CustomCategoriesScreen({super.key});

  @override
  State<CustomCategoriesScreen> createState() => _CustomCategoriesScreenState();
}

class _CustomCategoriesScreenState extends State<CustomCategoriesScreen> with SingleTickerProviderStateMixin {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String? _userId = FirebaseAuth.instance.currentUser?.uid;

  bool _isLoading = true;
  List<Map<String, dynamic>> _defaultCategories = [];
  List<Map<String, dynamic>> _customCategories = [];
  List<String> _hiddenDefaultIds = [];

  // 1. 3가지 탭의 순서를 각각 기억할 리스트
  List<String> _expenseOrder = [];
  List<String> _incomeOrder = [];
  List<String> _savingOrder = []; // 저축 순서 추가!

  // 2. 탭 컨트롤러 길이 3으로 변경 및 3개의 스크롤 컨트롤러 세팅
  late TabController _tabController;
  final ScrollController _expenseScroll = ScrollController();
  final ScrollController _incomeScroll = ScrollController();
  final ScrollController _savingScroll = ScrollController(); // 저축 스크롤 추가!
  bool _showFab = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this); // length: 3
    _tabController.addListener(() => _scrollListener());
    _expenseScroll.addListener(_scrollListener);
    _incomeScroll.addListener(_scrollListener);
    _savingScroll.addListener(_scrollListener);
    _loadAllCategories();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _expenseScroll.dispose();
    _incomeScroll.dispose();
    _savingScroll.dispose();
    super.dispose();
  }

  // 활성화된 탭의 스크롤 컨트롤러를 찾아주는 헬퍼 함수
  ScrollController _getActiveScrollController() {
    if (_tabController.index == 0) return _expenseScroll;
    if (_tabController.index == 1) return _incomeScroll;
    return _savingScroll;
  }

  void _scrollListener() {
    ScrollController activeController = _getActiveScrollController();
    if (activeController.hasClients) {
      if (activeController.offset > 200 && !_showFab) {
        setState(() => _showFab = true);
      } else if (activeController.offset <= 200 && _showFab) {
        setState(() => _showFab = false);
      }
    }
  }

  void _scrollToTop() {
    ScrollController activeController = _getActiveScrollController();
    if (activeController.hasClients) {
      activeController.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    }
  }

  Future<void> _loadAllCategories() async {
    if (_userId == null) return;
    setState(() => _isLoading = true);

    try {
      final defaultSnap = await _db.collection('categories').get();
      _defaultCategories = defaultSnap.docs.map((doc) => {'id': doc.id, ...doc.data(), 'isCustom': false}).toList();

      final customSnap = await _db.collection('customCategories').where('userId', isEqualTo: _userId).get();
      _customCategories = customSnap.docs.map((doc) => {'id': doc.id, ...doc.data(), 'isCustom': true}).toList();

      final userDoc = await _db.collection('users').doc(_userId).get();
      if (userDoc.exists) {
        final data = userDoc.data()!;
        if (data.containsKey('hiddenCategories')) {
          _hiddenDefaultIds = List<String>.from(data['hiddenCategories']);
        }
        if (data.containsKey('expenseOrder')) _expenseOrder = List<String>.from(data['expenseOrder']);
        if (data.containsKey('incomeOrder')) _incomeOrder = List<String>.from(data['incomeOrder']);
        if (data.containsKey('savingsOrder')) _savingOrder = List<String>.from(data['savingsOrder']); // 저축 순서 로드!
      }

      setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('카테고리 로드 에러: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _onReorder(String type, List<String> currentOrder, int oldIndex, int newIndex) async {
    if (_userId == null) return;

    if (newIndex > oldIndex) newIndex -= 1;

    setState(() {
      final String item = currentOrder.removeAt(oldIndex);
      currentOrder.insert(newIndex, item);

      // 3. 타입에 맞게 로컬 순서 업데이트
      if (type == 'expense') {
        _expenseOrder = currentOrder;
      } else if (type == 'income') {
        _incomeOrder = currentOrder;
      } else if (type == 'saving') {
        _savingOrder = currentOrder;
      }
    });

    // 4. 파이어베이스에 저장할 필드명 결정
    String fieldName = 'expenseOrder';
    if (type == 'income') fieldName = 'incomeOrder';
    if (type == 'saving') fieldName = 'savingsOrder';

    try {
      await _db.collection('users').doc(_userId).set({
        fieldName: currentOrder,
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('순서 저장 에러: $e');
    }
  }

  Future<void> _toggleVisibility(Map<String, dynamic> category, bool isVisible) async {
    if (_userId == null) return;
    final String catId = category['id'];
    final bool isCustom = category['isCustom'];

    try {
      if (isCustom) {
        await _db.collection('customCategories').doc(catId).update({'isHidden': !isVisible});
        setState(() => category['isHidden'] = !isVisible);
      } else {
        if (isVisible) {
          await _db.collection('users').doc(_userId).set({
            'hiddenCategories': FieldValue.arrayRemove([catId])
          }, SetOptions(merge: true));
          setState(() => _hiddenDefaultIds.remove(catId));
        } else {
          await _db.collection('users').doc(_userId).set({
            'hiddenCategories': FieldValue.arrayUnion([catId])
          }, SetOptions(merge: true));
          setState(() => _hiddenDefaultIds.add(catId));
        }
      }
    } catch (e) {
      debugPrint('상태 변경 에러: $e');
    }
  }

  void _showAddCategoryDialog(String transactionType, String parentName, String nature) {
    final TextEditingController nameController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('[$parentName] 새 카테고리 추가'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(hintText: '예: 마라탕, 통신비 등', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.trim().isEmpty) return;
              Navigator.pop(context);

              await _db.collection('customCategories').add({
                'userId': _userId,
                'transactionType': transactionType,
                'parentName': parentName,
                'name': nameController.text.trim(),
                'nature': nature,
                'isHidden': false,
                'createdAt': FieldValue.serverTimestamp(),
              });
              _loadAllCategories();
            },
            child: const Text('추가'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black),
        title: const Text('카테고리 관리', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        bottom: TabBar(
          controller: _tabController,
          // 5. 탭 메뉴 3개로 확장
          tabs: const [Tab(text: '지출'), Tab(text: '수입'), Tab(text: '저축')],
          labelColor: Colors.black,
          indicatorColor: Colors.black,
          unselectedLabelColor: Colors.grey,
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      floatingActionButton: _showFab
          ? FloatingActionButton.small(
        onPressed: _scrollToTop,
        backgroundColor: const Color(0xFF6B8AFF),
        elevation: 4,
        child: const Icon(Icons.arrow_upward, color: Colors.white),
      )
          : null,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          _buildCharacterBanner(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildCategoryList('expense', _expenseScroll),
                _buildCategoryList('income', _incomeScroll),
                _buildCategoryList('saving', _savingScroll),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCharacterBanner() {
    return Container(
      margin: const EdgeInsets.all(16.0),
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
      decoration: BoxDecoration(
        color: const Color(0xFFFF6F91),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.pink.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            padding: const EdgeInsets.all(8),
            child: Image.asset('assets/images/characters/cat.png', fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => const Icon(Icons.pets, color: Colors.grey),
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Text(
              '카테고리는 숨김처리 하거나\n순서를 길게 눌러 이동할 수 있어요!',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryList(String type, ScrollController controller) {
    List<Map<String, dynamic>> combined = [
      ..._defaultCategories.where((c) => c['transactionType'] == type),
      ..._customCategories.where((c) => c['transactionType'] == type),
    ];

    Map<String, List<Map<String, dynamic>>> grouped = {};
    for (var cat in combined) {
      String parent = cat['parentName'] ?? '기타';
      if (!grouped.containsKey(parent)) grouped[parent] = [];
      grouped[parent]!.add(cat);
    }

    if (grouped.isEmpty) return const Center(child: Text('카테고리가 없습니다.'));

    List<String> orderedKeys = grouped.keys.toList();
    // 7. 렌더링 시 타입에 맞는 저장된 순서(Order) 매핑
    List<String> savedOrder = type == 'expense'
        ? _expenseOrder
        : type == 'income' ? _incomeOrder : _savingOrder;

    orderedKeys.sort((a, b) {
      int indexA = savedOrder.indexOf(a);
      int indexB = savedOrder.indexOf(b);
      if (indexA == -1 && indexB == -1) return a.compareTo(b);
      if (indexA == -1) return 1;
      if (indexB == -1) return -1;
      return indexA.compareTo(indexB);
    });

    return ReorderableListView(
      scrollController: controller,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      onReorder: (oldIndex, newIndex) => _onReorder(type, orderedKeys, oldIndex, newIndex),
      children: orderedKeys.map((parentName) {
        List<Map<String, dynamic>> children = grouped[parentName]!;
        String nature = children.isNotEmpty ? (children.first['nature'] ?? 'variable') : 'variable';

        return Card(
          key: ValueKey('${type}_$parentName'),
          elevation: 0,
          color: Colors.white,
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          child: ExpansionTile(
            key: PageStorageKey<String>('tile_${type}_$parentName'),
            title: Text(parentName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87)),
            initiallyExpanded: true,
            shape: const Border(),
            collapsedShape: const Border(),
            iconColor: Colors.indigo,
            children: [
              ...children.map((child) {
                bool isCustom = child['isCustom'];
                bool isVisible = isCustom ? !(child['isHidden'] ?? false) : !_hiddenDefaultIds.contains(child['id']);

                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                  title: Text(child['name'] ?? '이름 없음', style: const TextStyle(fontSize: 15, color: Colors.black87)),
                  subtitle: isCustom ? const Text('직접 추가함', style: TextStyle(color: Colors.indigo, fontSize: 11)) : null,
                  trailing: Switch(
                    value: isVisible,
                    activeColor: Colors.white,
                    activeTrackColor: const Color(0xFF6B8AFF),
                    onChanged: (value) => _toggleVisibility(child, value),
                  ),
                );
              }),

              Padding(
                padding: const EdgeInsets.only(bottom: 12.0, top: 4.0),
                child: TextButton.icon(
                  icon: const Icon(Icons.add, size: 18, color: Color(0xFF6B8AFF)),
                  label: Text('$parentName 카테고리 추가', style: const TextStyle(color: Color(0xFF6B8AFF), fontWeight: FontWeight.w600)),
                  onPressed: () => _showAddCategoryDialog(type, parentName, nature),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}