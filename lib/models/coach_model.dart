import 'package:cloud_firestore/cloud_firestore.dart';

class DBCoach {
  final String id;
  final String name;
  final String title;
  final String desc;
  final String emoji;

  DBCoach({
    required this.id,
    required this.name,
    required this.title,
    required this.desc,
    required this.emoji,
  });

  factory DBCoach.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return DBCoach(
      id: doc.id,
      name: data['name'] ?? '',
      title: data['title'] ?? '',
      desc: data['desc'] ?? '',
      emoji: data['emoji'] ?? '🐶',
    );
  }
}