import 'dart:async';
import '../database/database_helper.dart';
import '../models/message_model.dart';
import 'backend_client.dart';

class SyncResult {
  final bool success;
  final int messagesSynced;
  final int reportsSynced;
  final String? errorMessage;

  const SyncResult({
    required this.success,
    this.messagesSynced = 0,
    this.reportsSynced = 0,
    this.errorMessage,
  });
}

/// Orchestrates synchronization between local SQLite storage and the SAHARA Python backend.
class BackendSyncService {
  final BackendClient client;
  final DatabaseHelper db;

  bool _isSyncing = false;
  DateTime? _lastSynced;
  bool _isServerReachable = false;

  bool get isSyncing => _isSyncing;
  DateTime? get lastSynced => _lastSynced;
  bool get isServerReachable => _isServerReachable;

  BackendSyncService({
    required this.client,
    DatabaseHelper? db,
  }) : db = db ?? DatabaseHelper.instance;

  /// Tests connectivity to backend server
  Future<bool> checkConnectivity() async {
    _isServerReachable = await client.checkHealth();
    return _isServerReachable;
  }

  /// Performs full bidirectional synchronization with backend.
  Future<SyncResult> syncAll({required String myUserId}) async {
    if (_isSyncing) {
      return const SyncResult(success: false, errorMessage: 'Sync already in progress');
    }

    _isSyncing = true;
    try {
      final isHealthy = await checkConnectivity();
      if (!isHealthy) {
        _isSyncing = false;
        return const SyncResult(
          success: false,
          errorMessage: 'Backend server unreachable. Offline mesh remains active.',
        );
      }

      int totalMessagesSynced = 0;
      int totalReportsSynced = 0;

      // 1. Upload Pending Local Messages
      final pendingMessages = await db.getMessagesByStatus('PENDING');
      if (pendingMessages.isNotEmpty) {
        final payload = pendingMessages.map((m) {
          // Normalize type for backend validation
          var type = m.type.toUpperCase();
          if (type == 'TEXT') {
            type = 'TEXT';
          }
          return {
            'message_id': m.messageId,
            'sender_id': m.senderId,
            'receiver_id': m.receiverId,
            'type': type,
            'priority': m.priority,
            'content': m.content,
            'ttl': m.ttl,
            'status': 'SYNCED',
            'timestamp': (m.timestamp ~/ 1000), // Backend expects seconds
          };
        }).toList();

        final syncResponse = await client.syncMessages(payload);
        if (syncResponse != null) {
          for (final msg in pendingMessages) {
            await db.updateMessageStatus(msg.messageId, 'SYNCED');
          }
          totalMessagesSynced += (syncResponse['synced'] as num?)?.toInt() ?? 0;
        }
      }

      // 2. Upload Pending Emergency Reports
      final pendingReports = await db.getPendingEmergencyReports();
      if (pendingReports.isNotEmpty) {
        final payload = pendingReports.map((r) => {
          'report_id': r['report_id'],
          'sender_id': r['sender_id'],
          'type': r['type'],
          'location': r['location'],
          'priority': r['priority'],
          'details': r['details'],
          'timestamp': ((r['timestamp'] as int? ?? 0) ~/ 1000),
        }).toList();

        final syncResponse = await client.syncEmergencyReports(payload);
        if (syncResponse != null) {
          for (final rpt in pendingReports) {
            final id = rpt['report_id'] as String;
            await db.updateEmergencyReportStatus(id, 'SYNCED');
          }
          totalReportsSynced += (syncResponse['synced'] as num?)?.toInt() ?? 0;
        }
      }

      // 3. Download Synced Messages for this user from backend
      if (myUserId.isNotEmpty) {
        final remoteMessages = await client.getSyncedMessages(myUserId);
        for (final item in remoteMessages) {
          final messageId = item['message_id'] as String? ?? '';
          if (messageId.isEmpty) continue;

          final exists = await db.getMessageById(messageId);
          if (exists == null) {
            final packet = MessagePacket(
              messageId: messageId,
              senderId: item['sender_id'] as String? ?? '',
              receiverId: item['receiver_id'] as String? ?? myUserId,
              senderNodeId: item['sender_id'] as String? ?? '',
              receiverNodeId: item['receiver_id'] as String? ?? myUserId,
              type: item['type'] as String? ?? MessageType.text,
              priority: item['priority'] as String? ?? MessagePriority.normal,
              content: item['content'] as String? ?? '',
              timestamp: ((item['timestamp'] as num?)?.toInt() ?? 0) * 1000,
              ttl: (item['ttl'] as num?)?.toInt() ?? 8,
              status: MessageStatus.synced,
            );
            await db.insertMessage(packet);
            await db.markMessageSeen(messageId);
          }
        }
      }

      // 4. Download Priority Emergency Reports Feed
      final remoteReports = await client.getEmergencyFeed();
      for (final rpt in remoteReports) {
        final reportId = rpt['report_id'] as String? ?? '';
        if (reportId.isNotEmpty) {
          await db.insertEmergencyReport({
            'report_id': reportId,
            'sender_id': rpt['sender_id'] ?? '',
            'type': rpt['type'] ?? 'EMERGENCY',
            'location': rpt['location'],
            'priority': rpt['priority'] ?? 'Normal',
            'details': rpt['details'] ?? '',
            'timestamp': ((rpt['timestamp'] as num?)?.toInt() ?? 0) * 1000,
            'status': 'SYNCED',
          });
        }
      }

      _lastSynced = DateTime.now();
      _isSyncing = false;
      return SyncResult(
        success: true,
        messagesSynced: totalMessagesSynced,
        reportsSynced: totalReportsSynced,
      );
    } catch (e) {
      _isSyncing = false;
      return SyncResult(
        success: false,
        errorMessage: 'Sync error: $e',
      );
    }
  }
}
