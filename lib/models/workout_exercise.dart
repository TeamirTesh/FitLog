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
}
