import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/market_product_model.dart';

class MarketService {
  final _db = FirebaseFirestore.instance;

  // 상품 목록 (판매중인 것만, 최신순)
  Stream<List<MarketProduct>> getProducts({String? category}) {
    Query query = _db
        .collection('marketProducts')
        .where('status', isEqualTo: 'selling')
        .orderBy('createdAt', descending: true);

    if (category != null && category != '전체') {
      query = query.where('category', isEqualTo: category);
    }

    return query.snapshots().map(
          (s) => s.docs.map((d) => MarketProduct.fromFirestore(d)).toList(),
    );
  }

  // 상품 상세 (단건 조회)
  Future<MarketProduct?> getProduct(String productId) async {
    final doc = await _db.collection('marketProducts').doc(productId).get();
    if (!doc.exists) return null;
    return MarketProduct.fromFirestore(doc);
  }

  // 상품 등록
  Future<String> addProduct(MarketProduct product) async {
    final docRef = await _db.collection('marketProducts').add(product.toMap());
    return docRef.id;
  }

  // 상품 정보 수정
  Future<void> updateProduct(String productId, Map<String, dynamic> updates) async {
    updates['updatedAt'] = Timestamp.now();
    await _db.collection('marketProducts').doc(productId).update(updates);
  }

  // 상품 상태 변경 (판매중/예약중/판매완료)
  Future<void> updateStatus(String productId, String status) async {
    await _db.collection('marketProducts').doc(productId).update({
      'status': status,
      'updatedAt': Timestamp.now(),
    });
  }

  // 상품 삭제
  Future<void> deleteProduct(String productId) async {
    await _db.collection('marketProducts').doc(productId).delete();
  }

  // 판매자 기준 본인 상품 목록
  Stream<List<MarketProduct>> getMyProducts(String sellerId) {
    return _db
        .collection('marketProducts')
        .where('sellerId', isEqualTo: sellerId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => MarketProduct.fromFirestore(d)).toList());
  }

  // 찜 토글
  Future<void> toggleFavorite(String userId, String productId, bool isFavorite) async {
    final ref = _db.collection('users').doc(userId).collection('favorites').doc(productId);
    if (isFavorite) {
      await ref.set({'createdAt': Timestamp.now()});
    } else {
      await ref.delete();
    }
  }

// 찜한 상품 ID 목록 (실시간)
  Stream<Set<String>> getFavoriteIds(String userId) {
    return _db
        .collection('users')
        .doc(userId)
        .collection('favorites')
        .snapshots()
        .map((snap) => snap.docs.map((d) => d.id).toSet());
  }
}