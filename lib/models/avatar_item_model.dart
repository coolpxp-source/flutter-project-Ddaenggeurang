class AvatarItem {
  final String id;
  final String name;
  final String slot;
  final int price;
  final int unlockLevel;
  final String imageUrl;
  final bool isOwned;
  final bool isEquipped;

  const AvatarItem({
    required this.id,
    required this.name,
    required this.slot,
    required this.price,
    required this.unlockLevel,
    required this.imageUrl,
    this.isOwned = false,
    this.isEquipped = false,
  });

  factory AvatarItem.fromMap(
      String id,
      Map<String, dynamic> map,
      ) {
    return AvatarItem(
      id: id,
      name: map['name'] as String? ?? '',
      slot: map['slot'] as String? ?? '',
      price: (map['price'] as num?)?.toInt() ?? 0,
      unlockLevel:
      (map['unlockLevel'] as num?)?.toInt() ?? 1,
      imageUrl: map['imageUrl'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'slot': slot,
      'price': price,
      'unlockLevel': unlockLevel,
      'imageUrl': imageUrl,
    };
  }

  AvatarItem copyWith({
    bool? isOwned,
    bool? isEquipped,
  }) {
    return AvatarItem(
      id: id,
      name: name,
      slot: slot,
      price: price,
      unlockLevel: unlockLevel,
      imageUrl: imageUrl,
      isOwned: isOwned ?? this.isOwned,
      isEquipped: isEquipped ?? this.isEquipped,
    );
  }
}