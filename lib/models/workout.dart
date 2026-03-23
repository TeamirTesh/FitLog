class Workout {
  final int? workoutId;
  final String workoutDate;
  final int duration;
  final String? notes;

  Workout({
    this.workoutId,
    required this.workoutDate,
    required this.duration,
    this.notes,
  });

  factory Workout.fromMap(Map<String, dynamic> map) {
    return Workout(
      workoutId: map['workout_id'] as int?,
      workoutDate: map['workout_date'] as String,
      duration: map['duration'] as int,
      notes: map['notes'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (workoutId != null) 'workout_id': workoutId,
      'workout_date': workoutDate,
      'duration': duration,
      'notes': notes,
    };
  }
}
