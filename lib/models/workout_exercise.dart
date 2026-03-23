class WorkoutExercise {
  final int? id;
  final int workoutId;
  final int exerciseId;
  final int sets;
  final int reps;
  final double weight;

  WorkoutExercise({
    this.id,
    required this.workoutId,
    required this.exerciseId,
    required this.sets,
    required this.reps,
    required this.weight,
  });

  factory WorkoutExercise.fromMap(Map<String, dynamic> map) {
    return WorkoutExercise(
      id: map['id'] as int?,
      workoutId: map['workout_id'] as int,
      exerciseId: map['exercise_id'] as int,
      sets: map['sets'] as int,
      reps: map['reps'] as int,
      weight: (map['weight'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'workout_id': workoutId,
      'exercise_id': exerciseId,
      'sets': sets,
      'reps': reps,
      'weight': weight,
    };
  }
}
