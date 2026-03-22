import 'package:flutter/material.dart';

class StartWorkoutScreen extends StatelessWidget {
  const StartWorkoutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Start Workout')),
      body: const Center(child: Text('Start Workout Screen')),
    );
  }
}
