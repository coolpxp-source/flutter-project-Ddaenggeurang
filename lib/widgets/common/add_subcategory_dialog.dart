import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'ddaeng_modal.dart';

/// 지출/수입/저축 입력화면에서 소분류를 바로 추가할 때 쓰는 다이얼로그.
/// 성공 시 새로 생성된 customCategories 문서 id를 반환한다.
/// 취소하거나 실패한 경우 null을 반환한다.
///
/// [transactionType]은 'expense' | 'income' | 'saving' 중 하나.
/// [nature]는 지출 성격(고정비/변동비/기타)이 있는 화면(expense)에서만 의미가 있고,
/// 없는 화면(income/saving)은 기본값 'variable'을 그대로 사용해도 무방하다.
Future<String?> showAddSubCategoryDialog(
    BuildContext context, {
      required String transactionType,
      required String parentName,
      String nature = 'variable',
    }) async {
  final name = await DdaengModal.prompt(
    context,
    title: '[$parentName] 새 소분류 추가',
    hintText: '예: 마라탕, 통신비 등',
    type: ModalType.info,
    confirmText: '추가',
  );

  if (name == null || name.isEmpty) return null;

  final userId = FirebaseAuth.instance.currentUser?.uid;
  if (userId == null) return null;

  try {
    final doc = await FirebaseFirestore.instance.collection('customCategories').add({
      'userId': userId,
      'transactionType': transactionType,
      'parentName': parentName,
      'name': name,
      'nature': nature,
      'isHidden': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return doc.id;
  } catch (e) {
    debugPrint('소분류 추가 오류: $e');
    return null;
  }
}