class Exercise {
  final int? id;
  final String name;
  final String muscleGroup;
  final String equipment;

  Exercise({
    this.id,
    required this.name,
    required this.muscleGroup,
    required this.equipment,
  });

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'name': name,
      'muscle_group': muscleGroup,
      'equipment': equipment,
    };
  }

  factory Exercise.fromMap(Map<String, Object?> map) {
    return Exercise(
      id: map['id'] as int?,
      name: (map['name'] as String?) ?? '',
      muscleGroup: (map['muscle_group'] as String?) ?? '',
      equipment: (map['equipment'] as String?) ?? '',
    );
  }

  Exercise copyWith({
    int? id,
    String? name,
    String? muscleGroup,
    String? equipment,
  }) {
    return Exercise(
      id: id ?? this.id,
      name: name ?? this.name,
      muscleGroup: muscleGroup ?? this.muscleGroup,
      equipment: equipment ?? this.equipment,
    );
  }
}
