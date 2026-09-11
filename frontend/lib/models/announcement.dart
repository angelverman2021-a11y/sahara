enum AnnouncementSeverity {
  warning,
  evacuation,
  advisory,
}

class EmergencyAnnouncement {
  final String id;
  final String title;
  final String message;
  final String source;
  final String timeAgo;
  final AnnouncementSeverity severity;

  const EmergencyAnnouncement({
    required this.id,
    required this.title,
    required this.message,
    required this.source,
    required this.timeAgo,
    this.severity = AnnouncementSeverity.warning,
  });
}
