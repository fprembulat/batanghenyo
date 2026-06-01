import 'package:cloud_firestore/cloud_firestore.dart';

class StudentResult {
  final String id;
  final String studentName;
  final String subject; 
  final int score;
  final int totalQuestions;
  final List<int> studentAnswers; 
  final List<bool> analysis;       
  final DateTime timestamp;

  StudentResult({
    required this.id,
    required this.studentName,
    required this.subject, 
    required this.score,
    required this.totalQuestions,
    required this.studentAnswers,
    required this.analysis,
    required this.timestamp,
  });

  // Convert Firebase document back to a Flutter Object
  factory StudentResult.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return StudentResult(
      id: doc.id,
      studentName: data['studentName'] ?? '',
      subject: data['subject'] ?? '', 
      score: data['score'] ?? 0,
      totalQuestions: data['totalQuestions'] ?? 0,
      studentAnswers: List<int>.from(data['studentAnswers'] ?? []),
      analysis: List<bool>.from(data['analysis'] ?? []),
      timestamp: (data['timestamp'] as Timestamp).toDate(),
    );
  }

  // Convert Flutter Object to Map format for Firebase storage
  Map<String, dynamic> toMap() {
    return {
      'studentName': studentName,
      'subject': subject, 
      'score': score,
      'totalQuestions': totalQuestions,
      'studentAnswers': studentAnswers,
      'analysis': analysis,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }
}