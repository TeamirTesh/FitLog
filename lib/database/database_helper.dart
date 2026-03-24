import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/exercise.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._internal();
  static Database? _database;

  DatabaseHelper._internal();

  static const String _dbName = 'fitlog.db';
  static const int _dbVersion = 5;

  static const String tableExercises = 'exercises';
  static const String tableWorkouts = 'workouts';
  static const String tableWorkoutExercises = 'workout_exercises';
  static const String tableWorkoutSets = 'workout_sets';

  /// Shipped with the app; seeded when the exercises table is empty.
  static const List<Map<String, String>> _presetExercises = [
    {'name': 'Bench Press', 'muscle_group': 'Chest'},
    {'name': 'Incline Bench Press', 'muscle_group': 'Chest'},
    {'name': 'Squat', 'muscle_group': 'Legs'},
    {'name': 'Leg Press', 'muscle_group': 'Legs'},
    {'name': 'Romanian Deadlift', 'muscle_group': 'Legs'},
    {'name': 'Deadlift', 'muscle_group': 'Back'},
    {'name': 'Lat Pulldown', 'muscle_group': 'Back'},
    {'name': 'Seated Cable Row', 'muscle_group': 'Back'},
    {'name': 'Barbell Row', 'muscle_group': 'Back'},
    {'name': 'Pull-Up', 'muscle_group': 'Back'},
    {'name': 'Overhead Press', 'muscle_group': 'Shoulders'},
    {'name': 'Lateral Raise', 'muscle_group': 'Shoulders'},
    {'name': 'Face Pull', 'muscle_group': 'Shoulders'},
    {'name': 'Dumbbell Curl', 'muscle_group': 'Arms'},
    {'name': 'Tricep Pushdown', 'muscle_group': 'Arms'},
    {'name': 'Plank', 'muscle_group': 'Core'},
  ];

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
      onOpen: (db) async => _ensureExercisesEquipmentColumn(db),
    );
  }

  Future<void> _createTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableExercises (
        exercise_id INTEGER PRIMARY KEY AUTOINCREMENT,
        exercise_name TEXT NOT NULL,
        muscle_group TEXT NOT NULL,
        equipment TEXT NOT NULL DEFAULT ""
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableWorkouts (
        workout_id INTEGER PRIMARY KEY AUTOINCREMENT,
        workout_date TEXT NOT NULL,
        duration INTEGER NOT NULL DEFAULT 0,
        notes TEXT,
        workout_name TEXT NOT NULL DEFAULT ''
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableWorkoutExercises (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        workout_id INTEGER NOT NULL,
        exercise_id INTEGER NOT NULL,
        sort_order INTEGER NOT NULL DEFAULT 0,
        sets INTEGER NOT NULL DEFAULT 0,
        reps INTEGER NOT NULL DEFAULT 0,
        weight REAL NOT NULL DEFAULT 0.0,
        FOREIGN KEY(workout_id) REFERENCES $tableWorkouts(workout_id) ON DELETE CASCADE,
        FOREIGN KEY(exercise_id) REFERENCES $tableExercises(exercise_id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableWorkoutSets (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        workout_exercise_id INTEGER NOT NULL,
        set_index INTEGER NOT NULL,
        reps INTEGER NOT NULL DEFAULT 0,
        weight REAL NOT NULL DEFAULT 0.0,
        FOREIGN KEY(workout_exercise_id) REFERENCES $tableWorkoutExercises(id) ON DELETE CASCADE,
        UNIQUE(workout_exercise_id, set_index)
      )
    ''');
  }

  Future<void> _seedPresetExercises(Database db) async {
    final batch = db.batch();
    for (final preset in _presetExercises) {
      batch.insert(
        tableExercises,
        {
          'exercise_name': preset['name'],
          'muscle_group': preset['muscle_group'],
          'equipment': '',
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<void> _onCreate(Database db, int version) async {
    await _createTables(db);
    await _seedPresetExercises(db);
  }

  /// Legacy DBs may have been created without [equipment]. Inserts fail until this runs.
  Future<void> _ensureExercisesEquipmentColumn(Database db) async {
    final info = await db.rawQuery('PRAGMA table_info($tableExercises)');
    final hasEquipment = info.any((row) => row['name'] == 'equipment');
    if (!hasEquipment) {
      await db.execute(
        'ALTER TABLE $tableExercises ADD COLUMN equipment TEXT NOT NULL DEFAULT ""',
      );
    }
  }

  Future<bool> _columnExists(Database db, String table, String column) async {
    final info = await db.rawQuery('PRAGMA table_info($table)');
    return info.any((row) => row['name'] == column);
  }

  Future<void> _migrateToV5(Database db) async {
    if (!await _columnExists(db, tableWorkouts, 'workout_name')) {
      await db.execute(
        'ALTER TABLE $tableWorkouts ADD COLUMN workout_name TEXT NOT NULL DEFAULT ""',
      );
    }

    await db.execute('''
      CREATE TABLE IF NOT EXISTS $tableWorkoutSets (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        workout_exercise_id INTEGER NOT NULL,
        set_index INTEGER NOT NULL,
        reps INTEGER NOT NULL DEFAULT 0,
        weight REAL NOT NULL DEFAULT 0.0,
        FOREIGN KEY(workout_exercise_id) REFERENCES $tableWorkoutExercises(id) ON DELETE CASCADE,
        UNIQUE(workout_exercise_id, set_index)
      )
    ''');

    if (!await _columnExists(db, tableWorkoutExercises, 'sort_order')) {
      await db.execute(
        'ALTER TABLE $tableWorkoutExercises ADD COLUMN sort_order INTEGER NOT NULL DEFAULT 0',
      );
    }

    final workoutIds = await db.rawQuery(
      'SELECT DISTINCT workout_id FROM $tableWorkoutExercises',
    );
    for (final row in workoutIds) {
      final wid = row['workout_id'];
      if (wid == null) continue;
      final weRows = await db.query(
        tableWorkoutExercises,
        where: 'workout_id = ?',
        whereArgs: [wid],
        orderBy: 'id ASC',
      );
      for (var i = 0; i < weRows.length; i++) {
        final weId = weRows[i]['id'];
        if (weId is! int) continue;
        await db.update(
          tableWorkoutExercises,
          {'sort_order': i},
          where: 'id = ?',
          whereArgs: [weId],
        );
      }
    }

    final allWe = await db.query(tableWorkoutExercises);
    for (final we in allWe) {
      final weId = we['id'] as int?;
      if (weId == null) continue;
      final existing = Sqflite.firstIntValue(
            await db.rawQuery(
              'SELECT COUNT(*) FROM $tableWorkoutSets WHERE workout_exercise_id = ?',
              [weId],
            ),
          ) ??
          0;
      if (existing > 0) continue;

      final rawSets = (we['sets'] as int?) ?? 1;
      final n = rawSets < 1 ? 1 : rawSets;
      final reps = (we['reps'] as int?) ?? 0;
      final weight = (we['weight'] as num?)?.toDouble() ?? 0.0;
      final batch = db.batch();
      for (var i = 0; i < n; i++) {
        batch.insert(tableWorkoutSets, {
          'workout_exercise_id': weId,
          'set_index': i,
          'reps': reps,
          'weight': weight,
        });
      }
      await batch.commit(noResult: true);
    }
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _createTables(db);
    }
    if (oldVersion < 4) {
      await _ensureExercisesEquipmentColumn(db);
      final count = Sqflite.firstIntValue(
            await db.rawQuery('SELECT COUNT(*) FROM $tableExercises'),
          ) ??
          0;
      if (count == 0) {
        await _seedPresetExercises(db);
      }
    }
    if (oldVersion < 5) {
      await _migrateToV5(db);
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
        notes,
        workout_name AS name
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
        notes,
        workout_name AS name
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
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  Future<int> insertWorkoutSet(Map<String, Object?> setRow) async {
    final db = await database;
    return db.insert(tableWorkoutSets, setRow);
  }

  Future<List<Map<String, dynamic>>> getExercisesForWorkout(int workoutId) async {
    final db = await database;
    return db.rawQuery('''
      SELECT
        we.id,
        we.workout_id,
        we.exercise_id,
        we.sort_order,
        we.sets,
        we.reps,
        we.weight,
        e.exercise_name,
        e.muscle_group
      FROM $tableWorkoutExercises we
      INNER JOIN $tableExercises e ON we.exercise_id = e.exercise_id
      WHERE we.workout_id = ?
      ORDER BY we.sort_order ASC, we.id ASC
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
        we.id AS workout_exercise_id,
        we.sort_order AS sort_order,
        e.exercise_name AS exercise_name,
        e.muscle_group AS muscle_group,
        ws.id AS set_id,
        ws.set_index AS set_index,
        ws.reps AS reps,
        ws.weight AS weight
      FROM $tableWorkoutExercises we
      INNER JOIN $tableExercises e ON e.exercise_id = we.exercise_id
      LEFT JOIN $tableWorkoutSets ws ON ws.workout_exercise_id = we.id
      WHERE we.workout_id = ?
      ORDER BY we.sort_order ASC, we.id ASC, ws.set_index ASC
      ''',
      [workoutId],
    );
  }
}
