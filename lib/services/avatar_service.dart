import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import '../models/avatar_item_model.dart';
import 'package:firebase_auth/firebase_auth.dart';


class AvatarService {
  AvatarService._();

  static final AvatarService instance = AvatarService._();

  final FirebaseFirestore _firestore =
  FirebaseFirestore.instanceFor(
    app: Firebase.app(),
    databaseId: '(default)',
  );

  String get _currentUserId {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      throw StateError('로그인된 사용자가 없습니다.');
    }

    return user.uid;
  }

  Future<int> getPoints() async {
    final userDoc = await _firestore
        .collection('users')
        .doc(_currentUserId)
        .get();

    final data = userDoc.data();

    return (data?['points'] as num?)?.toInt() ?? 0;
  }

  // 현재 사용자 닉네임 조회 메서드
  Future<String> getNickname() async {
    final userDoc = await _firestore
        .collection('users')
        .doc(_currentUserId)
        .get();

    final data = userDoc.data();
    final nickname = data?['nickname'] as String?;

    if (nickname == null || nickname.trim().isEmpty) {
      return '사용자';
    }

    return nickname.trim();
  }

  // 현재 사용자 레벨 조회 메서드
  Future<int> getLevel() async {
    final userDoc = await _firestore
        .collection('users')
        .doc(_currentUserId)
        .get();

    final data = userDoc.data();

    return (data?['level'] as num?)?.toInt() ?? 1;
  }

  Future<List<AvatarItem>> getItems() async {
    try {
      final userId = _currentUserId;

      final results = await Future.wait([
        _firestore
            .collection('avatarItems')
            .get(),
        _firestore
            .collection('users')
            .doc(userId)
            .get(),
        _firestore
            .collection('users')
            .doc(userId)
            .collection('ownedItems')
            .get(),
      ]);

      final avatarItemsSnapshot =
      results[0] as QuerySnapshot<Map<String, dynamic>>;

      final userSnapshot =
      results[1] as DocumentSnapshot<Map<String, dynamic>>;

      final ownedItemsSnapshot =
      results[2] as QuerySnapshot<Map<String, dynamic>>;

      final ownedItemIds = ownedItemsSnapshot.docs
          .map((doc) => doc.id)
          .toSet();

      final userData = userSnapshot.data();

      final equippedItems =
      Map<String, dynamic>.from(
        userData?['equippedItems'] ?? {},
      );

      return avatarItemsSnapshot.docs.map((doc) {
        final item = AvatarItem.fromMap(
          doc.id,
          doc.data(),
        );

        final equippedItemId =
        equippedItems[item.slot] as String?;

        return item.copyWith(
          isOwned: ownedItemIds.contains(item.id),
          isEquipped: equippedItemId == item.id,
        );
      }).toList();
    } catch (e) {
      debugPrint('아바타 아이템 조회 실패: $e');
      rethrow;
    }
  }

  Future<void> initializeDefaultAvatar() async {
    final userId = _currentUserId;

    final userRef = _firestore
        .collection('users')
        .doc(userId);

    final ownedItemsRef =
    userRef.collection('ownedItems');

    final ownedItemsSnapshot =
    await ownedItemsRef.limit(1).get();

    final userSnapshot = await userRef.get();
    final userData = userSnapshot.data();

    final equippedItems =
    Map<String, dynamic>.from(
      userData?['equippedItems'] ?? {},
    );

    final batch = _firestore.batch();

    if (ownedItemsSnapshot.docs.isEmpty) {
      final defaultItemIds = [
        'accessory_basic',
        'clothes_basic',
        'hat_basic',
        'shoes_basic',
      ];

      for (final itemId in defaultItemIds) {
        final itemRef =
        ownedItemsRef.doc(itemId);

        batch.set(
          itemRef,
          {
            'purchasedAt':
            FieldValue.serverTimestamp(),
            'pricePaid': 0,
          },
        );
      }
    }

    final hasNoEquippedItems =
        equippedItems['accessory'] == null &&
            equippedItems['clothes'] == null &&
            equippedItems['hat'] == null &&
            equippedItems['shoes'] == null;

    if (hasNoEquippedItems) {
      batch.update(
        userRef,
        {
          'equippedItems': {
            'accessory':
            'accessory_basic',
            'clothes':
            'clothes_basic',
            'hat':
            'hat_basic',
            'shoes':
            'shoes_basic',
          },
          'updatedAt':
          FieldValue.serverTimestamp(),
        },
      );
    }

    await batch.commit();
  }

  Future<bool> purchaseItem(String itemId) async {
    try {
      final userId = _currentUserId;

      final userRef = _firestore
          .collection('users')
          .doc(userId);

      final itemRef = _firestore
          .collection('avatarItems')
          .doc(itemId);

      final ownedItemRef = userRef
          .collection('ownedItems')
          .doc(itemId);

      await _firestore.runTransaction(
            (transaction) async {
          final userSnapshot =
          await transaction.get(userRef);

          final itemSnapshot =
          await transaction.get(itemRef);

          final ownedItemSnapshot =
          await transaction.get(ownedItemRef);

          if (!userSnapshot.exists ||
              !itemSnapshot.exists) {
            throw StateError(
              '사용자 또는 아이템 정보가 없습니다.',
            );
          }

          if (ownedItemSnapshot.exists) {
            throw StateError(
              '이미 보유한 아이템입니다.',
            );
          }

          final userData =
          userSnapshot.data()!;

          final itemData =
          itemSnapshot.data()!;

          final currentPoints =
              (userData['points'] as num?)
                  ?.toInt() ??
                  0;

          final itemPrice =
              (itemData['price'] as num?)
                  ?.toInt() ??
                  0;

          if (currentPoints < itemPrice) {
            throw StateError(
              '포인트가 부족합니다.',
            );
          }

          transaction.update(
            userRef,
            {
              'points':
              currentPoints - itemPrice,
              'updatedAt':
              FieldValue.serverTimestamp(),
            },
          );

          transaction.set(
            ownedItemRef,
            {
              'purchasedAt':
              FieldValue.serverTimestamp(),
              'pricePaid': itemPrice,
            },
          );
        },
      );

      return true;
    } catch (e) {
      debugPrint(
        '아이템 구매 실패: $e',
      );
      return false;
    }
  }

  Future<bool> equipItem(String itemId) async {
    try {
      final userId = _currentUserId;

      final itemDoc = await _firestore
          .collection('avatarItems')
          .doc(itemId)
          .get();

      if (!itemDoc.exists) {
        return false;
      }

      final ownedItemDoc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('ownedItems')
          .doc(itemId)
          .get();

      if (!ownedItemDoc.exists) {
        return false;
      }

      final item = AvatarItem.fromMap(
        itemDoc.id,
        itemDoc.data()!,
      );

      await _firestore
          .collection('users')
          .doc(userId)
          .update({
        'equippedItems.${item.slot}': itemId,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      debugPrint('아이템 착용 실패: $e');
      return false;
    }
  }
}