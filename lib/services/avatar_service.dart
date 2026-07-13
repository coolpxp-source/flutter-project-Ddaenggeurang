import '../models/avatar_item_model.dart';

class AvatarService {
  AvatarService._();

  static final AvatarService instance = AvatarService._();

  int _points = 2450;

  final List<AvatarItem> _items = [
    const AvatarItem(
      id: 'basic_hat',
      name: '기본 모자',
      slot: 'hat',
      price: 0,
      unlockLevel: 1,
      imageUrl: '',
      isOwned: true,
      isEquipped: true,
    ),
    const AvatarItem(
      id: 'crown',
      name: '저축 왕관',
      slot: 'hat',
      price: 500,
      unlockLevel: 1,
      imageUrl: '',
    ),
    const AvatarItem(
      id: 'baseball_cap',
      name: '야구모자',
      slot: 'hat',
      price: 300,
      unlockLevel: 1,
      imageUrl: '',
    ),
    const AvatarItem(
      id: 'party_hat',
      name: '파티모자',
      slot: 'hat',
      price: 700,
      unlockLevel: 10,
      imageUrl: '',
    ),
    const AvatarItem(
      id: 'basic_clothes',
      name: '기본 옷',
      slot: 'clothes',
      price: 0,
      unlockLevel: 1,
      imageUrl: '',
      isOwned: true,
      isEquipped: true,
    ),
    const AvatarItem(
      id: 'pink_clothes',
      name: '핑크 패딩',
      slot: 'clothes',
      price: 250,
      unlockLevel: 1,
      imageUrl: '',
    ),
    const AvatarItem(
      id: 'basic_shoes',
      name: '기본 신발',
      slot: 'shoes',
      price: 0,
      unlockLevel: 1,
      imageUrl: '',
      isOwned: true,
      isEquipped: true,
    ),
    const AvatarItem(
      id: 'sneakers',
      name: '운동화',
      slot: 'shoes',
      price: 200,
      unlockLevel: 1,
      imageUrl: '',
    ),
    const AvatarItem(
      id: 'sunglasses',
      name: '선글라스',
      slot: 'accessory',
      price: 300,
      unlockLevel: 1,
      imageUrl: '',
    ),
  ];

  Future<int> getPoints() async {
    await Future.delayed(const Duration(milliseconds: 200));
    return _points;
  }

  Future<List<AvatarItem>> getItems() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return List<AvatarItem>.from(_items);
  }

  Future<bool> purchaseItem(String itemId) async {
    await Future.delayed(const Duration(milliseconds: 300));

    final index = _items.indexWhere((item) => item.id == itemId);

    if (index == -1) {
      return false;
    }

    final item = _items[index];

    if (item.isOwned || _points < item.price) {
      return false;
    }

    _points -= item.price;

    _items[index] = item.copyWith(
      isOwned: true,
    );

    return true;
  }

  Future<bool> equipItem(String itemId) async {
    await Future.delayed(const Duration(milliseconds: 200));

    final selectedIndex = _items.indexWhere(
          (item) => item.id == itemId,
    );

    if (selectedIndex == -1 || !_items[selectedIndex].isOwned) {
      return false;
    }

    final selectedItem = _items[selectedIndex];

    for (int i = 0; i < _items.length; i++) {
      final item = _items[i];

      if (item.slot == selectedItem.slot) {
        _items[i] = item.copyWith(
          isEquipped: item.id == selectedItem.id,
        );
      }
    }

    return true;
  }
}