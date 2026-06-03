import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../services/firebase_service.dart';
import '../services/omr_processor.dart';
import '../models/student_result.dart';
import 'results_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  final TextEditingController _nameController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  final List<String> _subjects = ['Math', 'Science', 'English', 'History'];
  String _selectedSubject = 'Math';
  bool _isProcessing = false;

  Future<void> _setMasterKey() async {
    final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile == null) return;

    setState(() => _isProcessing = true);
    try {
      List<int> detectedKey = OMRProcessor.processAnswerSheet(File(pickedFile.path), 20, 4);
      await _firebaseService.saveMasterKey(_selectedSubject, detectedKey);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('🎉 Master Key for $_selectedSubject saved!')),
        );
      }
    } catch (e) {
      _showErrorSnackBar('Failed to parse image layout. Ensure lighting is uniform.');
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _scanStudentPaper() async {
    String studentName = _nameController.text.trim();
    if (studentName.isEmpty) {
      _showErrorSnackBar('Please enter the student\'s name first.');
      return;
    }

    List<int>? masterKey = await _firebaseService.getMasterKey(_selectedSubject);
    if (masterKey == null || masterKey.isEmpty) {
      _showErrorSnackBar('No Answer Key found for $_selectedSubject. Upload one first!');
      return;
    }

    final XFile? takenPhoto = await _picker.pickImage(source: ImageSource.camera);
    if (takenPhoto == null) return;

    setState(() => _isProcessing = true);

    try {
      List<int> studentAnswers = OMRProcessor.processAnswerSheet(File(takenPhoto.path), 20, 4);
      int score = 0;
      List<bool> analysis = [];

      for (int i = 0; i < masterKey.length; i++) {
        bool isCorrect = (i < studentAnswers.length) && (studentAnswers[i] == masterKey[i]);
        if (isCorrect) score++;
        analysis.add(isCorrect);
      }

      StudentResult finalResult = StudentResult(
        id: '',
        studentName: studentName,
        subject: _selectedSubject,
        score: score,
        totalQuestions: masterKey.length,
        studentAnswers: studentAnswers,
        analysis: analysis,
        timestamp: DateTime.now(),
      );

      await _firebaseService.saveStudentResult(finalResult);
      _nameController.clear();

      if (mounted) {
        _showResultDialog(finalResult);
      }
    } catch (e) {
      _showErrorSnackBar('Error auto-grading. Keep paper flat and minimize shadows.');
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  void _showResultDialog(StudentResult result) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Graded: ${result.studentName}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${result.score} / ${result.totalQuestions}',
              style: const TextStyle(fontSize: 42, fontWeight: FontWeight.w900, color: Colors.teal),
            ),
            Text('Subject: ${result.subject}', style: const TextStyle(fontWeight: FontWeight.w500)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))
        ],
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.redAccent));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('BatangHenyo Dashboard', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.analytics_outlined),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ResultsScreen())),
          )
        ],
      ),
      body: _isProcessing
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          const Text('1. Choose Target Subject', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            initialValue: _selectedSubject,
                            decoration: const InputDecoration(border: OutlineInputBorder()),
                            items: _subjects.map((sub) => DropdownMenuItem(value: sub, child: Text(sub))).toList(),
                            onChanged: (val) => setState(() => _selectedSubject = val!),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: _setMasterKey,
                            icon: const Icon(Icons.cloud_upload_outlined),
                            label: const Text('Upload Base Answer Key Template'),
                            style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(45)),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Student Full Name',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _scanStudentPaper,
                    icon: const Icon(Icons.document_scanner),
                    label: const Text('Auto-Grade Student Paper', style: TextStyle(fontSize: 16)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(60),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}