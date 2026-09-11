enum AnnouncementSeverity {
  warning,
  evacuation,
  advisory,
}

class LocalizedContent {
  final String title;
  final String message;
  final String? source;

  const LocalizedContent({
    required this.title,
    required this.message,
    this.source,
  });
}

class EmergencyAnnouncement {
  final String id;
  final String title;
  final String message;
  final String source;
  final String timeAgo;
  final AnnouncementSeverity severity;
  final Map<String, LocalizedContent>? translations;

  const EmergencyAnnouncement({
    required this.id,
    required this.title,
    required this.message,
    required this.source,
    required this.timeAgo,
    this.severity = AnnouncementSeverity.warning,
    this.translations,
  });

  /// Non-destructively resolves the localized title for given language code.
  /// Falls back to English, or original title.
  String localizedTitle(String langCode) {
    return translations?[langCode]?.title ??
        translations?['en']?.title ??
        title;
  }

  /// Non-destructively resolves the localized message for given language code.
  /// Falls back to English, or original message.
  String localizedMessage(String langCode) {
    return translations?[langCode]?.message ??
        translations?['en']?.message ??
        message;
  }

  /// Non-destructively resolves the localized source if available.
  String localizedSource(String langCode) {
    return translations?[langCode]?.source ??
        translations?['en']?.source ??
        source;
  }
}

