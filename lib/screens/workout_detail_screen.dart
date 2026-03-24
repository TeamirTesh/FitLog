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
  bool _deleting = false;
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

    setState(() => _deleting = true);
    try {
      await _db.deleteWorkout(widget.workoutId);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete workout: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _deleting = false);
      }
    }
  }

  String _workoutTitle(Map<String, Object?> w) {
    final name = ((w['name'] as String?) ?? '').trim();
    if (name.isNotEmpty) return name;
    return 'Workout';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _workout == null ? 'Workout' : _workoutTitle(_workout!),
        ),
        actions: [
          IconButton(
            tooltip: 'Delete workout',
            onPressed: _deleting ? null : _deleteWorkout,
            icon: _deleting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _workout == null
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.search_off, size: 56),
                        SizedBox(height: 12),
                        Text(
                          'Workout not found.',
                          textAlign: TextAlign.center,
                        ),
                      ],
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
                            if (((_workout!['name'] as String?) ?? '')
                                .trim()
                                .isNotEmpty) ...[
                              Text(
                                ((_workout!['name'] as String?) ?? '').trim(),
                                style: Theme.of(context)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                            ],
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
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            children: [
                              Icon(
                                Icons.playlist_remove,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                              const SizedBox(width: 10),
                              const Expanded(
                                child: Text(
                                  'No exercises logged for this workout.',
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      ..._buildGroupedExerciseCards(context),
                  ],
                ),
    );
  }

  /// Detail query rows are ordered by exercise, then set index.
  List<Widget> _buildGroupedExerciseCards(BuildContext context) {
    final theme = Theme.of(context);
    _WeGroup? cur;
    final groups = <_WeGroup>[];

    for (final row in _exerciseRows) {
      final weId = row['workout_exercise_id'] as int?;
      if (weId == null) continue;
      if (cur == null || cur.weId != weId) {
        cur = _WeGroup(
          weId,
          (row['exercise_name'] as String?) ?? 'Exercise',
          (row['muscle_group'] as String?) ?? '',
        );
        groups.add(cur);
      }
      if (row['set_id'] != null) {
        cur.sets.add(row);
      }
    }

    return groups.map((g) {
      return Card(
        margin: const EdgeInsets.only(bottom: 10),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                g.name,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (g.muscle.isNotEmpty)
                Text(
                  g.muscle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              const SizedBox(height: 10),
              if (g.sets.isEmpty)
                Text(
                  'No sets logged',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                )
              else
                ...g.sets.map((s) {
                  final idx = (s['set_index'] as int?) ?? 0;
                  final reps = s['reps'] ?? 0;
                  final weight = s['weight'];
                  final wText = weight is num
                      ? weight.toStringAsFixed(
                          weight % 1 == 0 ? 0 : 1,
                        )
                      : '${s['weight'] ?? 0}';
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 56,
                          child: Text(
                            'Set ${idx + 1}',
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                        Text('$reps reps', style: theme.textTheme.bodyMedium),
                        const Spacer(),
                        Text(
                          '$wText kg',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
            ],
          ),
        ),
      );
    }).toList();
  }
}

class _WeGroup {
  _WeGroup(this.weId, this.name, this.muscle);

  final int weId;
  final String name;
  final String muscle;
  final List<Map<String, Object?>> sets = [];
}
