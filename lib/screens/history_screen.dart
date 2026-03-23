import 'package:flutter/material.dart';

import '../database/database_helper.dart';
import 'workout_detail_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final DatabaseHelper _db = DatabaseHelper.instance;

  bool _loading = false;
  List<Map<String, Object?>> _workouts = const [];

  @override
  void initState() {
    super.initState();
    _refreshWorkouts();
  }

  Future<void> _refreshWorkouts() async {
    setState(() => _loading = true);
    try {
      final items = await _db.getAllWorkouts();
      if (!mounted) return;
      setState(() {
        _workouts = items;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load workouts: $e')),
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

  String _durationLabel(Object? value) {
    if (value is int) return '$value min';
    if (value is String && value.trim().isNotEmpty) return '${value.trim()} min';
    return '0 min';
  }

  Future<void> _openWorkout(Map<String, Object?> workout) async {
    final workoutId = workout['id'];
    if (workoutId is! int) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open workout details')),
      );
      return;
    }

    final deleted = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => WorkoutDetailScreen(workoutId: workoutId),
      ),
    );

    if (deleted == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Workout deleted')),
      );
      await _refreshWorkouts();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Workout History'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _refreshWorkouts,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _workouts.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.history_toggle_off,
                            size: 64,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'No workouts yet',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Your completed workouts will show up here.',
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
                  onRefresh: _refreshWorkouts,
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(12),
                    itemCount: _workouts.length,
                    itemBuilder: (context, index) {
                      final workout = _workouts[index];
                      final date = (workout['date'] as String?) ?? '';
                      final notes = ((workout['notes'] as String?) ?? '').trim();
                      final preview = notes.isEmpty ? 'No notes' : notes;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(14),
                          title: Text(
                            _formatDate(date),
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Duration: ${_durationLabel(workout['duration'])}'),
                                const SizedBox(height: 4),
                                Text(
                                  preview,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => _openWorkout(workout),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
