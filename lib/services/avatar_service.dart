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

  // 특정 유저의 현재 착용 아이템만 조회 (다른 사람 캐릭터 표시용, 커뮤니티 등)
  Future<List<AvatarItem>> getEquippedItemsForUser(String userId) async {
    try {
      final results = await Future.wait([
        _firestore.collection('avatarItems').get(),
        _firestore.collection('users').doc(userId).get(),
      ]);

      final avatarItemsSnapshot = results[0] as QuerySnapshot<Map<String, dynamic>>;
      final userSnapshot = results[1] as DocumentSnapshot<Map<String, dynamic>>;

      final userData = userSnapshot.data();
      final equippedItems = Map<String, dynamic>.from(
        userData?['equippedItems'] ?? {},
      );

      final equippedIds = equippedItems.values.whereType<String>().toSet();

      return avatarItemsSnapshot.docs
          .where((doc) => equippedIds.contains(doc.id))
          .map((doc) => AvatarItem.fromMap(doc.id, doc.data()).copyWith(
        isOwned: true,
        isEquipped: true,
      ))
          .toList();
    } catch (e) {
      debugPrint('유저 착용 아이템 조회 실패: $e');
      return [];
    }
  }


  // 기본 아바타 아이템의 보유 및 장착 상태를 초기화하는 메서드
  Future<void> initializeDefaultAvatar() async {
    final userId = _currentUserId;

    final userRef = _firestore
        .collection('users')
        .doc(userId);

    final ownedItemsRef = userRef.collection('ownedItems');

    final userSnapshot = await userRef.get();

    if (!userSnapshot.exists) {
      throw StateError('사용자 정보가 없습니다.');
    }

    final userData = userSnapshot.data();

    final equippedItems = Map<String, dynamic>.from(
      userData?['equippedItems'] ?? {},
    );

    // Firestore avatarItems 문서 ID와 반드시 동일해야 함
    final defaultItems = <String, String>{
      'hair': 'hair_basic',
      'clothes': 'basic_clothes',
      'shoes': 'basic_shoes',
      'accessory': 'basic_accessory',
      'pet': 'pet_basic',
    };

    final batch = _firestore.batch();

    // 기존 사용자도 누락된 기본 아이템을 받을 수 있도록 개별 확인
    for (final itemId in defaultItems.values) {
      final ownedItemRef = ownedItemsRef.doc(itemId);
      final ownedItemSnapshot = await ownedItemRef.get();

      if (!ownedItemSnapshot.exists) {
        batch.set(
          ownedItemRef,
          {
            'purchasedAt': FieldValue.serverTimestamp(),
            'pricePaid': 0,
          },
        );
      }
    }

    // 기존 장착 상태는 유지하고 누락된 슬롯만 기본 아이템으로 설정
    final updatedEquippedItems = Map<String, dynamic>.from(equippedItems);

    for (final entry in defaultItems.entries) {
      final currentItemId = updatedEquippedItems[entry.key];

      if (currentItemId == null ||
          currentItemId.toString().trim().isEmpty) {
        updatedEquippedItems[entry.key] = entry.value;
      }
    }

    // 1차 common 세트에서는 hat 슬롯을 사용하지 않음
    updatedEquippedItems.remove('hat');

    batch.update(
      userRef,
      {
        'equippedItems': updatedEquippedItems,
        'updatedAt': FieldValue.serverTimestamp(),
      },
    );

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