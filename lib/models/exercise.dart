class Exercise {
  final int? exerciseId;
  final String exerciseName;
  final String muscleGroup;

  Exercise({
    this.exerciseId,
    required this.exerciseName,
    required this.muscleGroup,
  });

  factory Exercise.fromMap(Map<String, dynamic> map) {
    return Exercise(
      exerciseId: map['exercise_id'] as int?,
      exerciseName: map['exercise_name'] as String,
      muscleGroup: map['muscle_group'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (exerciseId != null) 'exercise_id': exerciseId,
      'exercise_name': exerciseName,
      'muscle_group': muscleGroup,
    };
  }
}
