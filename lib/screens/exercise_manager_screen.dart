import 'package:flutter/material.dart';

class ExerciseManagerScreen extends StatelessWidget {
  const ExerciseManagerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Exercise Manager')),
      body: const Center(child: Text('Exercise Manager Screen')),
    );
  }
}
