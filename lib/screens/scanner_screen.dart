import 'package:flutter/material.dart';

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
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('scanner module'),
        centerTitle: true,
      ),
      body: const Center(
        child: Text('scanner functionality will be implemented in phase 4'),
      ),
    );
  }
}