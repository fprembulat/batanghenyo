import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/student_result.dart';
import '../services/firebase_service.dart';
import 'scanner_screen.dart';
import 'score_review_screen.dart';

class ExamDetailScreen extends StatefulWidget {
  final String examTitle;

  const ExamDetailScreen({
    super.key,
    required this.examTitle,
  });

  @override
  State<ExamDetailScreen> createState() {
    return _ExamDetailScreenState();
  }
}

class _ExamDetailScreenState extends State<ExamDetailScreen> {
  void _promptDeleteConfirmation(BuildContext context, String resultId) {
    final AlertDialog dialog = AlertDialog(
      title: const Text('delete record'),
      content: const Text('are you sure you want to delete this student record?'),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(context);
          },
          child: const Text('cancel'),
        ),
        TextButton(
          onPressed: () async {
            final FirebaseService firebaseService = Provider.of<FirebaseService>(context, listen: false);
            await firebaseService.deleteStudentResult(resultId);
            
            if (context.mounted == true) {
              Navigator.pop(context);
            } else {
              // widget is no longer active
            }
          },
          child: const Text(
            'delete',
            style: TextStyle(color: Colors.red),
          ),
        ),
      ],
    );

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return dialog;
      },
    );
  }

  void _navigateToScoreReview(StudentResult result) {
    final MaterialPageRoute route = MaterialPageRoute(
      builder: (BuildContext context) {
        return ScoreReviewScreen(
          studentResult: result,
        );
      },
    );
    Navigator.push(context, route);
  }

  void _navigateToScanner() {
    final MaterialPageRoute route = MaterialPageRoute(
      builder: (BuildContext context) {
        return ScannerScreen(
          examTitle: widget.examTitle,
        );
      },
    );
    Navigator.push(context, route);
  }

  @override
  Widget build(BuildContext context) {
    final FirebaseService firebaseService = Provider.of<FirebaseService>(context, listen: false);
    final String currentExamTitle = widget.examTitle;

    return Scaffold(
      appBar: AppBar(
        title: Text(currentExamTitle),
        centerTitle: true,
      ),
      body: StreamBuilder<List<StudentResult>>(
        stream: firebaseService.streamResults(subjectFilter: currentExamTitle),
        builder: (BuildContext context, AsyncSnapshot<List<StudentResult>> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          } else {
            if (snapshot.hasError == true) {
              return const Center(
                child: Text('failed to load student roster'),
              );
            } else {
              if (snapshot.hasData == false) {
                return const Center(
                  child: Text('no data available'),
                );
              } else {
                final List<StudentResult> results = snapshot.data!;

                if (results.isEmpty == true) {
                  return const Center(
                    child: Text('no students have been graded for this exam yet'),
                  );
                } else {
                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SingleChildScrollView(
                      child: DataTable(
                        columns: const [
                          DataColumn(label: Text('student name')),
                          DataColumn(label: Text('score')),
                          DataColumn(label: Text('actions')),
                        ],
                        rows: results.map((StudentResult result) {
                          // maps out variables explicitly instead of destructuring shorthand,
                          final String resultId = result.id;
                          final String studentName = result.studentName;
                          final int score = result.score;
                          final int totalQuestions = result.totalQuestions;

                          return DataRow(
                            cells: [
                              DataCell(Text(studentName)),
                              DataCell(Text('$score / $totalQuestions')),
                              DataCell(
                                Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit, color: Colors.blue),
                                      onPressed: () {
                                        _navigateToScoreReview(result);
                                      },
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete, color: Colors.red),
                                      onPressed: () {
                                        _promptDeleteConfirmation(context, resultId);
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  );
                }
              }
            }
          }
        },
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ElevatedButton.icon(
          onPressed: _navigateToScanner,
          icon: const Icon(Icons.document_scanner),
          label: const Text('scan answer sheet'),
          style: ElevatedButton.styleFrom(
            minimumSize: const Size.fromHeight(60.0),
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Colors.white,
          ),
        ),
      ),
    );
  }
}