import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../database/database_helper.dart';
import '../providers/workout_refresh_notifier.dart';
import '../models/exercise.dart';
import '../models/workout.dart';
import '../models/workout_exercise.dart';

// ─── In-session set row (controllers owned by parent block) ─────────────────

class _EditableSet {
  _EditableSet({String reps = '', String weight = ''})
      : repsCtrl = TextEditingController(text: reps),
        weightCtrl = TextEditingController(text: weight);

  final TextEditingController repsCtrl;
  final TextEditingController weightCtrl;

  factory _EditableSet.copyFrom(_EditableSet other) {
    return _EditableSet(
      reps: other.repsCtrl.text,
      weight: other.weightCtrl.text,
    );
  }

  void dispose() {
    repsCtrl.dispose();
    weightCtrl.dispose();
  }

  int parsedReps() {
    final v = int.tryParse(repsCtrl.text.trim());
    return v != null && v >= 0 ? v : 0;
  }

  double parsedWeight() {
    final v = double.tryParse(weightCtrl.text.trim());
    return v != null && v >= 0 ? v : 0.0;
  }
}

class _WorkoutBlock {
  _WorkoutBlock({required this.exercise}) : sets = [_EditableSet()];

  final Exercise exercise;
  final List<_EditableSet> sets;

  void dispose() {
    for (final s in sets) {
      s.dispose();
    }
  }

  void addSet() {
    sets.add(_EditableSet.copyFrom(sets.last));
  }

  void removeSetAt(int index) {
    if (sets.length <= 1 || index < 0 || index >= sets.length) return;
    sets[index].dispose();
    sets.removeAt(index);
  }
}

// ─── Screen ───────────────────────────────────────────────────────────────────

class StartWorkoutScreen extends StatefulWidget {
  const StartWorkoutScreen({super.key});

  @override
  State<StartWorkoutScreen> createState() => _StartWorkoutScreenState();
}

class _StartWorkoutScreenState extends State<StartWorkoutScreen> {
  final _nameController = TextEditingController();
  final _notesController = TextEditingController();
  final List<_WorkoutBlock> _blocks = [];

  late final Stopwatch _stopwatch;
  late final Timer _ticker;

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _stopwatch = Stopwatch()..start();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker.cancel();
    _stopwatch.stop();
    for (final b in _blocks) {
      b.dispose();
    }
    _nameController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  String get _elapsed {
    final s = _stopwatch.elapsed;
    final h = s.inHours;
    final m = s.inMinutes.remainder(60).toString().padLeft(2, '0');
    final sec = s.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$sec' : '$m:$sec';
  }

  int get _elapsedMinutes => _stopwatch.elapsed.inMinutes;

  Future<bool> _confirmDiscard() async {
    if (_blocks.isEmpty) return true;
    final leave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Discard workout?'),
        content: const Text(
          'You have unsaved exercises. Leave without saving?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep editing'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    return leave ?? false;
  }

  Future<void> _showAddExerciseDialog() async {
    final exercises = await DatabaseHelper.instance.getAllExercises();

    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (ctx) => _PickExerciseDialog(
        exercises: exercises,
        onPick: (exercise) {
          setState(() => _blocks.add(_WorkoutBlock(exercise: exercise)));
        },
      ),
    );
  }

  void _removeBlock(int index) {
    if (index < 0 || index >= _blocks.length) return;
    setState(() {
      _blocks[index].dispose();
      _blocks.removeAt(index);
    });
  }

  Future<void> _finishWorkout() async {
    if (_blocks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one exercise first.')),
      );
      return;
    }

    if (_blocks.any((b) => b.exercise.exerciseId == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('One or more exercises are invalid. Try re-adding them.'),
        ),
      );
      return;
    }

    setState(() => _saving = true);
    _stopwatch.stop();
    _ticker.cancel();

    try {
      final db = DatabaseHelper.instance;
      final now = DateTime.now();
      final dateStr =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      final workout = Workout(
        workoutDate: dateStr,
        duration: _elapsedMinutes,
        workoutName: _nameController.text.trim(),
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
      );

      final workoutId = await db.insertWorkout(workout.toMap());

      for (var i = 0; i < _blocks.length; i++) {
        final block = _blocks[i];
        final exerciseId = block.exercise.exerciseId!;

        final we = WorkoutExercise(
          workoutId: workoutId,
          exerciseId: exerciseId,
          sortOrder: i,
        );
        final weId = await db.insertWorkoutExercise(we.toInsertMap());

        for (var j = 0; j < block.sets.length; j++) {
          final row = block.sets[j];
          await db.insertWorkoutSet({
            'workout_exercise_id': weId,
            'set_index': j,
            'reps': row.parsedReps(),
            'weight': row.parsedWeight(),
          });
        }
      }

      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      context.read<WorkoutRefreshNotifier>().notifyWorkoutsChanged();
      Navigator.pop(context);
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Workout saved!'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving workout: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        final leave = await _confirmDiscard();
        if (leave && mounted) navigator.pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Start Workout'),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: _TimerBadge(elapsed: _elapsed),
            ),
          ],
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: TextField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Workout name',
                  hintText: 'e.g. Push Day, Legs',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.edit_outlined),
                ),
                textInputAction: TextInputAction.next,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: 'Notes (optional)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.notes_outlined),
                ),
                maxLines: 2,
                textInputAction: TextInputAction.done,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Exercises',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _saving ? null : _showAddExerciseDialog,
                    icon: const Icon(Icons.add),
                    label: const Text('Add exercise'),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: _blocks.isEmpty
                  ? _buildEmptyExercises(theme)
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 100),
                      itemCount: _blocks.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final block = _blocks[index];
                        return _ExerciseBlockCard(
                          key: ValueKey(
                            '${block.exercise.exerciseId}_$index',
                          ),
                          block: block,
                          onRemoveExercise: () => _removeBlock(index),
                          onChanged: () => setState(() {}),
                        );
                      },
                    ),
            ),
          ],
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: FilledButton.icon(
              onPressed: _saving ? null : _finishWorkout,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.check),
              label: Text(_saving ? 'Saving…' : 'Finish workout'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyExercises(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.add_circle_outline,
              size: 56, color: theme.colorScheme.outlineVariant),
          const SizedBox(height: 12),
          Text('No exercises yet', style: theme.textTheme.titleSmall),
          const SizedBox(height: 4),
          Text(
            'Tap “Add exercise” and pick a movement. Each one starts with one set — add more sets as you go.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ─── Exercise block (Hevy-style: multiple sets per exercise) ─────────────────

class _ExerciseBlockCard extends StatelessWidget {
  const _ExerciseBlockCard({
    super.key,
    required this.block,
    required this.onRemoveExercise,
    required this.onChanged,
  });

  final _WorkoutBlock block;
  final VoidCallback onRemoveExercise;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        block.exercise.exerciseName,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        block.exercise.muscleGroup,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Remove exercise',
                  onPressed: onRemoveExercise,
                  icon: Icon(Icons.close, color: scheme.outline),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                SizedBox(
                  width: 44,
                  child: Text(
                    'Set',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Reps',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'kg',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(width: 40),
              ],
            ),
            const SizedBox(height: 4),
            ...List.generate(block.sets.length, (i) {
              final setRow = block.sets[i];
              final canDelete = block.sets.length > 1;
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 44,
                      child: Text(
                        '${i + 1}',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: setRow.repsCtrl,
                        onChanged: (_) => onChanged(),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: const InputDecoration(
                          isDense: true,
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 10,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: setRow.weightCtrl,
                        onChanged: (_) => onChanged(),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'^\d*\.?\d*'),
                          ),
                        ],
                        decoration: const InputDecoration(
                          isDense: true,
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 10,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 40,
                      child: IconButton(
                        tooltip: canDelete ? 'Delete set' : 'Keep at least one set',
                        onPressed: canDelete
                            ? () {
                                block.removeSetAt(i);
                                onChanged();
                              }
                            : null,
                        icon: Icon(
                          Icons.delete_outline,
                          color: canDelete
                              ? scheme.error
                              : scheme.outline.withValues(alpha: 0.35),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () {
                  block.addSet();
                  onChanged();
                },
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add set'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Timer badge ──────────────────────────────────────────────────────────────

class _TimerBadge extends StatelessWidget {
  const _TimerBadge({required this.elapsed});
  final String elapsed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timer_outlined,
              size: 16, color: theme.colorScheme.onPrimaryContainer),
          const SizedBox(width: 4),
          Text(
            elapsed,
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onPrimaryContainer,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Pick exercise dialog (no sets/reps here — those are on the workout screen)

const List<String> _kMuscleGroups = [
  'Chest',
  'Back',
  'Legs',
  'Shoulders',
  'Arms',
  'Core',
  'Cardio',
];

class _PickExerciseDialog extends StatefulWidget {
  const _PickExerciseDialog({
    required this.exercises,
    required this.onPick,
  });

  final List<Exercise> exercises;
  final ValueChanged<Exercise> onPick;

  @override
  State<_PickExerciseDialog> createState() => _PickExerciseDialogState();
}

class _PickExerciseDialogState extends State<_PickExerciseDialog> {
  late List<Exercise> _exercises;
  Exercise? _selected;

  bool _creatingNew = false;
  bool _savingNew = false;
  final _newNameCtrl = TextEditingController();
  String _newMuscleGroup = _kMuscleGroups.first;
  final _newNameFormKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _exercises = List.from(widget.exercises);
  }

  @override
  void dispose() {
    _newNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveNewExercise() async {
    if (!_newNameFormKey.currentState!.validate()) return;

    setState(() => _savingNew = true);
    try {
      final newExercise = Exercise(
        name: _newNameCtrl.text.trim(),
        muscleGroup: _newMuscleGroup,
      );
      final id = await DatabaseHelper.instance.insertExercise(newExercise);
      final saved = Exercise(
        exerciseId: id,
        name: _newNameCtrl.text.trim(),
        muscleGroup: _newMuscleGroup,
      );
      setState(() {
        _exercises.add(saved);
        _exercises.sort((a, b) =>
            a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        _selected = saved;
        _creatingNew = false;
        _newNameCtrl.clear();
        _newMuscleGroup = _kMuscleGroups.first;
        _savingNew = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _savingNew = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to create exercise: $e')),
      );
    }
  }

  void _addToWorkout() {
    if (_selected == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an exercise')),
      );
      return;
    }
    widget.onPick(_selected!);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('Add exercise'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_exercises.isEmpty && !_creatingNew)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'No exercises yet. Create one below.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              )
            else if (!_creatingNew)
              DropdownButtonFormField<Exercise>(
                initialValue: _selected,
                decoration: const InputDecoration(
                  labelText: 'Exercise',
                  border: OutlineInputBorder(),
                ),
                items: _exercises
                    .map(
                      (e) => DropdownMenuItem(
                        value: e,
                        child: Text(e.exerciseName),
                      ),
                    )
                    .toList(),
                onChanged: (e) => setState(() => _selected = e),
              ),
            if (!_creatingNew)
              TextButton.icon(
                onPressed: () => setState(() => _creatingNew = true),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Create new exercise'),
              ),
            if (_creatingNew) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Form(
                  key: _newNameFormKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'New exercise',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _newNameCtrl,
                        autofocus: true,
                        decoration: const InputDecoration(
                          labelText: 'Name',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        validator: (v) {
                          if ((v ?? '').trim().isEmpty) {
                            return 'Name is required';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        initialValue: _newMuscleGroup,
                        decoration: const InputDecoration(
                          labelText: 'Muscle group',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: _kMuscleGroups
                            .map(
                              (g) => DropdownMenuItem(
                                value: g,
                                child: Text(g),
                              ),
                            )
                            .toList(),
                        onChanged: (v) {
                          if (v != null) {
                            setState(() => _newMuscleGroup = v);
                          }
                        },
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          TextButton(
                            onPressed: _savingNew
                                ? null
                                : () => setState(() {
                                      _creatingNew = false;
                                      _newNameCtrl.clear();
                                    }),
                            child: const Text('Cancel'),
                          ),
                          const Spacer(),
                          FilledButton(
                            onPressed: _savingNew ? null : _saveNewExercise,
                            child: _savingNew
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text('Create'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _creatingNew ? null : _addToWorkout,
          child: const Text('Add'),
        ),
      ],
    );
  }
}
