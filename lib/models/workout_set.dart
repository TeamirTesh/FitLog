class WorkoutSet {
  final int? id;
  final int workoutExerciseId;
  final int setIndex;
  final int reps;
  final double weight;

  WorkoutSet({
    this.id,
    required this.workoutExerciseId,
    required this.setIndex,
    required this.reps,
    required this.weight,
  });

  factory WorkoutSet.fromMap(Map<String, Object?> map) {
    return WorkoutSet(
      id: map['id'] as int?,
      workoutExerciseId: map['workout_exercise_id'] as int,
      setIndex: (map['set_index'] as int?) ?? 0,
      reps: (map['reps'] as int?) ?? 0,
      weight: (map['weight'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, Object?> toMap() {
    return {
      if (id != null) 'id': id,
      'workout_exercise_id': workoutExerciseId,
      'set_index': setIndex,
      'reps': reps,
      'weight': weight,
    };
  }
}
