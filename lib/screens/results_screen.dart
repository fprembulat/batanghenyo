import 'package:flutter/material.dart';
import '../services/firebase_service.dart';
import '../models/student_result.dart';

class ResultsScreen extends StatefulWidget {
  const ResultsScreen({super.key});

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  String _selectedFilter = 'All';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Saved Student Results')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'All', label: Text('All')),
                  ButtonSegment(value: 'Math', label: Text('Math')),
                  ButtonSegment(value: 'Science', label: Text('Sci')),
                  ButtonSegment(value: 'English', label: Text('Eng')),
                  ButtonSegment(value: 'History', label: Text('Hist')),
                ],
                selected: {_selectedFilter},
                onSelectionChanged: (set) => setState(() => _selectedFilter = set.first),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<StudentResult>>(
              stream: _firebaseService.streamResults(subjectFilter: _selectedFilter),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text('No evaluated sheets stored yet.'));
                }

                final results = snapshot.data!;
                return ListView.builder(
                  itemCount: results.length,
                  itemBuilder: (context, index) {
                    final item = results[index];
                    return ListTile(
                      title: Text(item.studentName, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('${item.subject} • ${item.timestamp.toString().substring(0, 16)}'),
                      trailing: Text(
                        '${item.score}/${item.totalQuestions}',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueGrey),
                      ),
                      onTap: () => _showWrongAnswersModal(context, item),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showWrongAnswersModal(BuildContext context, StudentResult result) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.7,
          maxChildSize: 0.9,
          builder: (_, scrollController) => Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text('Mistake Log: ${result.studentName}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              const Divider(),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: result.analysis.length,
                  itemBuilder: (context, idx) {
                    bool isCorrect = result.analysis[idx];
                    String letterChoice = result.studentAnswers[idx] == -1 
                        ? 'Unanswered' 
                        : String.fromCharCode(65 + result.studentAnswers[idx]);

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: isCorrect ? Colors.green.shade100 : Colors.red.shade100,
                        child: Text('${idx + 1}', style: TextStyle(color: isCorrect ? Colors.green.shade900 : Colors.red.shade900)),
                      ),
                      title: Text(isCorrect ? 'Correct' : 'Incorrect Marker'),
                      subtitle: Text('Submitted selection: $letterChoice'),
                      trailing: Icon(
                        isCorrect ? Icons.check_circle : Icons.cancel,
                        color: isCorrect ? Colors.green : Colors.red,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}