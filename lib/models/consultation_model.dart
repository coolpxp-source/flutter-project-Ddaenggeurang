import 'package:cloud_firestore/cloud_firestore.dart';

/// AI "살까말까" 상담 1건 — users/{uid}/consultations 서브컬렉션.
class ConsultationEntry {
  final String id;
  final String question;
  final String answer;
  final String? verdictCode; // buy | hold | conditional | null(파싱 실패)
  final DateTime date;

  const ConsultationEntry({
    required this.id,
    required this.question,
    required this.answer,
    required this.verdictCode,
    required this.date,
  });

  factory ConsultationEntry.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return ConsultationEntry(
      id: doc.id,
      question: d['question'] as String? ?? '',
      answer: d['answer'] as String? ?? '',
      verdictCode: d['verdictCode'] as String?,
      date: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'question': question,
        'answer': answer,
        'verdictCode': verdictCode,
        'createdAt': FieldValue.serverTimestamp(),
      };
}
