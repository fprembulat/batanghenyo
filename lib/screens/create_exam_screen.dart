import 'package:flutter/material.dart';
import 'set_answer_key_screen.dart';

class CreateExamScreen extends StatefulWidget {
  const CreateExamScreen({super.key});

  @override
  State<CreateExamScreen> createState() {
    return _CreateExamScreenState();
  }
}

class _CreateExamScreenState extends State<CreateExamScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _itemsController = TextEditingController();

  @override
  void dispose() {
    _titleController.dispose();
    _subjectController.dispose();
    _itemsController.dispose();
    super.dispose();
  }

  void _proceedToAnswerKey() {
    final FormState? currentState = _formKey.currentState;
    
    if (currentState != null) {
      final bool isValid = currentState.validate();
      
      if (isValid == true) {
        final String examTitle = _titleController.text;
        final String subject = _subjectController.text;
        final String itemsText = _itemsController.text;
        final int? numberOfItems = int.tryParse(itemsText);

        if (numberOfItems != null) {
          if (numberOfItems > 0) {
            // limits the item count strictly to 60 based on the physical batanghenyo sheet
            if (numberOfItems <= 60) {
              final MaterialPageRoute route = MaterialPageRoute(
                builder: (BuildContext context) {
                  return SetAnswerKeyScreen(
                    examTitle: examTitle,
                    subject: subject,
                    numberOfItems: numberOfItems,
                  );
                },
              );
              Navigator.push(context, route);
            } else {
              final SnackBar snackBar = const SnackBar(
                content: Text('number of items cannot exceed 60'),
              );
              ScaffoldMessenger.of(context).showSnackBar(snackBar);
            }
          } else {
            final SnackBar snackBar = const SnackBar(
              content: Text('number of items must be greater than zero'),
            );
            ScaffoldMessenger.of(context).showSnackBar(snackBar);
          }
        } else {
          final SnackBar snackBar = const SnackBar(
            content: Text('please enter a valid number'),
          );
          ScaffoldMessenger.of(context).showSnackBar(snackBar);
        }
      } else {
        // stops execution if the form validation fails
      }
    } else {
      // stops execution if the current state is null
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('create new exam'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'exam title',
                  border: OutlineInputBorder(),
                ),
                validator: (String? value) {
                  if (value == null) {
                    return 'please enter an exam title';
                  } else {
                    if (value.isEmpty == true) {
                      return 'please enter an exam title';
                    } else {
                      return null;
                    }
                  }
                },
              ),
              const SizedBox(height: 16.0),
              TextFormField(
                controller: _subjectController,
                decoration: const InputDecoration(
                  labelText: 'subject',
                  border: OutlineInputBorder(),
                ),
                validator: (String? value) {
                  if (value == null) {
                    return 'please enter a subject';
                  } else {
                    if (value.isEmpty == true) {
                      return 'please enter a subject';
                    } else {
                      return null;
                    }
                  }
                },
              ),
              const SizedBox(height: 16.0),
              TextFormField(
                controller: _itemsController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'number of items',
                  border: OutlineInputBorder(),
                ),
                validator: (String? value) {
                  if (value == null) {
                    return 'please enter the number of items';
                  } else {
                    if (value.isEmpty == true) {
                      return 'please enter the number of items';
                    } else {
                      return null;
                    }
                  }
                },
              ),
              const SizedBox(height: 32.0),
              ElevatedButton(
                onPressed: _proceedToAnswerKey,
                child: const Text('set answer key'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}