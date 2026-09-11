// SAHARA — Message Model & Packet Specification
// Standard library only (dart:convert).
// Strictly separates human User ID (sender_id, receiver_id) from physical device Mesh Node ID (senderNodeId, receiverNodeId).

import 'dart:convert';

/// Supported message types across the SAHARA system
class MessageType {
  static const String text = 'TEXT';
  static const String sos = 'SOS';
  static const String broadcast = 'BROADCAST';

  static const Set<String> all = {text, sos, broadcast};

  static bool isValid(String type) => all.contains(type);
}

/// Priority levels for battery-aware prioritization
class MessagePriority {
  static const String highest = 'Highest';
  static const String high = 'High';
  static const String normal = 'Normal';

  static const Set<String> all = {highest, high, normal};

  static bool isValid(String priority) => all.contains(priority);
}

/// Message synchronization and delivery status
class MessageStatus {
  static const String pending = 'PENDING';
  static const String synced = 'SYNCED';
  static const String delivered = 'DELIVERED';

  static const Set<String> all = {pending, synced, delivered};

  static bool isValid(String status) => all.contains(status);
}

/// The core packet transferred across the multi-hop mesh and stored in SQLite.
class MessagePacket {
  /// Unique identifier for deduplication and delivery tracking
  final String messageId;

  /// SAHARA User ID of the human sender (e.g., "SH-ZJHD")
  final String senderId;

  /// SAHARA User ID of the human recipient, or "BROADCAST"
  final String receiverId;

  /// Physical mesh node ID of the originating device (e.g., "NODE_A01")
  final String senderNodeId;

  /// Physical mesh node ID of the destination device, or "BROADCAST"
  final String receiverNodeId;

  /// Message type: 'TEXT', 'SOS', or 'BROADCAST'
  final String type;

  /// Priority: 'Highest', 'High', or 'Normal'
  final String priority;

  /// Text payload (maximum 2048 characters)
  final String content;

  /// Creation epoch timestamp in milliseconds
  final int timestamp;

  /// Time-To-Live hop counter (decremented on each relay hop)
  final int ttl;

  /// Delivery/sync status: 'PENDING', 'SYNCED', 'DELIVERED'
  final String status;

  const MessagePacket({
    required this.messageId,
    required this.senderId,
    required this.receiverId,
    required this.senderNodeId,
    required this.receiverNodeId,
    required this.type,
    required this.priority,
    required this.content,
    required this.timestamp,
    required this.ttl,
    this.status = MessageStatus.pending,
  });

  /// Maximum allowed payload characters (2 KB constraint)
  static const int maxContentLength = 2048;

  /// Creates a copy of this packet with TTL decremented by 1 for multi-hop relay.
  MessagePacket copyWithDecrementedTtl() {
    return MessagePacket(
      messageId: messageId,
      senderId: senderId,
      receiverId: receiverId,
      senderNodeId: senderNodeId,
      receiverNodeId: receiverNodeId,
      type: type,
      priority: priority,
      content: content,
      timestamp: timestamp,
      ttl: ttl - 1,
      status: status,
    );
  }

  /// Copies packet with an updated status (e.g., DELIVERED, SYNCED).
  MessagePacket copyWith({
    String? status,
    int? ttl,
  }) {
    return MessagePacket(
      messageId: messageId,
      senderId: senderId,
      receiverId: receiverId,
      senderNodeId: senderNodeId,
      receiverNodeId: receiverNodeId,
      type: type,
      priority: priority,
      content: content,
      timestamp: timestamp,
      ttl: ttl ?? this.ttl,
      status: status ?? this.status,
    );
  }

  /// Serializes packet to JSON map for over-the-air transmission or SQLite storage.
  Map<String, dynamic> toJson() {
    return {
      'message_id': messageId,
      'sender_id': senderId,
      'receiver_id': receiverId,
      'sender_node_id': senderNodeId,
      'receiver_node_id': receiverNodeId,
      'type': type,
      'priority': priority,
      'content': content,
      'timestamp': timestamp,
      'ttl': ttl,
      'status': status,
    };
  }

  /// Serializes packet directly to UTF-8 JSON bytes.
  List<int> toUtf8Bytes() {
    return utf8.encode(jsonEncode(toJson()));
  }

  /// Deserializes a MessagePacket from JSON map.
  factory MessagePacket.fromJson(Map<String, dynamic> json) {
    return MessagePacket(
      messageId: json['message_id'] as String? ?? '',
      senderId: json['sender_id'] as String? ?? '',
      receiverId: json['receiver_id'] as String? ?? '',
      senderNodeId: json['sender_node_id'] as String? ?? (json['sender_id'] as String? ?? ''),
      receiverNodeId: json['receiver_node_id'] as String? ?? (json['receiver_id'] as String? ?? ''),
      type: json['type'] as String? ?? MessageType.text,
      priority: json['priority'] as String? ?? MessagePriority.normal,
      content: json['content'] as String? ?? '',
      timestamp: (json['timestamp'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch,
      ttl: (json['ttl'] as num?)?.toInt() ?? 8,
      status: json['status'] as String? ?? MessageStatus.pending,
    );
  }

  /// Deserializes a MessagePacket from UTF-8 JSON bytes.
  factory MessagePacket.fromUtf8Bytes(List<int> bytes) {
    final decoded = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
    return MessagePacket.fromJson(decoded);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MessagePacket &&
          runtimeType == other.runtimeType &&
          messageId == other.messageId;

  @override
  int get hashCode => messageId.hashCode;

  @override
  String toString() {
    return 'MessagePacket($messageId, from: $senderNodeId ($senderId), to: $receiverNodeId ($receiverId), type: $type, ttl: $ttl, priority: $priority)';
  }
}
