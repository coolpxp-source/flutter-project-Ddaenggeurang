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