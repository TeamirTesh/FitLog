class Workout {
  final int? workoutId;
  final String workoutDate;
  final int duration;
  final String? notes;
  /// User-visible title (e.g. "Push Day"). Empty string if unset.
  final String workoutName;

  Workout({
    this.workoutId,
    required this.workoutDate,
    required this.duration,
    this.notes,
    this.workoutName = '',
  });

  factory Workout.fromMap(Map<String, dynamic> map) {
    final nameRaw = map['workout_name'] ?? map['name'];
    return Workout(
      workoutId: (map['workout_id'] ?? map['id']) as int?,
      workoutDate: ((map['workout_date'] ?? map['date']) as String?) ?? '',
      duration: (map['duration'] as int?) ?? 0,
      notes: map['notes'] as String?,
      workoutName: (nameRaw as String?)?.trim() ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (workoutId != null) 'workout_id': workoutId,
      'workout_date': workoutDate,
      'duration': duration,
      'notes': notes,
      'workout_name': workoutName.trim(),
    };
  }
}
