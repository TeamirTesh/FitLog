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

  static int? _asInt(Object? v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }

  factory Workout.fromMap(Map<String, Object?> map) {
    final nameRaw = map['workout_name'] ?? map['name'];
    return Workout(
      workoutId: _asInt(map['workout_id'] ?? map['id']),
      workoutDate: ((map['workout_date'] ?? map['date']) as String?) ?? '',
      duration: _asInt(map['duration']) ?? 0,
      notes: map['notes'] as String?,
      workoutName: (nameRaw is String ? nameRaw : nameRaw?.toString())?.trim() ?? '',
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
