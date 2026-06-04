import 'package:flutter/material.dart';
import '../models/student_result.dart';

class ScoreReviewScreen extends StatefulWidget {
  final StudentResult studentResult;

  const ScoreReviewScreen({
    super.key,
    required this.studentResult,
  });

  @override
  State<ScoreReviewScreen> createState() {
    return _ScoreReviewScreenState();
  }
}

class _ScoreReviewScreenState extends State<ScoreReviewScreen> {
  @override
  Widget build(BuildContext context) {
    final StudentResult result = widget.studentResult;
    final String studentName = result.studentName;

    return Scaffold(
      appBar: AppBar(
        title: Text('review: $studentName'),
        centerTitle: true,
      ),
      body: const Center(
        child: Text('manual override logic will be implemented in phase 5'),
      ),
    );
  }
}