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
    if (_database != null) return _database!;
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
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $tableExercises (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        muscle_group TEXT NOT NULL,
        equipment TEXT NOT NULL DEFAULT ''
      )
    ''');

    await db.execute('''
      CREATE TABLE $tableWorkouts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL,
        duration INTEGER NOT NULL DEFAULT 0,
        notes TEXT NOT NULL DEFAULT ''
      )
    ''');

    await db.execute('''
      CREATE TABLE $tableWorkoutExercises (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        workout_id INTEGER NOT NULL,
        exercise_id INTEGER NOT NULL,
        sets INTEGER NOT NULL DEFAULT 0,
        reps INTEGER NOT NULL DEFAULT 0,
        weight REAL NOT NULL DEFAULT 0,
        FOREIGN KEY(workout_id) REFERENCES $tableWorkouts(id) ON DELETE CASCADE,
        FOREIGN KEY(exercise_id) REFERENCES $tableExercises(id)
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS $tableWorkouts (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          date TEXT NOT NULL,
          duration INTEGER NOT NULL DEFAULT 0,
          notes TEXT NOT NULL DEFAULT ''
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS $tableWorkoutExercises (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          workout_id INTEGER NOT NULL,
          exercise_id INTEGER NOT NULL,
          sets INTEGER NOT NULL DEFAULT 0,
          reps INTEGER NOT NULL DEFAULT 0,
          weight REAL NOT NULL DEFAULT 0,
          FOREIGN KEY(workout_id) REFERENCES $tableWorkouts(id) ON DELETE CASCADE,
          FOREIGN KEY(exercise_id) REFERENCES $tableExercises(id)
        )
      ''');
    }
  }

  Future<List<Exercise>> getAllExercises() async {
    final db = await database;
    final rows = await db.query(tableExercises, orderBy: 'name COLLATE NOCASE ASC');
    return rows.map((r) => Exercise.fromMap(r)).toList();
  }

  Future<int> insertExercise(Exercise exercise) async {
    final db = await database;
    return db.insert(
      tableExercises,
      {
        'name': exercise.name,
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
        'name': exercise.name,
        'muscle_group': exercise.muscleGroup,
        'equipment': exercise.equipment,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteExercise(int id) async {
    final db = await database;
    return db.delete(tableExercises, where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Map<String, Object?>>> getAllWorkouts() async {
    final db = await database;
    return db.query(tableWorkouts, orderBy: 'date DESC');
  }

  Future<Map<String, Object?>?> getWorkoutById(int workoutId) async {
    final db = await database;
    final rows = await db.query(
      tableWorkouts,
      where: 'id = ?',
      whereArgs: [workoutId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first;
  }

  Future<List<Map<String, Object?>>> getWorkoutExerciseDetails(
    int workoutId,
  ) async {
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
        e.name AS exercise_name
      FROM $tableWorkoutExercises we
      INNER JOIN $tableExercises e ON e.id = we.exercise_id
      WHERE we.workout_id = ?
      ORDER BY e.name COLLATE NOCASE ASC
      ''',
      [workoutId],
    );
  }

  Future<int> deleteWorkout(int workoutId) async {
    final db = await database;
    return db.transaction((txn) async {
      await txn.delete(
        tableWorkoutExercises,
        where: 'workout_id = ?',
        whereArgs: [workoutId],
      );
      return txn.delete(tableWorkouts, where: 'id = ?', whereArgs: [workoutId]);
    });
  }
}
