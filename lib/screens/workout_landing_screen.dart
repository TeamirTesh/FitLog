import 'package:flutter/material.dart';
import 'start_workout_screen.dart';

class WorkoutLandingScreen extends StatelessWidget {
  const WorkoutLandingScreen({super.key});

  void _startWorkout(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const StartWorkoutScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Workout')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.fitness_center,
                size: 80,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 24),
              Text(
                'Ready to train?',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Start a new workout to log your exercises, sets, reps, and weight.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              FilledButton.icon(
                onPressed: () => _startWorkout(context),
                icon: const Icon(Icons.play_arrow),
                label: const Text('Start Workout'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(220, 52),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
