import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

import '../models/message_model.dart';

/// A singleton helper class that manages the local SQLite database for SAHARA.
///
/// Stores [MessagePacket] instances natively with physical mesh routing IDs,
/// hop-count TTL, epoch millisecond timestamps, and persistent crash-safe
/// deduplication state via the `seen_messages` table.
///
/// ## Usage
/// ```dart
/// final db = DatabaseHelper.instance;
/// await db.insertMessage(messagePacket);
/// final all = await db.getAllMessages();
/// final hasSeen = await db.hasSeenMessage(messagePacket.messageId);
/// ```
class DatabaseHelper {
  // ---------------------------------------------------------------------------
  // Database Configuration & Tables
  // ---------------------------------------------------------------------------

  static const String _dbName = 'offline_messages.db';
  static const int _dbVersion = 1;

  static const String _messagesTable = 'messages';
  static const String _seenMessagesTable = 'seen_messages';

  /// The single shared instance of [DatabaseHelper].
  static final DatabaseHelper instance = DatabaseHelper._internal();

  /// Private constructor — prevents external instantiation.
  DatabaseHelper._internal();

  /// The underlying [Database] object; lazily initialised on first access.
  Database? _db;

  // ---------------------------------------------------------------------------
  // Database Access Point
  // ---------------------------------------------------------------------------

  /// Returns the open [Database] instance, initialising it if necessary.
  Future<Database> get database async {
    _db ??= await _initDB();
    return _db!;
  }

  // ---------------------------------------------------------------------------
  // Initialisation & Schema Setup
  // ---------------------------------------------------------------------------

  /// Opens (or creates) the SQLite database file on the device.
  Future<Database> _initDB() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbName);

    return openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  /// Called the first time the database file is created.
  ///
  /// Sets up:
  /// 1. `messages`: Stores [MessagePacket] with physical node IDs and hop-count TTL.
  /// 2. `seen_messages`: Stores seen message IDs for persistent deduplication.
  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $_messagesTable (
        message_id       TEXT    PRIMARY KEY NOT NULL,
        sender_id        TEXT    NOT NULL,
        receiver_id      TEXT    NOT NULL,
        sender_node_id   TEXT    NOT NULL,
        receiver_node_id TEXT    NOT NULL,
        type             TEXT    NOT NULL,
        priority         TEXT    NOT NULL,
        content          TEXT    NOT NULL,
        timestamp        INTEGER NOT NULL,
        ttl              INTEGER NOT NULL,
        status           TEXT    NOT NULL DEFAULT 'PENDING'
      )
    ''');

    await db.execute('''
      CREATE TABLE $_seenMessagesTable (
        message_id TEXT    PRIMARY KEY NOT NULL,
        seen_at    INTEGER NOT NULL
      )
    ''');
  }

  /// Called when [_dbVersion] is bumped in a future release.
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Reserved for future schema migrations.
  }

  // ---------------------------------------------------------------------------
  // Message CRUD Operations (MessagePacket)
  // ---------------------------------------------------------------------------

  /// Inserts or replaces [message] in the database.
  ///
  /// Uses [MessagePacket.toJson] for strict 1:1 column mapping.
  /// Returns the row ID of the newly inserted or updated row.
  Future<int> insertMessage(MessagePacket message) async {
    final db = await database;
    return db.insert(
      _messagesTable,
      message.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Returns every message row in the table as a list of [MessagePacket].
  ///
  /// Rows are ordered by [timestamp] ascending (oldest first).
  Future<List<MessagePacket>> getAllMessages() async {
    final db = await database;
    final rows = await db.query(_messagesTable, orderBy: 'timestamp ASC');
    return rows.map((row) => MessagePacket.fromJson(row)).toList();
  }

  /// Returns the single [MessagePacket] matching [messageId], or `null` if none found.
  Future<MessagePacket?> getMessageById(String messageId) async {
    final db = await database;
    final rows = await db.query(
      _messagesTable,
      where: 'message_id = ?',
      whereArgs: [messageId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return MessagePacket.fromJson(rows.first);
  }

  /// Returns all messages whose [status] matches the given value (e.g. 'PENDING', 'DELIVERED').
  Future<List<MessagePacket>> getMessagesByStatus(String status) async {
    final db = await database;
    final rows = await db.query(
      _messagesTable,
      where: 'status = ?',
      whereArgs: [status],
      orderBy: 'timestamp ASC',
    );
    return rows.map((row) => MessagePacket.fromJson(row)).toList();
  }

  /// Updates the [status] field of the message identified by [messageId].
  ///
  /// Returns the number of rows affected.
  Future<int> updateMessageStatus(String messageId, String status) async {
    final db = await database;
    return db.update(
      _messagesTable,
      {'status': status},
      where: 'message_id = ?',
      whereArgs: [messageId],
    );
  }

  /// Deletes the message identified by [messageId].
  ///
  /// Returns the number of rows deleted.
  Future<int> deleteMessage(String messageId) async {
    final db = await database;
    return db.delete(
      _messagesTable,
      where: 'message_id = ?',
      whereArgs: [messageId],
    );
  }

  // ---------------------------------------------------------------------------
  // Persistent Deduplication Storage (seen_messages)
  // ---------------------------------------------------------------------------

  /// Marks a [messageId] as seen in SQLite for crash-safe deduplication.
  Future<void> markMessageSeen(String messageId, [int? seenAt]) async {
    final db = await database;
    final timestamp = seenAt ?? DateTime.now().millisecondsSinceEpoch;
    await db.insert(
      _seenMessagesTable,
      {
        'message_id': messageId,
        'seen_at': timestamp,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Checks if [messageId] has already been seen.
  Future<bool> hasSeenMessage(String messageId) async {
    final db = await database;
    final rows = await db.query(
      _seenMessagesTable,
      columns: ['message_id'],
      where: 'message_id = ?',
      whereArgs: [messageId],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  /// Removes a [messageId] from the seen cache table.
  ///
  /// Returns the number of rows deleted.
  Future<int> removeSeenMessage(String messageId) async {
    final db = await database;
    return db.delete(
      _seenMessagesTable,
      where: 'message_id = ?',
      whereArgs: [messageId],
    );
  }

  /// Returns all persisted seen message IDs.
  Future<List<String>> getAllSeenMessageIds() async {
    final db = await database;
    final rows = await db.query(_seenMessagesTable, columns: ['message_id']);
    return rows.map((r) => r['message_id'] as String).toList();
  }

  /// Clears seen message entries older than [olderThanEpochMs] to manage storage.
  Future<int> clearOldSeenMessages(int olderThanEpochMs) async {
    final db = await database;
    return db.delete(
      _seenMessagesTable,
      where: 'seen_at < ?',
      whereArgs: [olderThanEpochMs],
    );
  }

  // ---------------------------------------------------------------------------
  // Housekeeping
  // ---------------------------------------------------------------------------

  /// Closes the underlying database connection.
  Future<void> close() async {
    final db = _db;
    if (db != null && db.isOpen) {
      await db.close();
      _db = null;
    }
  }
}
