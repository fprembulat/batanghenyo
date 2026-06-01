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
          SnackBar(content: Text('🎉 Master Key for $_selectedSubject saved successfully!')),
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