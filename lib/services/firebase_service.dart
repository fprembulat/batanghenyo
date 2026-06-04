import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/student_result.dart';

class FirebaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // saves the master key using the exam title as the document id, storing subject and length explicitly
  Future<void> saveMasterKey(String examTitle, String subject, List<int> answers) async {
    final CollectionReference collectionRef = _db.collection('quiz_settings');
    final DocumentReference docRef = collectionRef.doc(examTitle);
    
    final int totalItems = answers.length;
    final FieldValue timestamp = FieldValue.serverTimestamp();

    final Map<String, dynamic> dataPayload = {
      'title': examTitle,
      'subject': subject,
      'totalItems': totalItems,
      'answers': answers,
      'updatedAt': timestamp,
    };

    await docRef.set(dataPayload);
  }

  // fetches the specific master key answers for a chosen subject
  Future<List<int>?> getMasterKey(String subjectName) async {
    final CollectionReference collectionRef = _db.collection('quiz_settings');
    final DocumentReference docRef = collectionRef.doc(subjectName);
    final DocumentSnapshot doc = await docRef.get();
    
    if (doc.exists == true) {
      final Map<String, dynamic>? data = doc.data() as Map<String, dynamic>?;
      
      if (data != null) {
        final List<dynamic> rawAnswers = data['answers'];
        final List<int> parsedAnswers = List<int>.from(rawAnswers);
        return parsedAnswers;
      } else {
        return null;
      }
    } else {
      return null;
    }
  }

  // uploads student automatic grading score
  Future<void> saveStudentResult(StudentResult result) async {
    final CollectionReference collectionRef = _db.collection('student_results');
    final Map<String, dynamic> dataPayload = result.toMap();
    
    await collectionRef.add(dataPayload);
  }

  // streams to listen to results filtered by subject
  Stream<List<StudentResult>> streamResults({String? subjectFilter}) {
    final CollectionReference collectionRef = _db.collection('student_results');
    Query query = collectionRef.orderBy('timestamp', descending: true);
    
    if (subjectFilter != null) {
      if (subjectFilter != 'All') {
        query = query.where('subject', isEqualTo: subjectFilter);
      } else {
        // no filter applied explicitly
      }
    } else {
      // no filter applied explicitly
    }
    
    final Stream<QuerySnapshot> snapshots = query.snapshots();
    
    return snapshots.map((QuerySnapshot snapshot) {
      final List<QueryDocumentSnapshot> docs = snapshot.docs;
      
      final List<StudentResult> results = docs.map((QueryDocumentSnapshot doc) {
        return StudentResult.fromFirestore(doc);
      }).toList();
      
      return results;
    });
  }

  // streams available exams from quiz_settings collection
  Stream<QuerySnapshot> streamExams() {
    final CollectionReference collectionRef = _db.collection('quiz_settings');
    return collectionRef.snapshots();
  }
}