import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/student_result.dart';
import '../services/firebase_service.dart';

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
  late List<bool> _currentAnalysis;
  late int _currentScore;
  List<int>? _masterKey;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final StudentResult result = widget.studentResult;
    _currentAnalysis = List<bool>.from(result.analysis);
    _currentScore = result.score;
    _fetchMasterKey();
  }

  Future<void> _fetchMasterKey() async {
    final FirebaseService firebaseService = Provider.of<FirebaseService>(context, listen: false);
    final String subjectName = widget.studentResult.subject;
    
    try {
      final List<int>? fetchedKey = await firebaseService.getMasterKey(subjectName);
      
      if (mounted == true) {
        setState(() {
          _masterKey = fetchedKey;
          _isLoading = false;
        });
      } else {
        // drops execution since widget is unmounted
      }
    } catch (error) {
      if (mounted == true) {
        setState(() {
          _isLoading = false;
        });
      } else {
        // drops execution since widget is unmounted
      }
    }
  }

  void _toggleAnswerStatus(int index) {
    setState(() {
      final bool previousStatus = _currentAnalysis[index];
      
      if (previousStatus == true) {
        _currentAnalysis[index] = false;
        _currentScore = _currentScore - 1;
      } else {
        _currentAnalysis[index] = true;
        _currentScore = _currentScore + 1;
      }
    });
  }

  Future<void> _saveOverrides() async {
    setState(() {
      _isSaving = true;
    });

    final FirebaseService firebaseService = Provider.of<FirebaseService>(context, listen: false);
    final StudentResult originalResult = widget.studentResult;
    
    final StudentResult updatedResult = StudentResult(
      id: originalResult.id,
      studentName: originalResult.studentName,
      subject: originalResult.subject,
      score: _currentScore,
      totalQuestions: originalResult.totalQuestions,
      studentAnswers: originalResult.studentAnswers,
      analysis: _currentAnalysis,
      timestamp: originalResult.timestamp,
    );

    try {
      await firebaseService.updateStudentResult(updatedResult);
      
      if (mounted == true) {
        final SnackBar snackBar = const SnackBar(
          content: Text('score updated successfully'),
        );
        ScaffoldMessenger.of(context).showSnackBar(snackBar);
        Navigator.pop(context);
      } else {
        // drops execution since widget is unmounted
      }
    } catch (error) {
      if (mounted == true) {
        final String errorMessage = error.toString();
        final SnackBar snackBar = SnackBar(
          content: Text('failed to update score: $errorMessage'),
          backgroundColor: Colors.redAccent,
        );
        ScaffoldMessenger.of(context).showSnackBar(snackBar);
      } else {
        // drops execution since widget is unmounted
      }
    } finally {
      if (mounted == true) {
        setState(() {
          _isSaving = false;
        });
      } else {
        // drops execution since widget is unmounted
      }
    }
  }

  String _getChoiceLetter(int choiceIndex) {
    if (choiceIndex == -1) {
      return 'blank';
    } else {
      if (choiceIndex == 0) {
        return 'A';
      } else {
        if (choiceIndex == 1) {
          return 'B';
        } else {
          if (choiceIndex == 2) {
            return 'C';
          } else {
            if (choiceIndex == 3) {
              return 'D';
            } else {
              if (choiceIndex == 4) {
                return 'E';
              } else {
                return 'unknown';
              }
            }
          }
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final String studentName = widget.studentResult.studentName;
    final int totalQuestions = widget.studentResult.totalQuestions;

    Widget bodyContent;

    if (_isLoading == true) {
      bodyContent = const Center(
        child: CircularProgressIndicator(),
      );
    } else {
      bodyContent = Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16.0),
            color: Colors.teal.shade50,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'adjusted score',
                  style: TextStyle(fontSize: 18.0, fontWeight: FontWeight.bold),
                ),
                Text(
                  '$_currentScore / $totalQuestions',
                  style: const TextStyle(
                    fontSize: 24.0,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: totalQuestions,
              itemBuilder: (BuildContext context, int index) {
                final int questionNumber = index + 1;
                final bool isCorrect = _currentAnalysis[index];
                
                final int studentChoiceIndex = widget.studentResult.studentAnswers[index];
                final String studentChoiceLetter = _getChoiceLetter(studentChoiceIndex);
                
                String correctChoiceText = 'unknown';
                if (_masterKey != null) {
                  final int correctChoiceIndex = _masterKey![index];
                  correctChoiceText = _getChoiceLetter(correctChoiceIndex);
                } else {
                  // keeps unknown string assignment
                }

                Color rowColor;
                if (isCorrect == true) {
                  rowColor = Colors.green.shade50;
                } else {
                  rowColor = Colors.red.shade50;
                }

                Widget actionIcon;
                if (isCorrect == true) {
                  actionIcon = const Icon(Icons.check_circle, color: Colors.green);
                } else {
                  actionIcon = const Icon(Icons.cancel, color: Colors.red);
                }

                return Card(
                  color: rowColor,
                  margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.white,
                      child: Text('$questionNumber'),
                    ),
                    title: Text('student answered: $studentChoiceLetter'),
                    subtitle: Text('correct answer: $correctChoiceText'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        actionIcon,
                        Switch(
                          value: isCorrect,
                          onChanged: (bool value) {
                            _toggleAnswerStatus(index);
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton(
              onPressed: () {
                if (_isSaving == true) {
                  // ignores interaction while saving
                } else {
                  _saveOverrides();
                }
              },
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(60.0),
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
              ),
              child: _isSaving
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('save adjustments', style: TextStyle(fontSize: 18.0)),
            ),
          ),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('review: $studentName'),
        centerTitle: true,
      ),
      body: bodyContent,
    );
  }
}