import 'package:flutter/material.dart';

import '../../models/avatar_item_model.dart';

class AvatarItemCard extends StatelessWidget {
  final AvatarItem item;
  final int userLevel;
  final VoidCallback? onTap;

  const AvatarItemCard({
    super.key,
    required this.item,
    required this.userLevel,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF20A67A);

    final isLocked = userLevel < item.unlockLevel;

    return InkWell(
      onTap: isLocked ? null : onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: item.isEquipped
                ? primaryColor
                : const Color(0xFFE7ECE9),
            width: item.isEquipped ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Align(
              alignment: Alignment.topRight,
              child: item.isEquipped
                  ? const Text(
                '착용중',
                style: TextStyle(
                  color: primaryColor,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              )
                  : const SizedBox(height: 14),
            ),
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: isLocked
                    ? const Color(0xFFF3F4F3)
                    : const Color(0xFFEEF8F3),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(
                isLocked ? Icons.lock_outline : _getIcon(item.slot),
                color: isLocked
                    ? const Color(0xFFB9BEBC)
                    : primaryColor,
                size: 30,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              item.name,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isLocked
                    ? const Color(0xFFB6BAB8)
                    : const Color(0xFF53615C),
              ),
            ),
            const SizedBox(height: 5),
            Text(
              isLocked
                  ? 'Lv.${item.unlockLevel} 해금'
                  : item.isOwned
                  ? '보유중'
                  : '${item.price} P',
              style: TextStyle(
                color: isLocked
                    ? const Color(0xFFC1C4C2)
                    : primaryColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getIcon(String slot) {
    switch (slot) {
      case 'hat':
        return Icons.checkroom;
      case 'clothes':
        return Icons.dry_cleaning;
      case 'shoes':
        return Icons.ice_skating;
      default:
        return Icons.star_outline;
    }
  }
}