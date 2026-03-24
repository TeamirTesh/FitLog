class WorkoutExercise {
  final int? id;
  final int workoutId;
  final int exerciseId;
  final int sortOrder;

  /// Legacy aggregate fields (pre–per-set storage). Prefer [WorkoutSet] rows.
  final int legacySets;
  final int legacyReps;
  final double legacyWeight;

  WorkoutExercise({
    this.id,
    required this.workoutId,
    required this.exerciseId,
    this.sortOrder = 0,
    this.legacySets = 0,
    this.legacyReps = 0,
    this.legacyWeight = 0,
  });

  factory WorkoutExercise.fromMap(Map<String, dynamic> map) {
    return WorkoutExercise(
      id: map['id'] as int?,
      workoutId: map['workout_id'] as int,
      exerciseId: map['exercise_id'] as int,
      sortOrder: (map['sort_order'] as int?) ?? 0,
      legacySets: (map['sets'] as int?) ?? 0,
      legacyReps: (map['reps'] as int?) ?? 0,
      legacyWeight: (map['weight'] as num?)?.toDouble() ?? 0.0,
    );
  }

  /// Insert map: legacy columns kept at 0; sets live in `workout_sets`.
  Map<String, dynamic> toInsertMap() {
    return {
      'workout_id': workoutId,
      'exercise_id': exerciseId,
      'sort_order': sortOrder,
      'sets': 0,
      'reps': 0,
      'weight': 0.0,
    };
  }
}
