import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/firebase_service.dart';

class SetAnswerKeyScreen extends StatefulWidget {
  final String examTitle;
  final String subject;
  final int numberOfItems;

  const SetAnswerKeyScreen({
    super.key,
    required this.examTitle,
    required this.subject,
    required this.numberOfItems,
  });

  @override
  State<SetAnswerKeyScreen> createState() {
    return _SetAnswerKeyScreenState();
  }
}

class _SetAnswerKeyScreenState extends State<SetAnswerKeyScreen> {
  late List<int> _answers;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final int itemLength = widget.numberOfItems;
    _answers = List<int>.filled(itemLength, -1);
  }

  void _selectAnswer(int questionIndex, int choiceIndex) {
    setState(() {
      _answers[questionIndex] = choiceIndex;
    });
  }

  Future<void> _saveAndGenerate() async {
    bool hasUnanswered = false;
    
    // iterates explicitly to check if there are any blank fields
    for (int i = 0; i < _answers.length; i++) {
      final int answer = _answers[i];
      if (answer == -1) {
        hasUnanswered = true;
      } else {
        // continues iterating without interruption
      }
    }

    if (hasUnanswered == true) {
      final SnackBar snackBar = const SnackBar(
        content: Text('please provide an answer for all items'),
      );
      ScaffoldMessenger.of(context).showSnackBar(snackBar);
    } else {
      setState(() {
        _isSaving = true;
      });

      final FirebaseService firebaseService = Provider.of<FirebaseService>(context, listen: false);
      final String examTitle = widget.examTitle;
      final String subject = widget.subject;
      final List<int> answers = _answers;

      try {
        await firebaseService.saveMasterKey(examTitle, subject, answers);
        
        if (mounted == true) {
          // returns to dashboard_screen.dart by popping the stack twice
          Navigator.pop(context);
          Navigator.pop(context);
        } else {
          // drops the operation if the widget is unmounted
        }
      } catch (error) {
        if (mounted == true) {
          final String errorMessage = error.toString();
          final SnackBar snackBar = SnackBar(
            content: Text('failed to save exam: $errorMessage'),
          );
          ScaffoldMessenger.of(context).showSnackBar(snackBar);
        } else {
          // drops the operation if the widget is unmounted
        }
      } finally {
        if (mounted == true) {
          setState(() {
            _isSaving = false;
          });
        } else {
          // drops the operation if the widget is unmounted
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget buttonContent;
    
    if (_isSaving == true) {
      buttonContent = const CircularProgressIndicator();
    } else {
      buttonContent = const Text('save and generate');
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('set answer key'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: widget.numberOfItems,
              itemBuilder: (BuildContext context, int index) {
                final int questionNumber = index + 1;
                final int currentAnswer = _answers[index];
                final List<String> options = ['A', 'B', 'C', 'D', 'E'];
                
                final List<Widget> optionWidgets = [];
                
                // builds the distinct option bubbles explicitly without array mapping
                for (int i = 0; i < options.length; i++) {
                  final int choiceIndex = i;
                  final String choiceText = options[i];
                  
                  bool isSelected;
                  if (currentAnswer == choiceIndex) {
                    isSelected = true;
                  } else {
                    isSelected = false;
                  }

                  Color backgroundColor;
                  Color textColor;
                  
                  if (isSelected == true) {
                    backgroundColor = Colors.teal;
                    textColor = Colors.white;
                  } else {
                    backgroundColor = Colors.grey.shade300;
                    textColor = Colors.black;
                  }

                  final Widget optionWidget = GestureDetector(
                    onTap: () {
                      _selectAnswer(index, choiceIndex);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(12.0),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: backgroundColor,
                      ),
                      child: Text(
                        choiceText,
                        style: TextStyle(
                          color: textColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  );

                  optionWidgets.add(optionWidget);
                }

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 40.0,
                        child: Text(
                          '$questionNumber.',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16.0),
                        ),
                      ),
                      Expanded(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: optionWidgets,
                        ),
                      ),
                    ],
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
                  // blocks interaction while saving
                } else {
                  _saveAndGenerate();
                }
              },
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(50.0),
              ),
              child: buttonContent,
            ),
          ),
        ],
      ),
    );
  }
}