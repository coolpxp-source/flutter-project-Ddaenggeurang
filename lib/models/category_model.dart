import 'package:cloud_firestore/cloud_firestore.dart';
import 'expense_model.dart' show ExpenseNature;

/// 이 카테고리가 수입/지출/저축 중 어디에 속하는지
enum TransactionType {
  income('income', '수입'),
  expense('expense', '지출'),
  saving('saving', '저축/투자');

  final String code;
  final String label;
  const TransactionType(this.code, this.label);

  static TransactionType fromCode(String? code) => TransactionType.values.firstWhere(
        (e) => e.code == code,
    orElse: () => TransactionType.expense,
  );
}

class CategoryModel {
  final String categoryId;
  final String name; // 소분류명 (예: "카페/디저트")
  final String parentName; // 대분류명 (예: "식비")
  final TransactionType transactionType;

  /// transactionType == expense 일 때만 값 있음 (income/saving은 null)
  final ExpenseNature? nature;

  final bool isCustom;
  final String? userId; // isCustom == true 일 때만 사용
  final DateTime? createdAt;

  CategoryModel({
    required this.categoryId,
    required this.name,
    required this.parentName,
    required this.transactionType,
    this.nature,
    this.isCustom = false,
    this.userId,
    this.createdAt,
  });

  factory CategoryModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return CategoryModel(
      categoryId: doc.id,
      name: d['name'] ?? '',
      parentName: d['parentName'] ?? '',
      transactionType: TransactionType.fromCode(d['transactionType']),
      nature: d['nature'] != null ? ExpenseNature.fromCode(d['nature']) : null,
      isCustom: d['isCustom'] ?? false,
      userId: d['userId'] as String?,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'name': name,
    'parentName': parentName,
    'transactionType': transactionType.code,
    'nature': nature?.code,
    'isCustom': isCustom,
    'userId': userId,
    'createdAt': createdAt != null
        ? Timestamp.fromDate(createdAt!)
        : FieldValue.serverTimestamp(),
  };

  CategoryModel copyWith({
    String? name,
    String? parentName,
    TransactionType? transactionType,
    ExpenseNature? nature,
    bool? isCustom,
    String? userId,
  }) {
    return CategoryModel(
      categoryId: categoryId,
      name: name ?? this.name,
      parentName: parentName ?? this.parentName,
      transactionType: transactionType ?? this.transactionType,
      nature: nature ?? this.nature,
      isCustom: isCustom ?? this.isCustom,
      userId: userId ?? this.userId,
      createdAt: createdAt,
    );
  }
}