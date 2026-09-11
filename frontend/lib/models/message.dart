enum MessageType {
  text,
  sosAlert,
  broadcast,
}

enum MessagePriority {
  normal,
  high,
  critical,
}

class Message {
  final String id;
  final String senderId;
  final String receiverId;
  final String senderName;
  final String content;
  final DateTime timestamp;
  final MessageType type;
  final MessagePriority priority;
  final bool isDelivered;
  final bool isFromMe;
  final int hops;
  final Map<String, String>? translations;

  const Message({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.senderName,
    required this.content,
    required this.timestamp,
    this.type = MessageType.text,
    this.priority = MessagePriority.normal,
    this.isDelivered = true,
    required this.isFromMe,
    this.hops = 1,
    this.translations,
  });

  String get timeFormatted {
    final hour = timestamp.hour.toString().padLeft(2, '0');
    final minute = timestamp.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  /// Non-destructively resolves the localized content for given language code.
  /// Falls back to English, or original content.
  String localizedContent(String langCode) {
    return translations?[langCode] ??
        translations?['en'] ??
        content;
  }

  Message copyWith({
    String? id,
    String? senderId,
    String? receiverId,
    String? senderName,
    String? content,
    DateTime? timestamp,
    MessageType? type,
    MessagePriority? priority,
    bool? isDelivered,
    bool? isFromMe,
    int? hops,
    Map<String, String>? translations,
  }) {
    return Message(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      receiverId: receiverId ?? this.receiverId,
      senderName: senderName ?? this.senderName,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      type: type ?? this.type,
      priority: priority ?? this.priority,
      isDelivered: isDelivered ?? this.isDelivered,
      isFromMe: isFromMe ?? this.isFromMe,
      hops: hops ?? this.hops,
      translations: translations ?? this.translations,
    );
  }
}

