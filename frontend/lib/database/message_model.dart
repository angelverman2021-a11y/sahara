/// A data model representing a chat message in the disaster management system.
///
/// This class handles serialization and deserialization of messages
/// to and from a SQLite database via [toMap] and [fromMap].
class MessageModel {
  /// Unique identifier for the message.
  final String messageId;

  /// Unique identifier of the message sender.
  final String senderId;

  /// Unique identifier of the intended recipient.
  final String receiverId;

  /// Category of the message (e.g., 'text', 'alert', 'sos', 'broadcast').
  final String type;

  /// Urgency level of the message (e.g., 'low', 'medium', 'high', 'critical').
  final String priority;

  /// The actual message payload or body.
  final String content;

  /// ISO 8601 timestamp string indicating when the message was created.
  final String timestamp;

  /// Time-to-live in seconds; after this duration the message should be discarded.
  final int ttl;

  /// Delivery/read status of the message (e.g., 'sent', 'delivered', 'read', 'failed').
  final String status;

  // ---------------------------------------------------------------------------
  // Constructor
  // ---------------------------------------------------------------------------

  /// Creates a [MessageModel] with all fields required.
  const MessageModel({
    required this.messageId,
    required this.senderId,
    required this.receiverId,
    required this.type,
    required this.priority,
    required this.content,
    required this.timestamp,
    required this.ttl,
    required this.status,
  });

  // ---------------------------------------------------------------------------
  // Serialization
  // ---------------------------------------------------------------------------

  /// Converts this [MessageModel] into a [Map] suitable for SQLite insertion.
  ///
  /// Column names match the database schema using snake_case keys.
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'message_id': messageId,
      'sender_id': senderId,
      'receiver_id': receiverId,
      'type': type,
      'priority': priority,
      'content': content,
      'timestamp': timestamp,
      'ttl': ttl,
      'status': status,
    };
  }

  // ---------------------------------------------------------------------------
  // Deserialization
  // ---------------------------------------------------------------------------

  /// Creates a [MessageModel] from a database [Map] (e.g., a row returned by sqflite).
  ///
  /// Throws a [TypeError] if any required field is missing or has an unexpected type.
  factory MessageModel.fromMap(Map<String, dynamic> map) {
    return MessageModel(
      messageId: map['message_id'] as String,
      senderId: map['sender_id'] as String,
      receiverId: map['receiver_id'] as String,
      type: map['type'] as String,
      priority: map['priority'] as String,
      content: map['content'] as String,
      timestamp: map['timestamp'] as String,
      ttl: map['ttl'] as int,
      status: map['status'] as String,
    );
  }

  // ---------------------------------------------------------------------------
  // Utility overrides
  // ---------------------------------------------------------------------------

  /// Returns a copy of this [MessageModel] with the given fields replaced.
  MessageModel copyWith({
    String? messageId,
    String? senderId,
    String? receiverId,
    String? type,
    String? priority,
    String? content,
    String? timestamp,
    int? ttl,
    String? status,
  }) {
    return MessageModel(
      messageId: messageId ?? this.messageId,
      senderId: senderId ?? this.senderId,
      receiverId: receiverId ?? this.receiverId,
      type: type ?? this.type,
      priority: priority ?? this.priority,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      ttl: ttl ?? this.ttl,
      status: status ?? this.status,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MessageModel && other.messageId == messageId;
  }

  @override
  int get hashCode => messageId.hashCode;

  @override
  String toString() {
    return 'MessageModel('
        'messageId: $messageId, '
        'senderId: $senderId, '
        'receiverId: $receiverId, '
        'type: $type, '
        'priority: $priority, '
        'content: $content, '
        'timestamp: $timestamp, '
        'ttl: $ttl, '
        'status: $status'
        ')';
  }
}
