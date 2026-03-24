import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../database/database_helper.dart';
import '../models/workout.dart';
import '../providers/workout_refresh_notifier.dart';
import 'start_workout_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with AutomaticKeepAliveClientMixin {
  late Future<List<Workout>> _recentWorkouts;
  WorkoutRefreshNotifier? _workoutRefresh;
  bool _refreshListenerAttached = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadWorkouts();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_refreshListenerAttached) {
      _refreshListenerAttached = true;
      _workoutRefresh = context.read<WorkoutRefreshNotifier>();
      _workoutRefresh!.addListener(_refresh);
    }
  }

  @override
  void dispose() {
    if (_workoutRefresh != null) {
      _workoutRefresh!.removeListener(_refresh);
    }
    super.dispose();
  }

  void _loadWorkouts() {
    _recentWorkouts = _fetchRecentWorkouts();
  }

  Future<List<Workout>> _fetchRecentWorkouts() async {
    final rows = await DatabaseHelper.instance.getAllWorkouts();
    return rows
        .take(5)
        .map((row) => Workout.fromMap(row))
        .toList();
  }

  void _refresh() => setState(() => _loadWorkouts());

  void _goToStartWorkout() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const StartWorkoutScreen()),
    );
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('FitLog')),
      body: RefreshIndicator(
        onRefresh: () async => _refresh(),
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
                child: Text(
                  'Welcome to FitLog',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: Text(
                  'Recent Workouts',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            FutureBuilder<List<Workout>>(
              future: _recentWorkouts,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SliverFillRemaining(
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                if (snapshot.hasError) {
                  return SliverFillRemaining(
                    child: Center(
                      child: Text('Error loading workouts: ${snapshot.error}'),
                    ),
                  );
                }

                final workouts = snapshot.data ?? [];

                if (workouts.isEmpty) {
                  return SliverFillRemaining(
                    hasScrollBody: false,
                    child: _EmptyState(onStart: _goToStartWorkout),
                  );
                }

                return SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                  sliver: SliverList.separated(
                    itemCount: workouts.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 10),
                    itemBuilder: (context, index) =>
                        _WorkoutCard(workout: workouts[index]),
                  ),
                );
              },
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _goToStartWorkout,
        icon: const Icon(Icons.add),
        label: const Text('Start Workout'),
      ),
    );
  }
}

// ─── Workout Card ─────────────────────────────────────────────────────────────

class _WorkoutCard extends StatelessWidget {
  const _WorkoutCard({required this.workout});

  final Workout workout;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final notes = workout.notes;
    final hasNotes = notes != null && notes.trim().isNotEmpty;
    final title = workout.workoutName.trim().isNotEmpty
        ? workout.workoutName.trim()
        : workout.workoutDate;

    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: theme.colorScheme.primaryContainer,
              child: Icon(
                Icons.fitness_center,
                color: theme.colorScheme.onPrimaryContainer,
                size: 20,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    workout.workoutName.trim().isNotEmpty
                        ? '${workout.workoutDate} · ${workout.duration} min'
                        : '${workout.duration} min',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  if (hasNotes) ...[
                    const SizedBox(height: 4),
                    Text(
                      notes,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Empty State ──────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onStart});

  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.directions_run,
              size: 72,
              color: theme.colorScheme.outlineVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'No workouts yet',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Hit the button below to log your first session!',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
