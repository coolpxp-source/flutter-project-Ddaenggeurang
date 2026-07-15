import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/category_model.dart';

class CategoryService {
  final _db = FirebaseFirestore.instance;

  /// 17a_카테고리관리 - 기본 카테고리 (전체 공용, isCustom=false)
  /// transactionType: income/expense/saving 필터링해서 쓸 때 사용
  Stream<List<CategoryModel>> getDefaultCategories({TransactionType? transactionType}) {
    Query query = _db.collection('categories').where('isCustom', isEqualTo: false);

    if (transactionType != null) {
      query = query.where('transactionType', isEqualTo: transactionType.code);
    }

    return query
        .snapshots()
        .map((s) => s.docs.map((d) => CategoryModel.fromFirestore(d)).toList());
  }

  /// 내 커스텀 카테고리
  Stream<List<CategoryModel>> getMyCustomCategories(
      String userId, {
        TransactionType? transactionType,
      }) {
    Query query = _db
        .collection('categories')
        .where('isCustom', isEqualTo: true)
        .where('userId', isEqualTo: userId);

    if (transactionType != null) {
      query = query.where('transactionType', isEqualTo: transactionType.code);
    }

    return query
        .snapshots()
        .map((s) => s.docs.map((d) => CategoryModel.fromFirestore(d)).toList());
  }

  /// 커스텀 카테고리 추가
  Future<String> addCustomCategory(CategoryModel category) async {
    final doc = await _db.collection('categories').add(category.toFirestore());
    return doc.id;
  }

  /// 카테고리 수정 (기본 카테고리는 화면단에서 수정 버튼 자체를 막는 걸 추천)
  Future<void> updateCategory(String categoryId, Map<String, dynamic> updates) async {
    await _db.collection('categories').doc(categoryId).update(updates);
  }

  /// 커스텀 카테고리 삭제 (하드 삭제 - CategoryModel엔 isDeleted 필드가 없어서 완전 삭제로 처리)
  Future<void> deleteCategory(String categoryId) async {
    await _db.collection('categories').doc(categoryId).delete();
  }
}