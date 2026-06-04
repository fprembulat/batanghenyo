import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import '../services/firebase_service.dart';
import '../services/omr_processor.dart';
import '../models/student_result.dart';

class ScannerScreen extends StatefulWidget {
  final String examTitle;

  const ScannerScreen({
    super.key,
    required this.examTitle,
  });

  @override
  State<ScannerScreen> createState() {
    return _ScannerScreenState();
  }
}

class _ScannerScreenState extends State<ScannerScreen> {
  final TextEditingController _studentNameController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  
  bool _isProcessing = false;
  File? _capturedImage;

  @override
  void dispose() {
    _studentNameController.dispose();
    super.dispose();
  }

  Future<void> _captureFromCamera() async {
    final XFile? takenPhoto = await _picker.pickImage(source: ImageSource.camera);
    
    if (takenPhoto != null) {
      final File imageFile = File(takenPhoto.path);
      setState(() {
        _capturedImage = imageFile;
      });
    } else {
      // user cancelled camera operation
    }
  }

  Future<void> _processAndGrade() async {
    final String studentName = _studentNameController.text.trim();
    
    if (studentName.isEmpty == true) {
      final SnackBar snackBar = const SnackBar(
        content: Text('please enter the student name first'),
        backgroundColor: Colors.redAccent,
      );
      ScaffoldMessenger.of(context).showSnackBar(snackBar);
    } else {
      if (_capturedImage == null) {
        final SnackBar snackBar = const SnackBar(
          content: Text('please capture an answer sheet image first'),
          backgroundColor: Colors.redAccent,
        );
        ScaffoldMessenger.of(context).showSnackBar(snackBar);
      } else {
        setState(() {
          _isProcessing = true;
        });

        final FirebaseService firebaseService = Provider.of<FirebaseService>(context, listen: false);
        final String examTitle = widget.examTitle;

        try {
          final List<int>? masterKey = await firebaseService.getMasterKey(examTitle);
          
          if (masterKey != null) {
            final int totalQuestions = masterKey.length;
            final File imageToProcess = _capturedImage!;
            
            final List<int> studentAnswers = OMRProcessor.processAnswerSheet(imageToProcess, totalQuestions);
            
            int score = 0;
            final List<bool> analysis = [];

            // evaluates explicit correct matches against the master key
            for (int i = 0; i < totalQuestions; i++) {
              if (i < studentAnswers.length) {
                final int studentChoice = studentAnswers[i];
                final int correctChoice = masterKey[i];
                
                if (studentChoice == correctChoice) {
                  score = score + 1;
                  analysis.add(true);
                } else {
                  analysis.add(false);
                }
              } else {
                analysis.add(false);
              }
            }

            final DateTime currentTime = DateTime.now();
            final StudentResult finalResult = StudentResult(
              id: '',
              studentName: studentName,
              subject: examTitle,
              score: score,
              totalQuestions: totalQuestions,
              studentAnswers: studentAnswers,
              analysis: analysis,
              timestamp: currentTime,
            );

            await firebaseService.saveStudentResult(finalResult);

            if (mounted == true) {
              _showSuccessModal(finalResult);
              setState(() {
                _capturedImage = null;
                _studentNameController.clear();
              });
            } else {
              // widget unmounted
            }
          } else {
            if (mounted == true) {
              final SnackBar snackBar = const SnackBar(
                content: Text('master key not found for this exam'),
                backgroundColor: Colors.redAccent,
              );
              ScaffoldMessenger.of(context).showSnackBar(snackBar);
            } else {
              // widget unmounted
            }
          }
        } catch (error) {
          if (mounted == true) {
            final SnackBar snackBar = SnackBar(
              content: Text('alignment failed, ensure corner markers are visible. error: $error'),
              backgroundColor: Colors.redAccent,
            );
            ScaffoldMessenger.of(context).showSnackBar(snackBar);
          } else {
            // widget unmounted
          }
        } finally {
          if (mounted == true) {
            setState(() {
              _isProcessing = false;
            });
          } else {
            // widget unmounted
          }
        }
      }
    }
  }

  void _showSuccessModal(StudentResult result) {
    final int score = result.score;
    final int total = result.totalQuestions;
    final String name = result.studentName;
    
    final AlertDialog dialog = AlertDialog(
      title: const Text('scan successful'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle, color: Colors.green, size: 64.0),
          const SizedBox(height: 16.0),
          Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18.0)),
          const SizedBox(height: 8.0),
          Text('score: $score / $total', style: const TextStyle(fontSize: 24.0, color: Colors.teal)),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(context);
          },
          child: const Text('scan next'),
        ),
        TextButton(
          onPressed: () {
            Navigator.pop(context);
            Navigator.pop(context); // returns to the exam details screen to view roster
          },
          child: const Text('review details'),
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

  @override
  Widget build(BuildContext context) {
    Widget imagePreview;
    
    if (_capturedImage != null) {
      imagePreview = Image.file(
        _capturedImage!,
        height: 300.0,
        fit: BoxFit.cover,
      );
    } else {
      imagePreview = Container(
        height: 300.0,
        color: Colors.grey.shade200,
        child: const Center(
          child: Text('no image captured'),
        ),
      );
    }

    Widget bodyContent;
    
    if (_isProcessing == true) {
      bodyContent = const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16.0),
            Text('processing image and evaluating score'),
          ],
        ),
      );
    } else {
      bodyContent = SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _studentNameController,
              decoration: const InputDecoration(
                labelText: 'student full name',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
            ),
            const SizedBox(height: 24.0),
            ClipRRect(
              borderRadius: BorderRadius.circular(12.0),
              child: imagePreview,
            ),
            const SizedBox(height: 16.0),
            ElevatedButton.icon(
              onPressed: _captureFromCamera,
              icon: const Icon(Icons.camera_alt),
              label: const Text('open camera'),
            ),
            const SizedBox(height: 32.0),
            ElevatedButton(
              onPressed: _processAndGrade,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(60.0),
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
              ),
              child: const Text(
                'evaluate and save',
                style: TextStyle(fontSize: 18.0),
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('scan answer sheet'),
        centerTitle: true,
      ),
      body: bodyContent,
    );
  }
}