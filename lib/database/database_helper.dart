import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/exercise.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._internal();
  static Database? _database;

  DatabaseHelper._internal();

  static const String _dbName = 'fitlog.db';
  static const int _dbVersion = 1;

  static const String tableExercises = 'exercises';

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbName);
    return openDatabase(path, version: _dbVersion, onCreate: _onCreate);
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
}
