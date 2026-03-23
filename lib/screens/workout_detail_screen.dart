import 'package:flutter/material.dart';

import '../database/database_helper.dart';

class WorkoutDetailScreen extends StatefulWidget {
  const WorkoutDetailScreen({super.key, required this.workoutId});

  final int workoutId;

  @override
  State<WorkoutDetailScreen> createState() => _WorkoutDetailScreenState();
}

class _WorkoutDetailScreenState extends State<WorkoutDetailScreen> {
  final DatabaseHelper _db = DatabaseHelper.instance;

  bool _loading = false;
  Map<String, Object?>? _workout;
  List<Map<String, Object?>> _exerciseRows = const [];

  @override
  void initState() {
    super.initState();
    _loadDetails();
  }

  Future<void> _loadDetails() async {
    setState(() => _loading = true);
    try {
      final workout = await _db.getWorkoutById(widget.workoutId);
      final rows = await _db.getWorkoutExerciseDetails(widget.workoutId);
      if (!mounted) return;
      setState(() {
        _workout = workout;
        _exerciseRows = rows;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load workout: $e')),
      );
    }
  }

  String _formatDate(String rawDate) {
    final date = DateTime.tryParse(rawDate)?.toLocal();
    if (date == null) return rawDate;
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    final year = date.year.toString();
    return '$month/$day/$year';
  }

  Future<void> _deleteWorkout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete workout?'),
          content: const Text('This will remove the workout and all logged exercises.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton.tonal(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    try {
      await _db.deleteWorkout(widget.workoutId);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete workout: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Workout Detail'),
        actions: [
          IconButton(
            tooltip: 'Delete workout',
            onPressed: _deleteWorkout,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _workout == null
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Workout not found.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _formatDate((_workout!['date'] as String?) ?? ''),
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            Text('Duration: ${_workout!['duration'] ?? 0} min'),
                            const SizedBox(height: 8),
                            Text(
                              'Notes: ${((_workout!['notes'] as String?) ?? '').trim().isEmpty ? 'None' : _workout!['notes']}',
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Exercises',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    if (_exerciseRows.isEmpty)
                      const Card(
                        child: Padding(
                          padding: EdgeInsets.all(14),
                          child: Text('No exercises logged for this workout.'),
                        ),
                      )
                    else
                      ..._exerciseRows.map((row) {
                        final weight = row['weight'];
                        final weightText = weight is num
                            ? weight.toStringAsFixed(weight % 1 == 0 ? 0 : 1)
                            : '${row['weight'] ?? 0}';
                        return Card(
                          child: ListTile(
                            title: Text((row['exercise_name'] as String?) ?? 'Exercise'),
                            subtitle: Text(
                              '${row['sets'] ?? 0} sets  •  ${row['reps'] ?? 0} reps  •  $weightText lb',
                            ),
                          ),
                        );
                      }),
                  ],
                ),
    );
  }
}
