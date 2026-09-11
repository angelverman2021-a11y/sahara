import 'package:flutter/material.dart';
import '../models/announcement.dart';
import '../services/service_scope.dart';
import '../theme/app_theme.dart';
import '../utils/app_localizations.dart';


class EmergencyBroadcastFeed extends StatelessWidget {
  final List<EmergencyAnnouncement> announcements;
  final VoidCallback onSendBroadcast;

  const EmergencyBroadcastFeed({
    super.key,
    required this.announcements,
    required this.onSendBroadcast,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Section Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.campaign_rounded,
                  size: 17,
                  color: AppTheme.primaryNavy,
                ),
                const SizedBox(width: 6),
                Text(
                  context.tr('emergency_broadcast').toUpperCase(),
                  style: const TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: AppTheme.primaryNavy,
                  ),
                ),
              ],
            ),
            if (announcements.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.blueSurfaceTint,
                  borderRadius: BorderRadius.circular(AppTheme.radius),
                  border: Border.all(color: AppTheme.surfaceBorder),
                ),
                child: Text(
                  context.tr('active_badge', {'count': announcements.length.toString()}),
                  style: const TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: AppTheme.primaryNavy,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),

        // Announcement Feed Container
        Container(
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(AppTheme.radius),
            border: Border.all(color: AppTheme.surfaceBorder),
          ),
          child: announcements.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(16),
                  child: Center(
                    child: Text(
                      context.tr('no_broadcasts'),
                      style: const TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 13,
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ),
                )
              : Column(
                  children: [
                    for (int i = 0; i < announcements.length; i++) ...[
                      if (i > 0)
                        const Divider(
                          height: 1,
                          thickness: 1,
                          color: AppTheme.surfaceBorder,
                        ),
                      _buildAnnouncementRow(context, announcements[i]),
                    ],
                  ],
                ),
        ),
        const SizedBox(height: 10),

        // Distinct "Send emergency broadcast" Action Underneath
        OutlinedButton.icon(
          onPressed: onSendBroadcast,
          icon: const Icon(Icons.send_rounded, size: 15),
          label: Text(
            context.tr('send_emergency_broadcast'),
            style: const TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppTheme.primaryNavy,
            backgroundColor: AppTheme.blueSurfaceTint.withValues(alpha: 0.4),
            side: const BorderSide(color: AppTheme.secondaryBlue, width: 1.2),
            padding: const EdgeInsets.symmetric(vertical: 11),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radius),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAnnouncementRow(BuildContext context, EmergencyAnnouncement announcement) {
    Color badgeBg;
    Color badgeText;
    Color badgeBorder;
    String label;

    switch (announcement.severity) {
      case AnnouncementSeverity.evacuation:
        badgeBg = AppTheme.emergencyRedLight;
        badgeText = AppTheme.emergencyRed;
        badgeBorder = AppTheme.emergencyRedBorder;
        label = context.tr('severity_evacuation').toUpperCase();
        break;
      case AnnouncementSeverity.warning:
        badgeBg = AppTheme.relayAmberLight;
        badgeText = AppTheme.relayAmber;
        badgeBorder = AppTheme.relayAmberBorder;
        label = context.tr('severity_warning').toUpperCase();
        break;
      case AnnouncementSeverity.advisory:
        badgeBg = AppTheme.blueSurfaceTint;
        badgeText = AppTheme.secondaryBlue;
        badgeBorder = AppTheme.lightBlue;
        label = context.tr('severity_advisory').toUpperCase();
        break;
    }

    final service = EmergencyServiceScope.of(context);
    final langCode = AppLocalizations.codeForLanguage(service.selectedLanguage);

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Badge, Source, and Timestamp
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(AppTheme.radius),
                  border: Border.all(color: badgeBorder, width: 0.8),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: badgeText,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  announcement.localizedSource(langCode),
                  style: const TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textMuted,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                announcement.timeAgo,
                style: const TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 11,
                  color: AppTheme.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Title
          Text(
            announcement.localizedTitle(langCode),
            style: const TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 3),

          // Message Content
          Text(
            announcement.localizedMessage(langCode),
            style: const TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 12.5,
              color: AppTheme.textSecondary,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}
