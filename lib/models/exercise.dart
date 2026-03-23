class Exercise {
  final int? exerciseId;
  final String exerciseName;
  final String muscleGroup;
  final String equipment;

  Exercise({
    int? exerciseId,
    int? id,
    String? exerciseName,
    String? name,
    required this.muscleGroup,
    this.equipment = '',
  })  : exerciseId = exerciseId ?? id,
        exerciseName = (exerciseName ?? name ?? '').trim();

  int? get id => exerciseId;
  String get name => exerciseName;

  factory Exercise.fromMap(dynamic value) {
    if (value is Exercise) return value;
    final map = value as Map<String, Object?>;
    return Exercise(
      exerciseId: (map['exercise_id'] ?? map['id']) as int?,
      exerciseName: ((map['exercise_name'] ?? map['name']) as String?) ?? '',
      muscleGroup: (map['muscle_group'] as String?) ?? '',
      equipment: (map['equipment'] as String?) ?? '',
    );
  }

  Map<String, Object?> toMap() {
    return {
      if (exerciseId != null) 'exercise_id': exerciseId,
      'exercise_name': exerciseName,
      'muscle_group': muscleGroup,
      'equipment': equipment,
    };
  }

  Exercise copyWith({
    int? id,
    int? exerciseId,
    String? name,
    String? exerciseName,
    String? muscleGroup,
    String? equipment,
  }) {
    return Exercise(
      exerciseId: exerciseId ?? id ?? this.exerciseId,
      exerciseName: exerciseName ?? name ?? this.exerciseName,
      muscleGroup: muscleGroup ?? this.muscleGroup,
      equipment: equipment ?? this.equipment,
    );
  }
}
