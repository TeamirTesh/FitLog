import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const FitLogApp());
}

class FitLogApp extends StatelessWidget {
  const FitLogApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FitLog',
      home: const HomeScreen(),
    );
  }
}
