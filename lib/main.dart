import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'screens/dashboard_screen.dart';

void main() async {
  // Ensure Flutter engine bindings are ready before Firebase kicks in
  WidgetsFlutterBinding.ensureInitialized();
  
  // Connect your app to your Firebase backend project shell
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const BatangHenyoApp());
}

class BatangHenyoApp extends StatelessWidget {
  const BatangHenyoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BatangHenyo OMR',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF008080), // Deep Teal Theme
          brightness: Brightness.light,
        ),
      ),
      home: const DashboardScreen(), // Launches your main dashboard screen on start
    );
  }
}