import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/exercise.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._internal();
  static Database? _database;

  DatabaseHelper._internal();

  static const String _dbName = 'fitlog.db';
  static const int _dbVersion = 2;

  static const String tableExercises = 'exercises';
  static const String tableWorkouts = 'workouts';
  static const String tableWorkoutExercises = 'workout_exercises';

  Future<Database> get database async {
    if (_database != null && _database!.isOpen) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbName);
    return openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onConfigure: (db) async => db.execute('PRAGMA foreign_keys = ON'),
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $tableExercises (
        exercise_id INTEGER PRIMARY KEY AUTOINCREMENT,
        exercise_name TEXT NOT NULL,
        muscle_group TEXT NOT NULL,
        equipment TEXT NOT NULL DEFAULT ''
      )
    ''');

    await db.execute('''
      CREATE TABLE $tableWorkouts (
        workout_id INTEGER PRIMARY KEY AUTOINCREMENT,
        workout_date TEXT NOT NULL,
        duration INTEGER NOT NULL DEFAULT 0,
        notes TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE $tableWorkoutExercises (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        workout_id INTEGER NOT NULL,
        exercise_id INTEGER NOT NULL,
        sets INTEGER NOT NULL DEFAULT 0,
        reps INTEGER NOT NULL DEFAULT 0,
        weight REAL NOT NULL DEFAULT 0.0,
        FOREIGN KEY(workout_id) REFERENCES $tableWorkouts(workout_id) ON DELETE CASCADE,
        FOREIGN KEY(exercise_id) REFERENCES $tableExercises(exercise_id) ON DELETE CASCADE
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS $tableExercises (
          exercise_id INTEGER PRIMARY KEY AUTOINCREMENT,
          exercise_name TEXT NOT NULL,
          muscle_group TEXT NOT NULL,
          equipment TEXT NOT NULL DEFAULT ''
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS $tableWorkoutExercises (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          workout_id INTEGER NOT NULL,
          exercise_id INTEGER NOT NULL,
          sets INTEGER NOT NULL DEFAULT 0,
          reps INTEGER NOT NULL DEFAULT 0,
          weight REAL NOT NULL DEFAULT 0.0,
          FOREIGN KEY(workout_id) REFERENCES $tableWorkouts(workout_id) ON DELETE CASCADE,
          FOREIGN KEY(exercise_id) REFERENCES $tableExercises(exercise_id) ON DELETE CASCADE
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS $tableWorkouts (
          workout_id INTEGER PRIMARY KEY AUTOINCREMENT,
          workout_date TEXT NOT NULL,
          duration INTEGER NOT NULL DEFAULT 0,
          notes TEXT
        )
      ''');
    }
  }

  Future<void> close() async {
    if (_database != null && _database!.isOpen) {
      await _database!.close();
      _database = null;
    }
  }

  Future<List<Exercise>> getAllExercises() async {
    final db = await database;
    final rows = await db.query(
      tableExercises,
      orderBy: 'exercise_name COLLATE NOCASE ASC',
    );
    return rows.map((r) => Exercise.fromMap(r)).toList();
  }

  Future<int> insertExercise(Exercise exercise) async {
    final db = await database;
    return db.insert(
      tableExercises,
      {
        'exercise_name': exercise.name,
        'muscle_group': exercise.muscleGroup,
        'equipment': exercise.equipment,
      },
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  Future<int> updateExercise(Exercise exercise) async {
    final db = await database;
    final id = exercise.id;
    if (id == null) {
      throw ArgumentError('Exercise.id cannot be null for update');
    }

    return db.update(
      tableExercises,
      {
        'exercise_name': exercise.name,
        'muscle_group': exercise.muscleGroup,
        'equipment': exercise.equipment,
      },
      where: 'exercise_id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteExercise(int id) async {
    final db = await database;
    return db.delete(
      tableExercises,
      where: 'exercise_id = ?',
      whereArgs: [id],
    );
  }

  Future<int> insertWorkout(Map<String, dynamic> workout) async {
    final db = await database;
    return db.insert(
      tableWorkouts,
      workout,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, Object?>>> getAllWorkouts() async {
    final db = await database;
    return db.rawQuery('''
      SELECT
        workout_id AS id,
        workout_date AS date,
        duration,
        notes
      FROM $tableWorkouts
      ORDER BY workout_date DESC
    ''');
  }

  Future<Map<String, Object?>?> getWorkoutById(int workoutId) async {
    final db = await database;
    final rows = await db.rawQuery(
      '''
      SELECT
        workout_id AS id,
        workout_date AS date,
        duration,
        notes
      FROM $tableWorkouts
      WHERE workout_id = ?
      LIMIT 1
      ''',
      [workoutId],
    );
    if (rows.isEmpty) return null;
    return rows.first;
  }

  Future<int> updateWorkout(int id, Map<String, dynamic> workout) async {
    final db = await database;
    return db.update(
      tableWorkouts,
      workout,
      where: 'workout_id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteWorkout(int workoutId) async {
    final db = await database;
    return db.delete(
      tableWorkouts,
      where: 'workout_id = ?',
      whereArgs: [workoutId],
    );
  }

  Future<int> insertWorkoutExercise(Map<String, dynamic> workoutExercise) async {
    final db = await database;
    return db.insert(
      tableWorkoutExercises,
      workoutExercise,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getExercisesForWorkout(int workoutId) async {
    final db = await database;
    return db.rawQuery('''
      SELECT
        we.id,
        we.workout_id,
        we.exercise_id,
        we.sets,
        we.reps,
        we.weight,
        e.exercise_name,
        e.muscle_group
      FROM $tableWorkoutExercises we
      INNER JOIN $tableExercises e ON we.exercise_id = e.exercise_id
      WHERE we.workout_id = ?
    ''', [workoutId]);
  }

  Future<Map<String, dynamic>?> getWorkoutExerciseById(int id) async {
    final db = await database;
    final rows = await db.query(
      tableWorkoutExercises,
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
    return db.update(
      tableWorkoutExercises,
      workoutExercise,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteWorkoutExercise(int id) async {
    final db = await database;
    return db.delete(
      tableWorkoutExercises,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteAllExercisesForWorkout(int workoutId) async {
    final db = await database;
    return db.delete(
      tableWorkoutExercises,
      where: 'workout_id = ?',
      whereArgs: [workoutId],
    );
  }

  Future<List<Map<String, Object?>>> getWorkoutExerciseDetails(int workoutId) async {
    final db = await database;
    return db.rawQuery(
      '''
      SELECT
        we.id,
        we.workout_id,
        we.exercise_id,
        we.sets,
        we.reps,
        we.weight,
        e.exercise_name AS exercise_name
      FROM $tableWorkoutExercises we
      INNER JOIN $tableExercises e ON e.exercise_id = we.exercise_id
      WHERE we.workout_id = ?
      ORDER BY e.exercise_name COLLATE NOCASE ASC
      ''',
      [workoutId],
    );
  }
}
