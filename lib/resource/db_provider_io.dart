import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:workout_planner/models/routine.dart';
import 'package:workout_planner/models/workout_session.dart';
import 'package:workout_planner/models/main_targeted_body_part.dart';
import 'package:workout_planner/resource/db_provider.dart';

class DBProviderIO implements DBProvider {
  DBProviderIO._internal();

  static final DBProviderIO _instance = DBProviderIO._internal();
  factory DBProviderIO() => _instance;

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await initDB();
    return _database!;
  }

  @override
  Future<Database> initDB({bool refresh = false}) async {
    Directory appDocDir = await getApplicationDocumentsDirectory();
    String path = join(appDocDir.path, "data.db");

    if (await File(path).exists() && !refresh) {
      return openDatabase(
        path,
        version: 2,
        onOpen: (db) async {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS WorkoutSessions (
              id TEXT PRIMARY KEY,
              routineId INTEGER,
              startTime TEXT NOT NULL,
              endTime TEXT,
              isCompleted INTEGER DEFAULT 0,
              exercises TEXT NOT NULL,
              FOREIGN KEY (routineId) REFERENCES Routines(id)
            )
          ''');
        },
      );
    } else {
      ByteData data = await rootBundle.load("database/data.db");
      List<int> bytes =
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      await File(path).writeAsBytes(bytes);
      
      return openDatabase(
        path,
        version: 2,
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 2) {
            await db.execute('''
              CREATE TABLE WorkoutSessions (
                id TEXT PRIMARY KEY,
                routineId INTEGER,
                startTime TEXT NOT NULL,
                endTime TEXT,
                isCompleted INTEGER DEFAULT 0,
                exercises TEXT NOT NULL,
                FOREIGN KEY (routineId) REFERENCES Routines(id)
              )
            ''');
          }
        },
      );
    }
  }

  // Existing routine methods
  @override
  Future<int> getLastId() async {
    final db = await database;
    var table = await db.rawQuery('SELECT MAX(Id)+1 as Id FROM Routines');
    int id = (table.first['Id'] as int?) ?? 1;
    return id;
  }

  @override
  Future<int> newRoutine(Routine routine) async {
    final db = await database;
    var table = await db.rawQuery('SELECT MAX(Id)+1 as Id FROM Routines');
    int id = (table.first['Id'] as int?) ?? 1;
    var map = routine.toMap();
    await db.rawInsert(
        'INSERT INTO Routines (Id, RoutineName, MainPart, Parts, LastCompletedDate, CreatedDate, Count, RoutineHistory, Weekdays) VALUES (?,?,?,?,?,?,?,?,?)',
        [
          id,
          map['routineName'],
          map['mainTargetedBodyPart'],
          jsonEncode(map['parts'] as List),
          map['lastCompletedDate'],
          map['createdDate'],
          map['completionCount'],
          map['routineHistory'],
          map['weekdays'],
        ]);
    return id;
  }

  @override
  Future<void> updateRoutine(Routine routine) async {
    final db = await database;
    await db.update(
      "Routines", 
      routine.toMap(),
      where: "id = ?", 
      whereArgs: [routine.id]
    );
  }

  @override
  Future<void> deleteRoutine(Routine routine) async {
    final db = await database;
    await db.delete(
      "Routines", 
      where: "id = ?", 
      whereArgs: [routine.id]
    );
  }

  @override
  Future<void> deleteAllRoutines() async {
    final db = await database;
    await db.delete("Routines");
  }

  @override
  Future<void> addAllRoutines(List<Routine> routines) async {
    final db = await database;
    for (var routine in routines) {
      await newRoutine(routine);
    }
  }

  @override
  Future<List<Routine>> getAllRoutines() async {
    final db = await database;
    List<Map<String, dynamic>> res = await db.query('Routines');
    return res.map((r) => Routine.fromMap(r)).toList();
  }

  @override
  Future<List<Routine>> getAllRecRoutines() async {
    final db = await database;
    List<Map<String, dynamic>> res = await db.query('RecommendedRoutines');
    return res.map((r) => Routine.fromMap(r)).toList();
  }

  // Workout session methods
  @override
  Future<void> saveWorkoutSession(WorkoutSession session) async {
    final db = await database;
    await db.insert(
      'WorkoutSessions',
      session.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<List<WorkoutSession>> getWorkoutSessions() async {
    final db = await database;
    final routines = await getAllRoutines();
    final sessions = await db.query('WorkoutSessions');
    
    return sessions.map((s) {
      final routine = routines.firstWhere(
        (r) => r.id == s['routineId'],
        orElse: () => Routine(
          routineName: 'Unknown',
          mainTargetedBodyPart: MainTargetedBodyPart.Chest,
          parts: [],
          createdDate: DateTime.now(),
        ),
      );
      return WorkoutSession.fromMap(s, routine);
    }).toList();
  }

  @override
  Future<WorkoutSession?> getWorkoutSessionById(String id) async {
    final db = await database;
    final session = await db.query(
      'WorkoutSessions',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (session.isEmpty) return null;
    
    final routines = await getAllRoutines();
    final routine = routines.firstWhere(
      (r) => r.id == session.first['routineId'],
      orElse: () => Routine(
        routineName: 'Unknown',
        mainTargetedBodyPart: MainTargetedBodyPart.Chest,
        parts: [],
        createdDate: DateTime.now(),
      ),
    );
    
    return WorkoutSession.fromMap(session.first, routine);
  }

  @override
  Future<void> deleteWorkoutSession(String id) async {
    final db = await database;
    await db.delete(
      'WorkoutSessions',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}