import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:workout_planner/models/routine.dart';
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
        version: 1,
        onOpen: (db) async {
          print(await db.query("sqlite_master"));
        },
      );
    } else {
      ByteData data = await rootBundle.load("database/data.db");
      List<int> bytes =
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      await File(path).writeAsBytes(bytes);
      return openDatabase(
        path,
        version: 1,
        onOpen: (db) async {
          print(await db.query("sqlite_master"));
        },
      );
    }
  }

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
          map['RoutineName'],
          map['MainPart'],
          map['Parts'],
          map['LastCompletedDate'],
          map['CreatedDate'],
          map['Count'],
          map['RoutineHistory'],
          map['Weekdays'],
        ]);
    return id;
  }

  @override
  Future<int> updateRoutine(Routine routine) async {
    final db = await database;
    int res = await db.update("Routines", routine.toMap(),
        where: "id = ?", whereArgs: [routine.id]);
    return res;
  }

  @override
  Future<int> deleteRoutine(Routine routine) async {
    final db = await database;
    int res = await db.delete("Routines", where: "id = ?", whereArgs: [routine.id]);
    return res;
  }

  @override
  Future<int> deleteAllRoutines() async {
    final db = await database;
    int res = await db.delete("Routines");
    return res;
  }

  @override
  Future<void> addAllRoutines(List<Routine> routines) async {
    final db = await database;
    for (var routine in routines) {
      var table = await db.rawQuery('SELECT MAX(Id)+1 as Id FROM Routines');
      int id = (table.first['Id'] as int?) ?? 1;
      var map = routine.toMap();
      await db.rawInsert(
          'INSERT INTO Routines (Id, RoutineName, MainPart, Parts, LastCompletedDate, CreatedDate, Count, RoutineHistory, Weekdays) VALUES (?,?,?,?,?,?,?,?,?)',
          [
            id,
            map['RoutineName'],
            map['MainPart'],
            map['Parts'],
            map['LastCompletedDate'],
            map['CreatedDate'],
            map['Count'],
            map['RoutineHistory'],
            map['Weekdays'],
          ]);
    }
  }

  @override
  Future<List<Routine>> getAllRoutines() async {
    final db = await database;
    List<Map<String, dynamic>> res = await db.query('Routines');
    List<Routine> routines = res.map((r) => Routine.fromMap(r)).toList();
    return res.isNotEmpty ? routines : [];
  }

  @override
  Future<List<Routine>> getAllRecRoutines() async {
    final db = await database;
    List<Map<String, dynamic>> res = await db.query('RecommendedRoutines');
    return res.isNotEmpty
        ? res.map((r) => Routine.fromMap(r)).toList()
        : [];
  }
}