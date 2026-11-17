import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

const String _databaseName = 'dziennik_kierowcy.db';
const String _tableName = 'app_data';
const String _tripsKey = 'trips';

Database? _database;
Future<Database>? _databaseOpening;

/// Otwiera bazę SQLite lub tworzy ją, jeśli jeszcze nie istnieje.
Future<Database> _openDatabase() async {
  if (_database != null && _database!.isOpen) {
    return _database!;
  }

  // Zapobiega równoczesnemu otwieraniu kilku połączeń.
  if (_databaseOpening != null) {
    return _databaseOpening!;
  }

  final opening = _createDatabase();
  _databaseOpening = opening;

  try {
    final db = await opening;
    _database = db;
    return db;
  } catch (e) {
    debugPrint('SQLITE: Błąd otwierania bazy: $e');
    rethrow;
  } finally {
    _databaseOpening = null;
  }
}

/// Tworzy lub otwiera fizyczny plik bazy danych.
Future<Database> _createDatabase() async {
  final databasesPath = await getDatabasesPath();

  final dbPath = path.join(
    databasesPath,
    _databaseName,
  );

  debugPrint('================================');
  debugPrint('SQLITE: OTWIERANIE BAZY');
  debugPrint('SQLITE: Ścieżka: $dbPath');

  final db = await openDatabase(
    dbPath,
    version: 1,
    onCreate: (database, version) async {
      await database.execute('''
        CREATE TABLE $_tableName (
          key TEXT PRIMARY KEY,
          value TEXT NOT NULL
        )
      ''');

      debugPrint('SQLITE: Utworzono tabelę $_tableName');
    },
  );

  try {
    await _migrateLegacyData(db);

    debugPrint('SQLITE: Baza otwarta poprawnie');
    debugPrint('SQLITE: Wersja bazy: ${await db.getVersion()}');
    debugPrint('================================');

    return db;
  } catch (e) {
    await db.close();
    rethrow;
  }
}

/// Przenosi stare dane z SharedPreferences do SQLite.
/// Stare dane usuwa dopiero po udanym zapisie do bazy.
Future<void> _migrateLegacyData(Database db) async {
  final existing = await db.query(
    _tableName,
    columns: ['key'],
    where: 'key = ?',
    whereArgs: [_tripsKey],
    limit: 1,
  );

  if (existing.isNotEmpty) {
    debugPrint('SQLITE: Dane tras już istnieją. Pomijam migrację.');
    return;
  }

  final prefs = await SharedPreferences.getInstance();
  final oldJson = prefs.getString(_tripsKey);

  if (oldJson == null || oldJson.isEmpty) {
    debugPrint('SQLITE: Brak starych danych do migracji.');
    return;
  }

  final decoded = jsonDecode(oldJson);

  if (decoded is! List) {
    throw const FormatException(
      'Stary zapis tras ma nieprawidłowy format.',
    );
  }

  await db.insert(
    _tableName,
    {
      'key': _tripsKey,
      'value': oldJson,
    },
    conflictAlgorithm: ConflictAlgorithm.replace,
  );

  // Usunięcie starej kopii dopiero po zapisie do SQLite.
  await prefs.remove(_tripsKey);

  debugPrint('SQLITE: Migracja zakończona.');
  debugPrint('SQLITE: Przeniesiono tras: ${decoded.length}');
}

/// Odczytuje zapisane trasy bezpośrednio z SQLite.
Future<String?> loadTripsJson() async {
  final db = await _openDatabase();

  final rows = await db.query(
    _tableName,
    columns: ['value'],
    where: 'key = ?',
    whereArgs: [_tripsKey],
    limit: 1,
  );

  if (rows.isEmpty) {
    debugPrint('SQLITE: Nie znaleziono zapisanych tras.');
    return null;
  }

  final json = rows.first['value'] as String;
  final decoded = jsonDecode(json);

  if (decoded is! List) {
    throw const FormatException(
      'Dane tras zapisane w SQLite są nieprawidłowe.',
    );
  }

  debugPrint('SQLITE: ODCZYT ZAKOŃCZONY');
  debugPrint('SQLITE: Liczba tras: ${decoded.length}');

  return json;
}

/// Zapisuje wszystkie trasy jako jeden rekord JSON w SQLite.
Future<void> saveTripsJson(String json) async {
  final decoded = jsonDecode(json);

  if (decoded is! List) {
    throw const FormatException(
      'Nieprawidłowy format danych tras.',
    );
  }

  final db = await _openDatabase();

  await db.insert(
    _tableName,
    {
      'key': _tripsKey,
      'value': json,
    },
    conflictAlgorithm: ConflictAlgorithm.replace,
  );

  // Kontrolny odczyt bezpośrednio z bazy.
  final verification = await db.query(
    _tableName,
    columns: ['value'],
    where: 'key = ?',
    whereArgs: [_tripsKey],
    limit: 1,
  );

  if (verification.isEmpty || verification.first['value'] != json) {
    throw StateError(
      'SQLite nie potwierdziło poprawnego zapisu tras.',
    );
  }

  debugPrint('================================');
  debugPrint('SQLITE: ZAPIS ZAKOŃCZONY POPRAWNIE');
  debugPrint('SQLITE: Liczba zapisanych tras: ${decoded.length}');
  debugPrint('SQLITE: Weryfikacja zapisu: OK');
  debugPrint('================================');
}
