import 'package:flutter/material.dart';
import '../services/firebase_service.dart';
import '../models/student_result.dart';

class ResultsScreen extends StatefulWidget {
  const ResultsScreen({super.key});

  @override
  State<ResultsScreen> createState() {
    return _ResultsScreenState();
  }
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
                onSelectionChanged: (Set<String> set) {
                  setState(() {
                    _selectedFilter = set.first;
                  });
                },
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<StudentResult>>(
              stream: _firebaseService.streamResults(subjectFilter: _selectedFilter),
              builder: (BuildContext context, AsyncSnapshot<List<StudentResult>> snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                } else {
                  if (snapshot.hasData == false) {
                    return const Center(child: Text('No evaluated sheets stored yet.'));
                  } else {
                    if (snapshot.data!.isEmpty == true) {
                      return const Center(child: Text('No evaluated sheets stored yet.'));
                    } else {
                      final List<StudentResult> results = snapshot.data!;
                      return ListView.builder(
                        itemCount: results.length,
                        itemBuilder: (BuildContext context, int index) {
                          final StudentResult item = results[index];
                          return ListTile(
                            title: Text(item.studentName, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text('${item.subject} • ${item.timestamp.toString().substring(0, 16)}'),
                            trailing: Text(
                              '${item.score}/${item.totalQuestions}',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueGrey),
                            ),
                            onTap: () {
                              _showWrongAnswersModal(context, item);
                            },
                          );
                        },
                      );
                    }
                  }
                }
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
      builder: (BuildContext context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.7,
          maxChildSize: 0.9,
          builder: (BuildContext context, ScrollController scrollController) {
            return Column(
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
                    itemBuilder: (BuildContext context, int idx) {
                      final bool isCorrect = result.analysis[idx];
                      
                      String letterChoice;
                      if (result.studentAnswers[idx] == -1) {
                        letterChoice = 'Unanswered';
                      } else {
                        letterChoice = String.fromCharCode(65 + result.studentAnswers[idx]);
                      }

                      Color avatarBackgroundColor;
                      Color avatarTextColor;
                      String titleText;
                      IconData trailingIcon;
                      Color trailingIconColor;

                      if (isCorrect == true) {
                        avatarBackgroundColor = Colors.green.shade100;
                        avatarTextColor = Colors.green.shade900;
                        titleText = 'Correct';
                        trailingIcon = Icons.check_circle;
                        trailingIconColor = Colors.green;
                      } else {
                        avatarBackgroundColor = Colors.red.shade100;
                        avatarTextColor = Colors.red.shade900;
                        titleText = 'Incorrect Marker';
                        trailingIcon = Icons.cancel;
                        trailingIconColor = Colors.red;
                      }

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: avatarBackgroundColor,
                          child: Text('${idx + 1}', style: TextStyle(color: avatarTextColor)),
                        ),
                        title: Text(titleText),
                        subtitle: Text('Submitted selection: $letterChoice'),
                        trailing: Icon(
                          trailingIcon,
                          color: trailingIconColor,
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}