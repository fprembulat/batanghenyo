import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'screens/dashboard_screen.dart';
import 'services/firebase_service.dart';

void main() async {
  // ensures flutter engine bindings are ready before firebase initialization
  WidgetsFlutterBinding.ensureInitialized();
  
  // initializes firebase backend for the current platform
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const BatangHenyoApp());
}

class BatangHenyoApp extends StatelessWidget {
  const BatangHenyoApp({super.key});

  @override
  Widget build(BuildContext context) {
    // wraps the application with multiprovider to inject services globally
    return MultiProvider(
      providers: [
        Provider<FirebaseService>(
          create: (BuildContext context) {
            return FirebaseService();
          },
        ),
      ],
      child: MaterialApp(
        title: 'BatangHenyo OMR',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF008080),
            brightness: Brightness.light,
          ),
        ),
        home: const DashboardScreen(),
      ),
    );
  }
}