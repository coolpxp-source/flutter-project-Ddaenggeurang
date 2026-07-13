import '../models/avatar_item_model.dart';

class AvatarService {
  int _points = 2450;

  final List<AvatarItem> _items = const [
    AvatarItem(
      id: 'basic_hat',
      name: '기본 모자',
      slot: 'hat',
      price: 0,
      unlockLevel: 1,
      imageUrl: '',
      isOwned: true,
      isEquipped: true,
    ),
    AvatarItem(
      id: 'crown',
      name: '왕관',
      slot: 'hat',
      price: 500,
      unlockLevel: 1,
      imageUrl: '',
    ),
    AvatarItem(
      id: 'baseball_cap',
      name: '야구모자',
      slot: 'hat',
      price: 300,
      unlockLevel: 1,
      imageUrl: '',
    ),
    AvatarItem(
      id: 'party_hat',
      name: '파티모자',
      slot: 'hat',
      price: 700,
      unlockLevel: 5,
      imageUrl: '',
    ),
    AvatarItem(
      id: 'basic_clothes',
      name: '기본 옷',
      slot: 'clothes',
      price: 0,
      unlockLevel: 1,
      imageUrl: '',
      isOwned: true,
    ),
    AvatarItem(
      id: 'sneakers',
      name: '운동화',
      slot: 'shoes',
      price: 200,
      unlockLevel: 1,
      imageUrl: '',
    ),
  ];

  Future<int> getPoints() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return _points;
  }

  Future<List<AvatarItem>> getItems() async {
    await Future.delayed(const Duration(milliseconds: 500));
    return List.from(_items);
  }

  Future<bool> purchaseItem(AvatarItem item) async {
    await Future.delayed(const Duration(milliseconds: 500));

    if (item.isOwned || _points < item.price) {
      return false;
    }

    _points -= item.price;
    return true;
  }
}