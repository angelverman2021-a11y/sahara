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
  static const int _dbVersion = 4;

  static const String _messagesTable = 'messages';
  static const String _seenMessagesTable = 'seen_messages';
  static const String _emergencyTable = 'emergency_reports';
  static const String _contactsTable = 'contacts';

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
        status           TEXT    NOT NULL DEFAULT 'PENDING',
        sender_name      TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE $_seenMessagesTable (
        message_id TEXT    PRIMARY KEY NOT NULL,
        seen_at    INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE $_emergencyTable (
        report_id   TEXT    PRIMARY KEY NOT NULL,
        sender_id   TEXT    NOT NULL,
        type        TEXT    NOT NULL,
        location    TEXT,
        priority    TEXT    NOT NULL,
        details     TEXT    NOT NULL,
        timestamp   INTEGER NOT NULL,
        status      TEXT    NOT NULL DEFAULT 'PENDING',
        sender_name TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE $_contactsTable (
        id                 TEXT    PRIMARY KEY NOT NULL,
        name               TEXT    NOT NULL,
        relation           TEXT    NOT NULL,
        status             TEXT    NOT NULL,
        hops               INTEGER NOT NULL DEFAULT 1,
        last_seen          TEXT    NOT NULL,
        location_available INTEGER NOT NULL DEFAULT 0,
        last_known_location TEXT   NOT NULL,
        coordinates        TEXT,
        phone_number       TEXT,
        user_id            TEXT,
        node_id            TEXT
      )
    ''');
  }

  /// Called when [_dbVersion] is bumped in a future release.
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS $_emergencyTable (
          report_id   TEXT    PRIMARY KEY NOT NULL,
          sender_id   TEXT    NOT NULL,
          type        TEXT    NOT NULL,
          location    TEXT,
          priority    TEXT    NOT NULL,
          details     TEXT    NOT NULL,
          timestamp   INTEGER NOT NULL,
          status      TEXT    NOT NULL DEFAULT 'PENDING'
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS $_contactsTable (
          id                 TEXT    PRIMARY KEY NOT NULL,
          name               TEXT    NOT NULL,
          relation           TEXT    NOT NULL,
          status             TEXT    NOT NULL,
          hops               INTEGER NOT NULL DEFAULT 1,
          last_seen          TEXT    NOT NULL,
          location_available INTEGER NOT NULL DEFAULT 0,
          last_known_location TEXT   NOT NULL,
          coordinates        TEXT,
          phone_number       TEXT,
          user_id            TEXT,
          node_id            TEXT
        )
      ''');
    }

    if (oldVersion < 3) {
      try {
        await db.execute('ALTER TABLE $_messagesTable ADD COLUMN sender_name TEXT');
      } catch (_) {}
    }

    if (oldVersion < 4) {
      try {
        await db.execute('ALTER TABLE $_emergencyTable ADD COLUMN sender_name TEXT');
      } catch (_) {}
    }
  }

  // ---------------------------------------------------------------------------
  // Message CRUD Operations (MessagePacket)
  // ---------------------------------------------------------------------------

  /// Inserts or replaces [message] in the database.
  ///
  /// Uses [MessagePacket.toJson] for strict 1:1 column mapping.
  /// Returns the row ID of the newly inserted or updated row.
  Future<int> insertMessage(MessagePacket message) async {
    try {
      final db = await database;
      final map = Map<String, dynamic>.from(message.toJson());
      return await db.insert(
        _messagesTable,
        map,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      // Defensive recovery: dynamically add column if missing on existing installations
      try {
        final db = await database;
        await db.execute('ALTER TABLE $_messagesTable ADD COLUMN sender_name TEXT');
        final map = Map<String, dynamic>.from(message.toJson());
        return await db.insert(
          _messagesTable,
          map,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      } catch (_) {
        // Last line of defense: strip sender_name to guarantee message row is saved
        try {
          final db = await database;
          final safeMap = Map<String, dynamic>.from(message.toJson())..remove('sender_name');
          return await db.insert(
            _messagesTable,
            safeMap,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        } catch (_) {
          return -1;
        }
      }
    }
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
  // Conversation & Peer Queries
  // ---------------------------------------------------------------------------

  /// Retrieves messages exchanged between this device and a given peer.
  Future<List<MessagePacket>> getConversationMessages(
    String peerId, {
    String? peerUserId,
  }) async {
    final db = await database;
    final String whereClause;
    final List<dynamic> whereArgs;

    if (peerUserId != null && peerUserId.isNotEmpty && peerUserId != peerId) {
      whereClause = '''
        (sender_node_id = ? OR receiver_node_id = ? OR sender_id = ? OR receiver_id = ?)
        OR (sender_node_id = ? OR receiver_node_id = ? OR sender_id = ? OR receiver_id = ?)
      ''';
      whereArgs = [
        peerId, peerId, peerId, peerId,
        peerUserId, peerUserId, peerUserId, peerUserId,
      ];
    } else {
      whereClause = '''
        sender_node_id = ? OR receiver_node_id = ? OR sender_id = ? OR receiver_id = ?
      ''';
      whereArgs = [peerId, peerId, peerId, peerId];
    }

    final rows = await db.query(
      _messagesTable,
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'timestamp ASC',
    );
    return rows.map((r) => MessagePacket.fromJson(r)).toList();
  }

  // ---------------------------------------------------------------------------
  // Emergency Reports CRUD
  // ---------------------------------------------------------------------------

  /// Inserts or replaces an emergency report in SQLite with defensive fallback.
  Future<int> insertEmergencyReport(Map<String, dynamic> report) async {
    try {
      final db = await database;
      return await db.insert(
        _emergencyTable,
        report,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      try {
        final db = await database;
        await db.execute('ALTER TABLE $_emergencyTable ADD COLUMN sender_name TEXT');
        return await db.insert(
          _emergencyTable,
          report,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      } catch (_) {
        try {
          final db = await database;
          final safeReport = Map<String, dynamic>.from(report)..remove('sender_name');
          return await db.insert(
            _emergencyTable,
            safeReport,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        } catch (_) {
          return -1;
        }
      }
    }
  }

  /// Returns up to [limit] most recent emergency broadcasts and SOS alerts stored locally.
  Future<List<MessagePacket>> getEmergencyBroadcastHistory({int limit = 50}) async {
    try {
      final db = await database;
      final rows = await db.query(
        _messagesTable,
        where: "type = 'BROADCAST' OR type = 'SOS'",
        orderBy: 'timestamp DESC',
        limit: limit,
      );
      return rows.map((r) => MessagePacket.fromJson(r)).toList();
    } catch (_) {
      return [];
    }
  }

  /// Returns all stored emergency reports, newest first.
  Future<List<Map<String, dynamic>>> getAllEmergencyReports() async {
    final db = await database;
    return db.query(_emergencyTable, orderBy: 'timestamp DESC');
  }

  /// Returns pending emergency reports that have not yet been synced to backend.
  Future<List<Map<String, dynamic>>> getPendingEmergencyReports() async {
    final db = await database;
    return db.query(
      _emergencyTable,
      where: 'status = ?',
      whereArgs: ['PENDING'],
      orderBy: 'timestamp ASC',
    );
  }

  /// Updates status of an emergency report (e.g. 'SYNCED').
  Future<int> updateEmergencyReportStatus(String reportId, String status) async {
    final db = await database;
    return db.update(
      _emergencyTable,
      {'status': status},
      where: 'report_id = ?',
      whereArgs: [reportId],
    );
  }

  // ---------------------------------------------------------------------------
  // Contacts CRUD
  // ---------------------------------------------------------------------------

  /// Inserts or updates a contact (family member or discovered peer).
  Future<int> insertOrUpdateContact(Map<String, dynamic> contact) async {
    final db = await database;
    return db.insert(
      _contactsTable,
      contact,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Retrieves all cached contacts.
  Future<List<Map<String, dynamic>>> getAllContacts() async {
    final db = await database;
    return db.query(_contactsTable, orderBy: 'name ASC');
  }

  /// Retrieves all family contacts.
  Future<List<Map<String, dynamic>>> getFamilyContacts() async {
    final db = await database;
    return db.query(
      _contactsTable,
      where: 'relation = ?',
      whereArgs: ['family'],
      orderBy: 'name ASC',
    );
  }

  /// Deletes a contact by ID.
  Future<int> deleteContact(String id) async {
    final db = await database;
    return db.delete(
      _contactsTable,
      where: 'id = ?',
      whereArgs: [id],
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
