import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

import 'message_model.dart';

/// A singleton helper class that manages the local SQLite database for
/// the disaster management chat application.
///
/// Uses the `sqflite` package to open, create, and operate on a persistent
/// database file named `offline_messages.db` in the device's default
/// database directory.
///
/// ## Usage
/// ```dart
/// final db = DatabaseHelper.instance;
/// await db.insertMessage(message);
/// final all = await db.getAllMessages();
/// ```
class DatabaseHelper {
  // ---------------------------------------------------------------------------
  // Singleton boilerplate
  // ---------------------------------------------------------------------------

  static const String _dbName    = 'offline_messages.db';
  static const int    _dbVersion = 1;
  static const String _tableName = 'messages';

  /// The single shared instance of [DatabaseHelper].
  static final DatabaseHelper instance = DatabaseHelper._internal();

  /// Private constructor — prevents external instantiation.
  DatabaseHelper._internal();

  /// The underlying [Database] object; lazily initialised on first access.
  Database? _db;

  // ---------------------------------------------------------------------------
  // Database access point
  // ---------------------------------------------------------------------------

  /// Returns the open [Database] instance, initialising it if necessary.
  Future<Database> get database async {
    _db ??= await _initDB();
    return _db!;
  }

  // ---------------------------------------------------------------------------
  // Initialisation
  // ---------------------------------------------------------------------------

  /// Opens (or creates) the SQLite database file on the device.
  Future<Database> _initDB() async {
    // Resolve the platform-specific default database directory.
    final dbPath = await getDatabasesPath();

    // Build the full absolute path, e.g. /data/user/0/<app>/databases/offline_messages.db
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
  /// Creates the `messages` table with columns matching every field of
  /// [MessageModel]. `message_id` is the PRIMARY KEY.
  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $_tableName (
        message_id  TEXT    PRIMARY KEY NOT NULL,
        sender_id   TEXT    NOT NULL,
        receiver_id TEXT    NOT NULL,
        type        TEXT    NOT NULL,
        priority    TEXT    NOT NULL,
        content     TEXT    NOT NULL,
        timestamp   TEXT    NOT NULL,
        ttl         INTEGER NOT NULL DEFAULT 0,
        status      TEXT    NOT NULL DEFAULT 'sent'
      )
    ''');
  }

  /// Called when [_dbVersion] is bumped in a future release.
  ///
  /// Extend this method with ALTER TABLE statements as the schema evolves.
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Reserved for future schema migrations.
    // Example:
    //   if (oldVersion < 2) {
    //     await db.execute('ALTER TABLE $_tableName ADD COLUMN read_at TEXT');
    //   }
  }

  // ---------------------------------------------------------------------------
  // CRUD operations
  // ---------------------------------------------------------------------------

  /// Inserts [message] into the database.
  ///
  /// If a row with the same `message_id` already exists, it is replaced
  /// entirely (`ConflictAlgorithm.replace`).
  ///
  /// Returns the row ID of the newly inserted row.
  Future<int> insertMessage(MessageModel message) async {
    final db = await database;
    return db.insert(
      _tableName,
      message.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Returns every message row in the table as a list of [MessageModel].
  ///
  /// Rows are ordered by [timestamp] ascending (oldest first).
  Future<List<MessageModel>> getAllMessages() async {
    final db   = await database;
    final rows = await db.query(_tableName, orderBy: 'timestamp ASC');
    return rows.map(MessageModel.fromMap).toList();
  }

  /// Returns the single [MessageModel] matching [messageId], or `null` if
  /// no such row exists.
  Future<MessageModel?> getMessageById(String messageId) async {
    final db   = await database;
    final rows = await db.query(
      _tableName,
      where:     'message_id = ?',
      whereArgs: [messageId],
      limit:     1,
    );
    if (rows.isEmpty) return null;
    return MessageModel.fromMap(rows.first);
  }

  /// Returns all messages whose [status] matches the given value.
  ///
  /// Example: `await db.getMessagesByStatus('pending')`
  Future<List<MessageModel>> getMessagesByStatus(String status) async {
    final db   = await database;
    final rows = await db.query(
      _tableName,
      where:     'status = ?',
      whereArgs: [status],
      orderBy:   'timestamp ASC',
    );
    return rows.map(MessageModel.fromMap).toList();
  }

  /// Updates the [status] field of the message identified by [messageId].
  ///
  /// Returns the number of rows affected (0 if no match was found).
  Future<int> updateMessageStatus(String messageId, String status) async {
    final db = await database;
    return db.update(
      _tableName,
      {'status': status},
      where:     'message_id = ?',
      whereArgs: [messageId],
    );
  }

  /// Deletes the message identified by [messageId].
  ///
  /// Returns the number of rows deleted (0 if no match was found).
  Future<int> deleteMessage(String messageId) async {
    final db = await database;
    return db.delete(
      _tableName,
      where:     'message_id = ?',
      whereArgs: [messageId],
    );
  }

  /// Deletes all messages whose TTL has expired relative to [nowEpochSeconds].
  ///
  /// A message is considered expired when:
  ///   `(unix_epoch_of_timestamp + ttl) < nowEpochSeconds`
  ///
  /// Returns the number of rows deleted.
  Future<int> deleteExpiredMessages(int nowEpochSeconds) async {
    final db = await database;
    // timestamp is stored as ISO 8601; use SQLite's strftime to convert.
    return db.rawDelete(
      '''
      DELETE FROM $_tableName
      WHERE (strftime('%s', timestamp) + ttl) < ?
      ''',
      [nowEpochSeconds],
    );
  }

  // ---------------------------------------------------------------------------
  // Housekeeping
  // ---------------------------------------------------------------------------

  /// Closes the underlying database connection.
  ///
  /// After calling this, the next call to [database] will re-open the file.
  Future<void> close() async {
    final db = _db;
    if (db != null && db.isOpen) {
      await db.close();
      _db = null;
    }
  }
}
