import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/student_result.dart';

class FirebaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Saves the master key using the Subject Name as the Document ID
  Future<void> saveMasterKey(String subjectName, List<int> answers) async {
    await _db.collection('quiz_settings').doc(subjectName).set({
      'answers': answers,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // Fetches the specific master key answers for a chosen subject
  Future<List<int>?> getMasterKey(String subjectName) async {
    var doc = await _db.collection('quiz_settings').doc(subjectName).get();
    if (doc.exists && doc.data() != null) {
      return List<int>.from(doc.data()!['answers']);
    }
    return null;
  }

  // Upload student automatic grading score
  Future<void> saveStudentResult(StudentResult result) async {
    await _db.collection('student_results').add(result.toMap());
  }

  // Stream to listen to results filtered by subject, or all of them
  Stream<List<StudentResult>> streamResults({String? subjectFilter}) {
    Query query = _db.collection('student_results').orderBy('timestamp', descending: true);
    
    if (subjectFilter != null && subjectFilter != "All") {
      query = query.where('subject', isEqualTo: subjectFilter);
    }
    
    return query.snapshots().map((snapshot) => snapshot.docs
        .map((doc) => StudentResult.fromFirestore(doc))
        .toList());
  }
}