import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/student_result.dart';

class FirebaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // saves the master key using the subject name as the document id
  Future<void> saveMasterKey(String subjectName, List<int> answers) async {
    await _db.collection('quiz_settings').doc(subjectName).set({
      'answers': answers,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // fetches the specific master key answers for a chosen subject
  Future<List<int>?> getMasterKey(String subjectName) async {
    final DocumentSnapshot doc = await _db.collection('quiz_settings').doc(subjectName).get();
    
    if (doc.exists) {
      final Map<String, dynamic>? data = doc.data() as Map<String, dynamic>?;
      if (data != null) {
        return List<int>.from(data['answers']);
      } else {
        return null;
      }
    } else {
      return null;
    }
  }

  // uploads student automatic grading score
  Future<void> saveStudentResult(StudentResult result) async {
    await _db.collection('student_results').add(result.toMap());
  }

  // streams to listen to results filtered by subject
  Stream<List<StudentResult>> streamResults({String? subjectFilter}) {
    Query query = _db.collection('student_results').orderBy('timestamp', descending: true);
    
    if (subjectFilter != null) {
      if (subjectFilter != 'All') {
        query = query.where('subject', isEqualTo: subjectFilter);
      }
    }
    
    return query.snapshots().map((QuerySnapshot snapshot) {
      return snapshot.docs.map((QueryDocumentSnapshot doc) {
        return StudentResult.fromFirestore(doc);
      }).toList();
    });
  }

  // streams available exams from quiz_settings collection
  Stream<QuerySnapshot> streamExams() {
    return _db.collection('quiz_settings').snapshots();
  }
}