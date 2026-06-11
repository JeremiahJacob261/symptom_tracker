import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import '../models/symptom_entry.dart';
import '../models/medication_entry.dart';
import '../models/appointment_entry.dart';
import '../models/chat_message.dart';

class SymptomStorage {
  static Database? _database;

  static Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  static Future<Database> _initDB() async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final path = join(documentsDirectory.path, 'symptom_tracker.db');

    return await openDatabase(
      path,
      version: 2,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  static Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE symptoms(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL,
        painLevel INTEGER NOT NULL,
        mood TEXT NOT NULL,
        bodyArea TEXT NOT NULL,
        notes TEXT NOT NULL,
        symptoms TEXT,
        imagePath TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE medications(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        dosage TEXT NOT NULL,
        frequency TEXT NOT NULL,
        time TEXT NOT NULL,
        isActive INTEGER NOT NULL DEFAULT 1,
        startDate TEXT NOT NULL,
        endDate TEXT,
        notes TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE appointments(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        doctorName TEXT NOT NULL,
        specialty TEXT NOT NULL,
        dateTime TEXT NOT NULL,
        location TEXT NOT NULL,
        notes TEXT,
        isCompleted INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE chat_messages(
        id TEXT PRIMARY KEY,
        text TEXT NOT NULL,
        isUser INTEGER NOT NULL,
        timestamp TEXT NOT NULL,
        analysisType TEXT
      )
    ''');
  }

  static Future<void> _upgradeDB(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE symptoms ADD COLUMN symptoms TEXT');
      await db.execute('ALTER TABLE symptoms ADD COLUMN imagePath TEXT');
    }
  }

  static Future<void> init() async {
    await database;
  }

  static Future<int> addEntry(SymptomEntry entry) async {
    final db = await database;
    return await db.insert('symptoms', entry.toMap());
  }

  static Future<List<SymptomEntry>> getEntries() async {
    final db = await database;
    final maps = await db.query('symptoms', orderBy: 'date DESC');
    return maps.map((map) => SymptomEntry.fromMap(map)).toList();
  }

  static Future<List<SymptomEntry>> searchEntries(String query) async {
    final db = await database;
    final maps = await db.query(
      'symptoms',
      where: 'notes LIKE ? OR bodyArea LIKE ? OR mood LIKE ?',
      whereArgs: ['%\$query%', '%\$query%', '%\$query%'],
      orderBy: 'date DESC',
    );
    return maps.map((map) => SymptomEntry.fromMap(map)).toList();
  }

  static Future<void> clearAll() async {
    final db = await database;
    await db.delete('symptoms');
    await db.delete('medications');
    await db.delete('appointments');
    await db.delete('chat_messages');
  }

  static Future<int> addMedication(MedicationEntry medication) async {
    final db = await database;
    return await db.insert('medications', medication.toMap());
  }

  static Future<List<MedicationEntry>> getMedications() async {
    final db = await database;
    final maps = await db.query('medications', orderBy: 'startDate DESC');
    return maps.map((map) => MedicationEntry.fromMap(map)).toList();
  }

  static Future<void> updateMedicationStatus(int id, bool isActive) async {
    final db = await database;
    await db.update(
      'medications',
      {'isActive': isActive ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  static Future<void> deleteMedication(int id) async {
    final db = await database;
    await db.delete('medications', where: 'id = ?', whereArgs: [id]);
  }

  static Future<int> addAppointment(AppointmentEntry appointment) async {
    final db = await database;
    return await db.insert('appointments', appointment.toMap());
  }

  static Future<List<AppointmentEntry>> getAppointments() async {
    final db = await database;
    final maps = await db.query('appointments', orderBy: 'dateTime ASC');
    return maps.map((map) => AppointmentEntry.fromMap(map)).toList();
  }

  static Future<void> updateAppointmentStatus(int id, bool isCompleted) async {
    final db = await database;
    await db.update(
      'appointments',
      {'isCompleted': isCompleted ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  static Future<void> deleteAppointment(int id) async {
    final db = await database;
    await db.delete('appointments', where: 'id = ?', whereArgs: [id]);
  }

  static Future<int> addChatMessage(ChatMessage message) async {
    final db = await database;
    return await db.insert('chat_messages', message.toMap());
  }

  static Future<List<ChatMessage>> getChatMessages() async {
    final db = await database;
    final maps = await db.query('chat_messages', orderBy: 'timestamp ASC');
    return maps.map((map) => ChatMessage.fromMap(map)).toList();
  }

  static Future<void> clearChatMessages() async {
    final db = await database;
    await db.delete('chat_messages');
  }
}
