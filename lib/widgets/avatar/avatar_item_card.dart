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
    const pinkColor = Color(0xFFFF68AE);
    const purpleColor = Color(0xFF8566FF);

    final isLocked = userLevel < item.unlockLevel;

    return InkWell(
      onTap: isLocked ? null : onTap,
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: item.isEquipped
                ? pinkColor
                : const Color(0xFFE8E9EF),
            width: item.isEquipped ? 2 : 1,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0D000000),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Align(
              alignment: Alignment.topRight,
              child: _buildStatusBadge(
                isLocked: isLocked,
                pinkColor: pinkColor,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              width: 66,
              height: 66,
              decoration: BoxDecoration(
                color: isLocked
                    ? const Color(0xFFF1F2F5)
                    : const Color(0xFFFFF0F6),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(
                isLocked ? Icons.lock_outline : _getIcon(item.slot),
                size: 32,
                color: isLocked
                    ? const Color(0xFFB5B7C0)
                    : pinkColor,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              item.name,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: isLocked
                    ? const Color(0xFFB2B4BC)
                    : const Color(0xFF343644),
              ),
            ),
            const SizedBox(height: 5),
            Text(
              _buildBottomText(isLocked),
              style: TextStyle(
                color: isLocked
                    ? const Color(0xFFB9BBC2)
                    : item.isOwned
                    ? pinkColor
                    : purpleColor,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge({
    required bool isLocked,
    required Color pinkColor,
  }) {
    if (isLocked) {
      return const Text(
        '잠김',
        style: TextStyle(
          color: Color(0xFFB6B8C0),
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      );
    }

    if (item.isEquipped) {
      return Text(
        '착용중',
        style: TextStyle(
          color: pinkColor,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      );
    }

    if (item.isOwned) {
      return const Text(
        '보유중',
        style: TextStyle(
          color: Color(0xFF6E7180),
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      );
    }

    return const SizedBox(height: 14);
  }

  String _buildBottomText(bool isLocked) {
    if (isLocked) {
      return 'Lv.${item.unlockLevel} 해금';
    }

    if (item.isOwned) {
      return '보유중';
    }

    return '${item.price} P';
  }

  IconData _getIcon(String slot) {
    switch (slot) {
      case 'hat':
        return Icons.checkroom;
      case 'clothes':
        return Icons.dry_cleaning;
      case 'shoes':
        return Icons.ice_skating;
      case 'accessory':
        return Icons.auto_awesome;
      default:
        return Icons.star_outline;
    }
  }
}