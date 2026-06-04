import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firebase_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() {
    return _DashboardScreenState();
  }
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  Widget build(BuildContext context) {
    // accesses the injected firebase service explicitly
    final FirebaseService firebaseService = Provider.of<FirebaseService>(context, listen: false);

    return Scaffold(
      appBar: AppBar(
        title: const Text('batanghenyo dashboard'),
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: firebaseService.streamExams(),
        builder: (BuildContext context, AsyncSnapshot<QuerySnapshot> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return const Center(
              child: Text('failed to load exams'),
            );
          }

          if (snapshot.hasData == false) {
            return const Center(
              child: Text('no data available'),
            );
          }

          final List<QueryDocumentSnapshot> docs = snapshot.data!.docs;

          if (docs.isEmpty) {
            return const Center(
              child: Text('no exams found, tap the plus button to create one'),
            );
          }

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (BuildContext context, int index) {
              final QueryDocumentSnapshot doc = docs[index];
              final String subjectName = doc.id;
              
              // renders a card for each subject streamed from firestore
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: ListTile(
                  title: Text(
                    subjectName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () {
                    // routes to exam detail screen in phase 3
                    debugPrint('routing to $subjectName details');
                  },
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // routes to create exam screen in phase 2
          debugPrint('routing to create exam');
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}