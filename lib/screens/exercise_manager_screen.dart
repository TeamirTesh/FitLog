import 'package:flutter/material.dart';

import '../database/database_helper.dart';
import '../models/exercise.dart';

class ExerciseManagerScreen extends StatefulWidget {
  const ExerciseManagerScreen({super.key});

  @override
  State<ExerciseManagerScreen> createState() => _ExerciseManagerScreenState();
}

class _ExerciseManagerScreenState extends State<ExerciseManagerScreen> {
  static const List<String> _muscleGroups = [
    'Chest',
    'Back',
    'Legs',
    'Shoulders',
    'Arms',
    'Core',
    'Cardio',
  ];

  final DatabaseHelper _db = DatabaseHelper.instance;

  bool _loading = false;
  List<Exercise> _exercises = const [];

  @override
  void initState() {
    super.initState();
    _refreshExercises();
  }

  Future<void> _refreshExercises() async {
    setState(() => _loading = true);
    try {
      final items = await _db.getAllExercises();
      if (!mounted) return;
      setState(() {
        _exercises = items;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load exercises: $e')),
      );
    }
  }

  Future<void> _openAddDialog() async {
    final nameController = TextEditingController();
    String selectedMuscleGroup = _muscleGroups.first;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Add Exercise'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    autofocus: true,
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(
                      labelText: 'Name',
                      hintText: 'e.g., Bench Press',
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: selectedMuscleGroup,
                    items: _muscleGroups
                        .map(
                          (g) => DropdownMenuItem<String>(
                            value: g,
                            child: Text(g),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setDialogState(() => selectedMuscleGroup = value);
                    },
                    decoration: const InputDecoration(labelText: 'Muscle group'),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    final name = nameController.text.trim();
                    if (name.isEmpty) {
                      ScaffoldMessenger.of(this.context).showSnackBar(
                        const SnackBar(content: Text('Name cannot be empty')),
                      );
                      return;
                    }
                    Navigator.of(context).pop(true);
                  },
                  child: const Text('Add'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != true) return;

    try {
      final name = nameController.text.trim();
      await _db.insertExercise(
        Exercise(name: name, muscleGroup: selectedMuscleGroup, equipment: ''),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Exercise added')),
      );
      await _refreshExercises();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to add exercise: $e')),
      );
    }
  }

  Future<void> _openEditDialog(Exercise exercise) async {
    final nameController = TextEditingController(text: exercise.name);
    String selectedMuscleGroup = exercise.muscleGroup;
    if (!_muscleGroups.contains(selectedMuscleGroup)) {
      selectedMuscleGroup = _muscleGroups.first;
    }

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Edit Exercise'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    autofocus: true,
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(labelText: 'Name'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: selectedMuscleGroup,
                    items: _muscleGroups
                        .map(
                          (g) => DropdownMenuItem<String>(
                            value: g,
                            child: Text(g),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setDialogState(() => selectedMuscleGroup = value);
                    },
                    decoration: const InputDecoration(labelText: 'Muscle group'),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    final name = nameController.text.trim();
                    if (name.isEmpty) {
                      ScaffoldMessenger.of(this.context).showSnackBar(
                        const SnackBar(content: Text('Name cannot be empty')),
                      );
                      return;
                    }
                    Navigator.of(context).pop(true);
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != true) return;

    try {
      final name = nameController.text.trim();
      await _db.updateExercise(
        exercise.copyWith(name: name, muscleGroup: selectedMuscleGroup),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Exercise updated')),
      );
      await _refreshExercises();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update exercise: $e')),
      );
    }
  }

  Future<bool> _confirmDelete(Exercise exercise) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete exercise?'),
          content: Text('Delete "${exercise.name}"? This cannot be undone.'),
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

    return result ?? false;
  }

  Future<void> _deleteExercise(Exercise exercise) async {
    final id = exercise.id;
    if (id == null) return;

    try {
      await _db.deleteExercise(id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Exercise deleted')),
      );
      await _refreshExercises();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete exercise: $e')),
      );
      await _refreshExercises();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Exercise Manager'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _refreshExercises,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openAddDialog,
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _exercises.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.fitness_center,
                          size: 64,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'No exercises yet',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Tap + to add your first exercise.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _refreshExercises,
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: _exercises.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final exercise = _exercises[index];
                      final id = exercise.id ?? index;

                      return Dismissible(
                        key: ValueKey('exercise_$id'),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          color: Theme.of(context).colorScheme.errorContainer,
                          child: Icon(
                            Icons.delete,
                            color:
                                Theme.of(context).colorScheme.onErrorContainer,
                          ),
                        ),
                        confirmDismiss: (_) => _confirmDelete(exercise),
                        onDismissed: (_) => _deleteExercise(exercise),
                        child: ListTile(
                          title: Text(exercise.name),
                          subtitle: Text(exercise.muscleGroup),
                          onTap: () => _openEditDialog(exercise),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
