import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../database/database_helper.dart';
import '../models/exercise.dart';
import '../models/workout.dart';
import '../models/workout_exercise.dart';

// ─── Data class for an exercise entry pending save ────────────────────────────

class _WorkoutEntry {
  final Exercise exercise;
  int sets;
  int reps;
  double weight;

  _WorkoutEntry({
    required this.exercise,
    required this.sets,
    required this.reps,
    required this.weight,
  });
}

// ─── Screen ───────────────────────────────────────────────────────────────────

class StartWorkoutScreen extends StatefulWidget {
  const StartWorkoutScreen({super.key});

  @override
  State<StartWorkoutScreen> createState() => _StartWorkoutScreenState();
}

class _StartWorkoutScreenState extends State<StartWorkoutScreen> {
  final _notesController = TextEditingController();
  final List<_WorkoutEntry> _entries = [];

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
    _notesController.dispose();
    super.dispose();
  }

  // ─── Helpers ────────────────────────────────────────────────────────────

  String get _elapsed {
    final s = _stopwatch.elapsed;
    final h = s.inHours;
    final m = s.inMinutes.remainder(60).toString().padLeft(2, '0');
    final sec = s.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$sec' : '$m:$sec';
  }

  int get _elapsedMinutes => _stopwatch.elapsed.inMinutes;

  // ─── Unsaved-changes guard ───────────────────────────────────────────────

  Future<bool> _confirmDiscard() async {
    if (_entries.isEmpty) return true;
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

  // ─── Add exercise dialog ─────────────────────────────────────────────────

  Future<void> _showAddExerciseDialog() async {
    final exercises = (await DatabaseHelper.instance.getAllExercises())
        .map(Exercise.fromMap)
        .toList();

    if (!mounted) return;

    if (exercises.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No exercises found. Add some in the Exercises tab.'),
        ),
      );
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (ctx) => _AddExerciseDialog(
        exercises: exercises,
        onAdd: (entry) => setState(() => _entries.add(entry)),
      ),
    );
  }

  // ─── Save workout ────────────────────────────────────────────────────────

  Future<void> _finishWorkout() async {
    if (_entries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one exercise first.')),
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
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
      );

      final workoutId = await db.insertWorkout(workout.toMap());

      for (final entry in _entries) {
        final we = WorkoutExercise(
          workoutId: workoutId,
          exerciseId: entry.exercise.exerciseId!,
          sets: entry.sets,
          reps: entry.reps,
          weight: entry.weight,
        );
        await db.insertWorkoutExercise(we.toMap());
      }

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
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

  // ─── Build ───────────────────────────────────────────────────────────────

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
          children: [
            // Notes field
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: TextField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: 'Workout notes (optional)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.notes),
                ),
                maxLines: 2,
                textInputAction: TextInputAction.done,
              ),
            ),

            // Section header
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
                    label: const Text('Add Exercise'),
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // Exercise list / empty state
            Expanded(
              child: _entries.isEmpty
                  ? _buildEmptyExercises(theme)
                  : _buildExerciseList(),
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
              label: Text(_saving ? 'Saving…' : 'Finish Workout'),
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
          Text('No exercises added yet',
              style: theme.textTheme.titleSmall),
          const SizedBox(height: 4),
          Text(
            'Tap "Add Exercise" to get started',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExerciseList() {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: _entries.length,
      separatorBuilder: (_, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final entry = _entries[index];
        return Dismissible(
          key: ValueKey(Object.hash(entry.exercise.exerciseId, index)),
          direction: DismissDirection.endToStart,
          background: _DismissBackground(),
          onDismissed: (_) => setState(() => _entries.removeAt(index)),
          child: _ExerciseEntryCard(entry: entry),
        );
      },
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
              fontFeatures: [const FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Dismiss background ───────────────────────────────────────────────────────

class _DismissBackground extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        Icons.delete_outline,
        color: Theme.of(context).colorScheme.onErrorContainer,
      ),
    );
  }
}

// ─── Exercise entry card ──────────────────────────────────────────────────────

class _ExerciseEntryCard extends StatelessWidget {
  const _ExerciseEntryCard({required this.entry});
  final _WorkoutEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.exercise.exerciseName,
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    entry.exercise.muscleGroup,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            _Stat(label: 'Sets', value: '${entry.sets}'),
            const SizedBox(width: 12),
            _Stat(label: 'Reps', value: '${entry.reps}'),
            const SizedBox(width: 12),
            _Stat(label: 'kg', value: '${entry.weight}'),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(value,
            style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.bold)),
        Text(label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            )),
      ],
    );
  }
}

// ─── Add Exercise Dialog ──────────────────────────────────────────────────────

class _AddExerciseDialog extends StatefulWidget {
  const _AddExerciseDialog({required this.exercises, required this.onAdd});
  final List<Exercise> exercises;
  final ValueChanged<_WorkoutEntry> onAdd;

  @override
  State<_AddExerciseDialog> createState() => _AddExerciseDialogState();
}

class _AddExerciseDialogState extends State<_AddExerciseDialog> {
  final _formKey = GlobalKey<FormState>();
  final _setsCtrl = TextEditingController();
  final _repsCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();

  Exercise? _selected;

  @override
  void dispose() {
    _setsCtrl.dispose();
    _repsCtrl.dispose();
    _weightCtrl.dispose();
    super.dispose();
  }

  String? _validatePositiveInt(String? v, String field) {
    if (v == null || v.trim().isEmpty) return '$field is required';
    final n = int.tryParse(v.trim());
    if (n == null || n <= 0) return 'Enter a positive number';
    return null;
  }

  String? _validateWeight(String? v) {
    if (v == null || v.trim().isEmpty) return 'Weight is required';
    final n = double.tryParse(v.trim());
    if (n == null || n < 0) return 'Enter a valid weight';
    return null;
  }

  void _submit() {
    if (_selected == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an exercise')),
      );
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    widget.onAdd(
      _WorkoutEntry(
        exercise: _selected!,
        sets: int.parse(_setsCtrl.text.trim()),
        reps: int.parse(_repsCtrl.text.trim()),
        weight: double.parse(_weightCtrl.text.trim()),
      ),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Exercise'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<Exercise>(
                initialValue: _selected,
                decoration: const InputDecoration(
                  labelText: 'Exercise',
                  border: OutlineInputBorder(),
                ),
                items: widget.exercises
                    .map((e) => DropdownMenuItem(
                          value: e,
                          child: Text(e.exerciseName),
                        ))
                    .toList(),
                onChanged: (e) => setState(() => _selected = e),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _setsCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Sets',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      validator: (v) => _validatePositiveInt(v, 'Sets'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: _repsCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Reps',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      validator: (v) => _validatePositiveInt(v, 'Reps'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _weightCtrl,
                decoration: const InputDecoration(
                  labelText: 'Weight (kg)',
                  border: OutlineInputBorder(),
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                ],
                validator: _validateWeight,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Add'),
        ),
      ],
    );
  }
}
