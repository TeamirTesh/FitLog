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
  bool _saving = false;
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
    final formKey = GlobalKey<FormState>();
    bool submitting = false;

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Add Exercise'),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: nameController,
                        autofocus: true,
                        textInputAction: TextInputAction.done,
                        decoration: const InputDecoration(
                          labelText: 'Name',
                          hintText: 'e.g., Bench Press',
                        ),
                        validator: (value) {
                          if ((value ?? '').trim().isEmpty) {
                            return 'Please enter an exercise name';
                          }
                          return null;
                        },
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
                        decoration:
                            const InputDecoration(labelText: 'Muscle group'),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: submitting
                      ? null
                      : () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: submitting
                      ? null
                      : () {
                          if (!formKey.currentState!.validate()) {
                            return;
                          }
                          setDialogState(() => submitting = true);
                          Navigator.of(context).pop(<String, String>{
                            'name': nameController.text.trim(),
                            'muscleGroup': selectedMuscleGroup,
                          });
                        },
                  child: submitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Add'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == null) return;

    setState(() => _saving = true);
    try {
      await _db.insertExercise(
        Exercise(
          name: (result['name'] ?? '').trim(),
          muscleGroup: result['muscleGroup'] ?? _muscleGroups.first,
          equipment: '',
        ),
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
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _openEditDialog(Exercise exercise) async {
    final nameController = TextEditingController(text: exercise.name);
    String selectedMuscleGroup = exercise.muscleGroup;
    final formKey = GlobalKey<FormState>();
    bool submitting = false;
    if (!_muscleGroups.contains(selectedMuscleGroup)) {
      selectedMuscleGroup = _muscleGroups.first;
    }

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Edit Exercise'),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: nameController,
                        autofocus: true,
                        textInputAction: TextInputAction.done,
                        decoration: const InputDecoration(labelText: 'Name'),
                        validator: (value) {
                          if ((value ?? '').trim().isEmpty) {
                            return 'Please enter an exercise name';
                          }
                          return null;
                        },
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
                        decoration:
                            const InputDecoration(labelText: 'Muscle group'),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: submitting
                      ? null
                      : () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: submitting
                      ? null
                      : () {
                          if (!formKey.currentState!.validate()) {
                            return;
                          }
                          setDialogState(() => submitting = true);
                          Navigator.of(context).pop(<String, String>{
                            'name': nameController.text.trim(),
                            'muscleGroup': selectedMuscleGroup,
                          });
                        },
                  child: submitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == null) return;

    setState(() => _saving = true);
    try {
      await _db.updateExercise(
        exercise.copyWith(
          name: (result['name'] ?? '').trim(),
          muscleGroup: result['muscleGroup'] ?? selectedMuscleGroup,
        ),
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
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
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

    setState(() => _saving = true);
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
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
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
            onPressed: _loading || _saving ? null : _refreshExercises,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _loading || _saving ? null : _openAddDialog,
        child: const Icon(Icons.add),
      ),
      body: Stack(
        children: [
          _loading
              ? const Center(child: CircularProgressIndicator())
              : _exercises.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: SingleChildScrollView(
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
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              color:
                                  Theme.of(context).colorScheme.errorContainer,
                              child: Icon(
                                Icons.delete,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onErrorContainer,
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
          if (_saving)
            ColoredBox(
              color: Colors.black26,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const CircularProgressIndicator(),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
