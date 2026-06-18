import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

class LocalSymptomRepository {
  static const _uuid = Uuid();
  static const _entriesKey = 'mar_local_entries';
  static const _medicationsKey = 'mar_local_medications';
  static const _appointmentsKey = 'mar_local_appointments';
  static const _lastSyncedAtKey = 'mar_last_synced_at';

  @visibleForTesting
  static bool useWebStorageForTesting = false;

  Database? _database;

  bool get _usesPrefsStorage => kIsWeb || useWebStorageForTesting;

  Future<void> init() async {
    if (_usesPrefsStorage) {
      await SharedPreferences.getInstance();
      return;
    }
    await database;
  }

  Future<Database> get database async {
    _database ??= await _initDB();
    return _database!;
  }

  Future<Database> _initDB() async {
    final path = p.join(await getDatabasesPath(), 'symptom_tracker.db');
    return openDatabase(
      path,
      version: 3,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE entries (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            client_id TEXT NOT NULL,
            remote_id TEXT,
            pain_level INTEGER,
            body_area TEXT,
            mood TEXT,
            notes TEXT,
            symptoms_json TEXT,
            custom_symptoms TEXT,
            temperature_celsius REAL,
            photo_path TEXT,
            photo_bytes_base64 TEXT,
            timestamp TEXT,
            updated_at TEXT,
            deleted_at TEXT,
            sync_status TEXT NOT NULL DEFAULT 'pending'
          )
        ''');
        await db.execute('''
          CREATE TABLE medications (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            client_id TEXT NOT NULL,
            remote_id TEXT,
            name TEXT,
            dosage TEXT,
            frequency TEXT,
            is_active INTEGER,
            updated_at TEXT,
            deleted_at TEXT,
            sync_status TEXT NOT NULL DEFAULT 'pending'
          )
        ''');
        await db.execute('''
          CREATE TABLE appointments (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            client_id TEXT NOT NULL,
            remote_id TEXT,
            title TEXT,
            doctor TEXT,
            date TEXT,
            time TEXT,
            notes TEXT,
            updated_at TEXT,
            deleted_at TEXT,
            sync_status TEXT NOT NULL DEFAULT 'pending'
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await _addSyncColumns(db, 'entries');
          await _addSyncColumns(db, 'medications');
          await _addSyncColumns(db, 'appointments');
          await _backfillClientIds(db, 'entries');
          await _backfillClientIds(db, 'medications');
          await _backfillClientIds(db, 'appointments');
        }
        if (oldVersion < 3) {
          await _addEntryHealthColumns(db);
        }
      },
    );
  }

  Future<void> _addEntryHealthColumns(Database db) async {
    final existing = await db.rawQuery('PRAGMA table_info(entries)');
    final names = existing.map((row) => row['name'] as String).toSet();

    Future<void> add(String column, String definition) async {
      if (!names.contains(column)) {
        await db.execute('ALTER TABLE entries ADD COLUMN $column $definition');
      }
    }

    await add('symptoms_json', 'TEXT');
    await add('custom_symptoms', 'TEXT');
    await add('temperature_celsius', 'REAL');
  }

  Future<void> _addSyncColumns(Database db, String table) async {
    final existing = await db.rawQuery('PRAGMA table_info($table)');
    final names = existing.map((row) => row['name'] as String).toSet();

    Future<void> add(String column, String definition) async {
      if (!names.contains(column)) {
        await db.execute('ALTER TABLE $table ADD COLUMN $column $definition');
      }
    }

    await add('client_id', 'TEXT');
    await add('remote_id', 'TEXT');
    if (table == 'entries') {
      await add('photo_bytes_base64', 'TEXT');
    }
    await add('updated_at', 'TEXT');
    await add('deleted_at', 'TEXT');
    await add('sync_status', "TEXT NOT NULL DEFAULT 'pending'");
  }

  Future<void> _backfillClientIds(Database db, String table) async {
    final rows = await db.query(
      table,
      columns: ['id', 'client_id', 'updated_at'],
      where: 'client_id IS NULL OR client_id = ? OR updated_at IS NULL',
      whereArgs: [''],
    );
    final now = DateTime.now().toUtc().toIso8601String();
    for (final row in rows) {
      await db.update(
        table,
        {
          if ((row['client_id'] as String?)?.isNotEmpty != true)
            'client_id': _uuid.v4(),
          if (row['updated_at'] == null) 'updated_at': now,
          'sync_status': 'pending',
        },
        where: 'id = ?',
        whereArgs: [row['id']],
      );
    }
  }

  Future<int> insertEntry(Map<String, dynamic> entry) async {
    return _insert('entries', entry);
  }

  Future<List<Map<String, dynamic>>> getEntries() async {
    return _getActive('entries', orderBy: 'timestamp DESC');
  }

  Future<int> deleteEntry(int id) async {
    return _softDelete('entries', id);
  }

  Future<int> insertMedication(Map<String, dynamic> medication) async {
    return _insert('medications', medication);
  }

  Future<List<Map<String, dynamic>>> getMedications() async {
    return _getActive('medications');
  }

  Future<int> updateMedication(int id, Map<String, dynamic> medication) async {
    return _update('medications', id, medication);
  }

  Future<int> deleteMedication(int id) async {
    return _softDelete('medications', id);
  }

  Future<int> insertAppointment(Map<String, dynamic> appointment) async {
    return _insert('appointments', appointment);
  }

  Future<List<Map<String, dynamic>>> getAppointments() async {
    return _getActive('appointments', orderBy: 'date ASC');
  }

  Future<int> deleteAppointment(int id) async {
    return _softDelete('appointments', id);
  }

  Future<List<Map<String, dynamic>>> getPending(String table) async {
    if (_usesPrefsStorage) {
      final rows = await _readWebRows(table);
      return rows.where((row) => row['sync_status'] == 'pending').toList();
    }

    final db = await database;
    return db.query(table, where: 'sync_status = ?', whereArgs: ['pending']);
  }

  Future<void> markSynced(String table, int localId, String remoteId) async {
    await _updateRaw(table, localId, {
      'remote_id': remoteId,
      'sync_status': 'synced',
    });
  }

  Future<void> markPending(String table, int localId) async {
    await _updateRaw(table, localId, {'sync_status': 'pending'});
  }

  Future<void> upsertRemoteEntry(Map<String, dynamic> remote) async {
    await _upsertRemote('entries', remote, {
      'remote_id': remote['id'],
      'client_id': remote['client_id'],
      'pain_level': remote['pain_level'],
      'body_area': remote['body_area'],
      'mood': remote['mood'],
      'notes': remote['notes'],
      'symptoms_json': jsonEncode(remote['symptoms'] ?? const []),
      'custom_symptoms': remote['custom_symptoms'],
      'temperature_celsius': remote['temperature_celsius'],
      'photo_path': remote['photo_path'],
      'photo_bytes_base64': null,
      'timestamp': remote['occurred_at'],
      'updated_at': remote['updated_at'],
      'deleted_at': remote['deleted_at'],
      'sync_status': 'synced',
    });
  }

  Future<void> upsertRemoteMedication(Map<String, dynamic> remote) async {
    await _upsertRemote('medications', remote, {
      'remote_id': remote['id'],
      'client_id': remote['client_id'],
      'name': remote['name'],
      'dosage': remote['dosage'],
      'frequency': remote['frequency'],
      'is_active': remote['is_active'] == true ? 1 : 0,
      'updated_at': remote['updated_at'],
      'deleted_at': remote['deleted_at'],
      'sync_status': 'synced',
    });
  }

  Future<void> upsertRemoteAppointment(Map<String, dynamic> remote) async {
    await _upsertRemote('appointments', remote, {
      'remote_id': remote['id'],
      'client_id': remote['client_id'],
      'title': remote['title'],
      'doctor': remote['doctor'],
      'date': remote['appointment_date'],
      'time': remote['appointment_time'],
      'notes': remote['notes'],
      'updated_at': remote['updated_at'],
      'deleted_at': remote['deleted_at'],
      'sync_status': 'synced',
    });
  }

  Future<String?> getLastSyncedAt() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_lastSyncedAtKey);
  }

  Future<void> setLastSyncedAt(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastSyncedAtKey, value);
  }

  Future<int> _insert(String table, Map<String, dynamic> row) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final value = <String, dynamic>{
      ...row,
      'client_id': row['client_id'] ?? _uuid.v4(),
      'updated_at': row['updated_at'] ?? now,
      'deleted_at': row['deleted_at'],
      'sync_status': 'pending',
    };

    if (_usesPrefsStorage) {
      final rows = await _readWebRows(table);
      final nextId = _nextWebId(rows);
      rows.add({...value, 'id': nextId});
      await _writeWebRows(table, rows);
      return nextId;
    }

    final db = await database;
    return db.insert(table, value);
  }

  Future<int> _update(String table, int id, Map<String, dynamic> row) async {
    return _updateRaw(table, id, {
      ...row,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
      'sync_status': 'pending',
    });
  }

  Future<int> _softDelete(String table, int id) async {
    final now = DateTime.now().toUtc().toIso8601String();
    return _updateRaw(table, id, {
      'deleted_at': now,
      'updated_at': now,
      'sync_status': 'pending',
    });
  }

  Future<int> _updateRaw(String table, int id, Map<String, dynamic> row) async {
    if (_usesPrefsStorage) {
      final rows = await _readWebRows(table);
      final index = rows.indexWhere((item) => item['id'] == id);
      if (index == -1) return 0;
      rows[index] = {...rows[index], ...row};
      await _writeWebRows(table, rows);
      return 1;
    }

    final db = await database;
    return db.update(table, row, where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Map<String, dynamic>>> _getActive(
    String table, {
    String? orderBy,
  }) async {
    if (_usesPrefsStorage) {
      final rows = await _readWebRows(table);
      final active = rows.where((row) => row['deleted_at'] == null).toList();
      if (orderBy == 'timestamp DESC') {
        active.sort((a, b) => (b['timestamp'] ?? '')
            .toString()
            .compareTo((a['timestamp'] ?? '').toString()));
      } else if (orderBy == 'date ASC') {
        active.sort((a, b) => (a['date'] ?? '')
            .toString()
            .compareTo((b['date'] ?? '').toString()));
      }
      return active;
    }

    final db = await database;
    return db.query(
      table,
      where: 'deleted_at IS NULL',
      orderBy: orderBy,
    );
  }

  Future<void> _upsertRemote(
    String table,
    Map<String, dynamic> remote,
    Map<String, dynamic> local,
  ) async {
    final clientId = remote['client_id'];
    if (clientId == null) return;

    if (_usesPrefsStorage) {
      final rows = await _readWebRows(table);
      final index = rows.indexWhere((row) => row['client_id'] == clientId);
      if (index == -1) {
        rows.add({...local, 'id': _nextWebId(rows)});
      } else if (_remoteWins(rows[index], local)) {
        rows[index] = {...rows[index], ...local};
      }
      await _writeWebRows(table, rows);
      return;
    }

    final db = await database;
    final existing = await db.query(
      table,
      where: 'client_id = ?',
      whereArgs: [clientId],
      limit: 1,
    );
    if (existing.isEmpty) {
      await db.insert(table, local);
    } else if (_remoteWins(existing.first, local)) {
      await db
          .update(table, local, where: 'client_id = ?', whereArgs: [clientId]);
    }
  }

  bool _remoteWins(Map<String, dynamic> local, Map<String, dynamic> remote) {
    final localUpdated =
        DateTime.tryParse((local['updated_at'] ?? '').toString());
    final remoteUpdated =
        DateTime.tryParse((remote['updated_at'] ?? '').toString());
    if (local['sync_status'] == 'pending') return false;
    if (localUpdated == null || remoteUpdated == null) return true;
    return remoteUpdated.isAfter(localUpdated);
  }

  Future<List<Map<String, dynamic>>> _readWebRows(String table) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_webKey(table));
    if (raw == null || raw.isEmpty) return [];
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  Future<void> _writeWebRows(
      String table, List<Map<String, dynamic>> rows) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_webKey(table), jsonEncode(rows));
  }

  String _webKey(String table) {
    switch (table) {
      case 'entries':
        return _entriesKey;
      case 'medications':
        return _medicationsKey;
      case 'appointments':
        return _appointmentsKey;
      default:
        throw ArgumentError('Unknown table: $table');
    }
  }

  int _nextWebId(List<Map<String, dynamic>> rows) {
    if (rows.isEmpty) return 1;
    return rows
            .map((row) => row['id'])
            .whereType<int>()
            .fold<int>(0, (max, id) => id > max ? id : max) +
        1;
  }
}
