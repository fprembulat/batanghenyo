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

  // converts firebase document back to a flutter object with explicit null safety
  factory StudentResult.fromFirestore(DocumentSnapshot doc) {
    final Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    
    final String parsedId = doc.id;
    
    final dynamic rawName = data['studentName'];
    String parsedName;
    if (rawName != null) {
      parsedName = rawName as String;
    } else {
      parsedName = '';
    }

    final dynamic rawSubject = data['subject'];
    String parsedSubject;
    if (rawSubject != null) {
      parsedSubject = rawSubject as String;
    } else {
      parsedSubject = '';
    }

    final dynamic rawScore = data['score'];
    int parsedScore;
    if (rawScore != null) {
      parsedScore = rawScore as int;
    } else {
      parsedScore = 0;
    }

    final dynamic rawTotal = data['totalQuestions'];
    int parsedTotal;
    if (rawTotal != null) {
      parsedTotal = rawTotal as int;
    } else {
      parsedTotal = 0;
    }

    final dynamic rawAnswers = data['studentAnswers'];
    List<int> parsedAnswers;
    if (rawAnswers != null) {
      parsedAnswers = List<int>.from(rawAnswers as List<dynamic>);
    } else {
      parsedAnswers = [];
    }

    final dynamic rawAnalysis = data['analysis'];
    List<bool> parsedAnalysis;
    if (rawAnalysis != null) {
      parsedAnalysis = List<bool>.from(rawAnalysis as List<dynamic>);
    } else {
      parsedAnalysis = [];
    }

    final dynamic rawTimestamp = data['timestamp'];
    DateTime parsedTimestamp;
    if (rawTimestamp != null) {
      final Timestamp firestoreTime = rawTimestamp as Timestamp;
      parsedTimestamp = firestoreTime.toDate();
    } else {
      parsedTimestamp = DateTime.now();
    }

    final StudentResult result = StudentResult(
      id: parsedId,
      studentName: parsedName,
      subject: parsedSubject,
      score: parsedScore,
      totalQuestions: parsedTotal,
      studentAnswers: parsedAnswers,
      analysis: parsedAnalysis,
      timestamp: parsedTimestamp,
    );

    return result;
  }

  // converts flutter object to map format for firebase storage explicitly
  Map<String, dynamic> toMap() {
    final Timestamp firestoreTimestamp = Timestamp.fromDate(timestamp);
    
    final Map<String, dynamic> mappedData = {
      'studentName': studentName,
      'subject': subject, 
      'score': score,
      'totalQuestions': totalQuestions,
      'studentAnswers': studentAnswers,
      'analysis': analysis,
      'timestamp': firestoreTimestamp,
    };
    
    return mappedData;
  }
}