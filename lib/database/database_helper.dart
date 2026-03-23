import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._internal();
  static Database? _database;

  DatabaseHelper._internal();

  // ─── Connection ───────────────────────────────────────────────────────────

  Future<Database> get database async {
    if (_database != null && _database!.isOpen) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'fitlog.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
      onConfigure: (db) async => await db.execute('PRAGMA foreign_keys = ON'),
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE exercises (
        exercise_id   INTEGER PRIMARY KEY AUTOINCREMENT,
        exercise_name TEXT    NOT NULL,
        muscle_group  TEXT    NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE workouts (
        workout_id   INTEGER PRIMARY KEY AUTOINCREMENT,
        workout_date TEXT    NOT NULL,
        duration     INTEGER NOT NULL DEFAULT 0,
        notes        TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE workout_exercises (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        workout_id  INTEGER NOT NULL,
        exercise_id INTEGER NOT NULL,
        sets        INTEGER NOT NULL DEFAULT 0,
        reps        INTEGER NOT NULL DEFAULT 0,
        weight      REAL    NOT NULL DEFAULT 0.0,
        FOREIGN KEY (workout_id)  REFERENCES workouts  (workout_id)  ON DELETE CASCADE,
        FOREIGN KEY (exercise_id) REFERENCES exercises (exercise_id) ON DELETE CASCADE
      )
    ''');
  }

  Future<void> close() async {
    if (_database != null && _database!.isOpen) {
      await _database!.close();
      _database = null;
    }
  }

  // ─── Exercises CRUD ───────────────────────────────────────────────────────

  Future<int> insertExercise(Map<String, dynamic> exercise) async {
    final db = await database;
    return await db.insert(
      'exercises',
      exercise,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getAllExercises() async {
    final db = await database;
    return await db.query('exercises', orderBy: 'exercise_name ASC');
  }

  Future<Map<String, dynamic>?> getExerciseById(int id) async {
    final db = await database;
    final rows = await db.query(
      'exercises',
      where: 'exercise_id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isNotEmpty ? rows.first : null;
  }

  Future<List<Map<String, dynamic>>> getExercisesByMuscleGroup(
    String muscleGroup,
  ) async {
    final db = await database;
    return await db.query(
      'exercises',
      where: 'muscle_group = ?',
      whereArgs: [muscleGroup],
      orderBy: 'exercise_name ASC',
    );
  }

  Future<int> updateExercise(int id, Map<String, dynamic> exercise) async {
    final db = await database;
    return await db.update(
      'exercises',
      exercise,
      where: 'exercise_id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteExercise(int id) async {
    final db = await database;
    return await db.delete(
      'exercises',
      where: 'exercise_id = ?',
      whereArgs: [id],
    );
  }

  // ─── Workouts CRUD ────────────────────────────────────────────────────────

  Future<int> insertWorkout(Map<String, dynamic> workout) async {
    final db = await database;
    return await db.insert(
      'workouts',
      workout,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getAllWorkouts() async {
    final db = await database;
    return await db.query('workouts', orderBy: 'workout_date DESC');
  }

  Future<Map<String, dynamic>?> getWorkoutById(int id) async {
    final db = await database;
    final rows = await db.query(
      'workouts',
      where: 'workout_id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isNotEmpty ? rows.first : null;
  }

  Future<int> updateWorkout(int id, Map<String, dynamic> workout) async {
    final db = await database;
    return await db.update(
      'workouts',
      workout,
      where: 'workout_id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteWorkout(int id) async {
    final db = await database;
    // workout_exercises rows are removed via ON DELETE CASCADE
    return await db.delete(
      'workouts',
      where: 'workout_id = ?',
      whereArgs: [id],
    );
  }

  // ─── WorkoutExercises CRUD ────────────────────────────────────────────────

  Future<int> insertWorkoutExercise(Map<String, dynamic> workoutExercise) async {
    final db = await database;
    return await db.insert(
      'workout_exercises',
      workoutExercise,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getExercisesForWorkout(
    int workoutId,
  ) async {
    final db = await database;
    // Join to include exercise_name and muscle_group alongside set data
    return await db.rawQuery('''
      SELECT
        we.id, we.workout_id, we.exercise_id,
        we.sets, we.reps, we.weight,
        e.exercise_name, e.muscle_group
      FROM workout_exercises we
      INNER JOIN exercises e ON we.exercise_id = e.exercise_id
      WHERE we.workout_id = ?
    ''', [workoutId]);
  }

  Future<Map<String, dynamic>?> getWorkoutExerciseById(int id) async {
    final db = await database;
    final rows = await db.query(
      'workout_exercises',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isNotEmpty ? rows.first : null;
  }

  Future<int> updateWorkoutExercise(
    int id,
    Map<String, dynamic> workoutExercise,
  ) async {
    final db = await database;
    return await db.update(
      'workout_exercises',
      workoutExercise,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteWorkoutExercise(int id) async {
    final db = await database;
    return await db.delete(
      'workout_exercises',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteAllExercisesForWorkout(int workoutId) async {
    final db = await database;
    return await db.delete(
      'workout_exercises',
      where: 'workout_id = ?',
      whereArgs: [workoutId],
    );
  }
}
