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

  // converts firebase document back to a flutter object with rigorous type safety boundaries
  factory StudentResult.fromFirestore(DocumentSnapshot doc) {
    final dynamic rawData = doc.data();
    
    if (rawData == null) {
      throw Exception('firestore document data is missing or null');
    } else {
      // proceeds with parsing the valid data payload
    }

    final Map<String, dynamic> data = rawData as Map<String, dynamic>;
    final String parsedId = doc.id;
    
    final dynamic rawName = data['studentName'];
    String parsedName;
    if (rawName is String) {
      parsedName = rawName;
    } else {
      parsedName = 'unknown student';
    }

    final dynamic rawSubject = data['subject'];
    String parsedSubject;
    if (rawSubject is String) {
      parsedSubject = rawSubject;
    } else {
      parsedSubject = 'unknown subject';
    }

    final dynamic rawScore = data['score'];
    int parsedScore;
    if (rawScore is int) {
      parsedScore = rawScore;
    } else {
      if (rawScore is String) {
        final int? convertedScore = int.tryParse(rawScore);
        if (convertedScore != null) {
          parsedScore = convertedScore;
        } else {
          parsedScore = 0;
        }
      } else {
        parsedScore = 0;
      }
    }

    final dynamic rawTotal = data['totalQuestions'];
    int parsedTotal;
    if (rawTotal is int) {
      parsedTotal = rawTotal;
    } else {
      if (rawTotal is String) {
        final int? convertedTotal = int.tryParse(rawTotal);
        if (convertedTotal != null) {
          parsedTotal = convertedTotal;
        } else {
          parsedTotal = 0;
        }
      } else {
        parsedTotal = 0;
      }
    }

    final dynamic rawAnswers = data['studentAnswers'];
    List<int> parsedAnswers;
    if (rawAnswers is List<dynamic>) {
      parsedAnswers = List<int>.from(rawAnswers);
    } else {
      parsedAnswers = [];
    }

    final dynamic rawAnalysis = data['analysis'];
    List<bool> parsedAnalysis;
    if (rawAnalysis is List<dynamic>) {
      parsedAnalysis = List<bool>.from(rawAnalysis);
    } else {
      parsedAnalysis = [];
    }

    final dynamic rawTimestamp = data['timestamp'];
    DateTime parsedTimestamp;
    if (rawTimestamp is Timestamp) {
      parsedTimestamp = rawTimestamp.toDate();
    } else {
      if (rawTimestamp is String) {
        final DateTime? convertedTime = DateTime.tryParse(rawTimestamp);
        if (convertedTime != null) {
          parsedTimestamp = convertedTime;
        } else {
          parsedTimestamp = DateTime.now();
        }
      } else {
        parsedTimestamp = DateTime.now();
      }
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