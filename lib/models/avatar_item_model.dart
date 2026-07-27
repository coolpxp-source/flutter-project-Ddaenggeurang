class AvatarItem {
  final String id;
  final String name;
  final String slot;
  final String rarity;
  final String assetPath;
  final int price;
  final int unlockLevel;
  final String imageUrl;
  final bool isOwned;
  final bool isEquipped;

  const AvatarItem({
    required this.id,
    required this.name,
    required this.slot,
    required this.rarity,
    required this.assetPath,
    required this.price,
    required this.unlockLevel,
    required this.imageUrl,
    this.isOwned = false,
    this.isEquipped = false,
  });

  // Firestore 데이터를 AvatarItem 객체로 변환하는 메서드
  factory AvatarItem.fromMap(
      String id,
      Map<String, dynamic> map,
      ) {
    return AvatarItem(
      id: id,
      name: map['name'] as String? ?? '',
      slot: map['slot'] as String? ?? '',
      rarity: map['rarity'] as String? ?? 'common',
      assetPath: map['assetPath'] as String? ?? '',
      price: (map['price'] as num?)?.toInt() ?? 0,
      unlockLevel:
      (map['unlockLevel'] as num?)?.toInt() ?? 1,
      imageUrl: map['imageUrl'] as String? ?? '',
    );
  }

  // AvatarItem 객체를 Firestore 저장용 Map으로 변환하는 메서드
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'slot': slot,
      'rarity': rarity,
      'assetPath': assetPath,
      'price': price,
      'unlockLevel': unlockLevel,
      'imageUrl': imageUrl,
    };
  }

  // 보유 및 장착 상태를 변경한 새 객체를 반환하는 메서드
  AvatarItem copyWith({
    String? rarity,
    String? assetPath,
    bool? isOwned,
    bool? isEquipped,
  }) {
    return AvatarItem(
      id: id,
      name: name,
      slot: slot,
      rarity: rarity ?? this.rarity,
      assetPath: assetPath ?? this.assetPath,
      price: price,
      unlockLevel: unlockLevel,
      imageUrl: imageUrl,
      isOwned: isOwned ?? this.isOwned,
      isEquipped: isEquipped ?? this.isEquipped,
    );
  }
}