import 'package:flutter/material.dart';
import '../models/announcement.dart';
import '../models/message.dart';
import '../services/service_scope.dart';
import '../theme/app_theme.dart';
import '../utils/app_localizations.dart';
import '../widgets/brand_title.dart';

class BroadcastScreen extends StatefulWidget {
  const BroadcastScreen({super.key});

  @override
  State<BroadcastScreen> createState() => _BroadcastScreenState();
}

class _BroadcastScreenState extends State<BroadcastScreen> {
  final TextEditingController _controller = TextEditingController();
  bool _isSent = false;
  String _lastBroadcastedMessage = '';
  AnnouncementSeverity _selectedSeverity = AnnouncementSeverity.warning;

  final List<String> _suggestions = const [
    'Road blocked near Gate 2.',
    'Safe shelter available.',
    'Do not use this route.',
    'Drinking water point active at Relief Tent 3.',
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleBroadcast(dynamic service) {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter an emergency broadcast message.'),
        ),
      );
      return;
    }

    final userProfile = service.userProfile;
    final senderName = (userProfile?.fullName != null && userProfile!.fullName.isNotEmpty)
        ? userProfile.fullName
        : 'You';

    String title;
    switch (_selectedSeverity) {
      case AnnouncementSeverity.evacuation:
        title = 'Evacuation Alert';
        break;
      case AnnouncementSeverity.warning:
        title = 'Emergency Warning';
        break;
      case AnnouncementSeverity.advisory:
        title = 'Advisory Notice';
        break;
    }

    // Add to announcements so it immediately appears in the Home feed
    final newAnnouncement = EmergencyAnnouncement(
      id: 'ann_${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      message: text,
      source: senderName,
      timeAgo: 'Just now',
      severity: _selectedSeverity,
    );
    service.addAnnouncement(newAnnouncement);

    // Relayed via mesh P2P service
    service.sendBroadcast(content: text);

    setState(() {
      _lastBroadcastedMessage = text;
      _isSent = true;
      _controller.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final service = EmergencyServiceScope.of(context);
    final recentBroadcasts = service.recentBroadcasts;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(_isSent ? context.tr('broadcast_sent') : context.tr('emergency_broadcast')),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: _isSent
              ? _buildSentConfirmationView(context)
              : _buildComposeView(context, service, recentBroadcasts),
        ),
      ),
    );
  }

  Widget _buildComposeView(
    BuildContext context,
    dynamic service,
    List<Message> recentBroadcasts,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          context.tr('emergency_broadcast'),
          style: const TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 6),
        Text.rich(
          TextSpan(
            style: const TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 13,
              color: AppTheme.textSecondary,
            ),
            children: [
              const TextSpan(
                text: 'Propagated to all reachable peer devices in the ',
              ),
              buildBrandSpan(
                context: context,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
              const TextSpan(
                text: ' mesh.',
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // 1. Required Severity Selector
        Text(
          context.tr('broadcast_severity'),
          style: const TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
            color: AppTheme.textMuted,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildSeverityOption(
                context,
                severity: AnnouncementSeverity.advisory,
                label: context.tr('severity_advisory'),
                icon: Icons.info_outline_rounded,
                activeColor: AppTheme.secondaryBlue,
                activeBg: AppTheme.blueSurfaceTint,
                activeBorder: AppTheme.lightBlue,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildSeverityOption(
                context,
                severity: AnnouncementSeverity.warning,
                label: context.tr('severity_warning'),
                icon: Icons.warning_amber_rounded,
                activeColor: AppTheme.relayAmber,
                activeBg: AppTheme.relayAmberLight,
                activeBorder: AppTheme.relayAmberBorder,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildSeverityOption(
                context,
                severity: AnnouncementSeverity.evacuation,
                label: context.tr('severity_evacuation'),
                icon: Icons.crisis_alert_rounded,
                activeColor: AppTheme.emergencyRed,
                activeBg: AppTheme.emergencyRedLight,
                activeBorder: AppTheme.emergencyRedBorder,
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),

        // Quick suggestions
        Text(
          context.tr('quick_suggestions'),
          style: const TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
            color: AppTheme.textMuted,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: _suggestions.map((template) {
            return ActionChip(
              label: Text(
                template,
                style: const TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 12.5,
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              backgroundColor: AppTheme.surfaceSubtle,
              side: const BorderSide(color: AppTheme.surfaceBorder),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radius),
              ),
              onPressed: () {
                _controller.text = template;
                _controller.selection = TextSelection.fromPosition(
                  TextPosition(offset: _controller.text.length),
                );
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 18),

        // Text input field
        Text(
          context.tr('broadcast_message'),
          style: const TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
            color: AppTheme.textMuted,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _controller,
          maxLines: 4,
          minLines: 3,
          textCapitalization: TextCapitalization.sentences,
          style: const TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: 14.5,
            color: AppTheme.textPrimary,
          ),
          decoration: InputDecoration(
            hintText: context.tr('enter_broadcast_hint'),
          ),
        ),
        const SizedBox(height: 20),

        // Prominent Broadcast Message Button
        ElevatedButton.icon(
          onPressed: () => _handleBroadcast(service),
          icon: const Icon(Icons.campaign_rounded, size: 20),
          label: Text(
            context.tr('broadcast_button'),
            style: const TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 15,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: _selectedSeverity == AnnouncementSeverity.evacuation
                ? AppTheme.emergencyRed
                : AppTheme.textPrimary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),

        const SizedBox(height: 28),

        // Recent Broadcasts
        if (recentBroadcasts.isNotEmpty) ...[
          const Text(
            'RECENT MESH BROADCASTS',
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: AppTheme.textMuted,
            ),
          ),
          const SizedBox(height: 10),
          ...recentBroadcasts.map((b) => _buildRecentBroadcastCard(b)),
        ],
      ],
    );
  }

  Widget _buildSeverityOption(
    BuildContext context, {
    required AnnouncementSeverity severity,
    required String label,
    required IconData icon,
    required Color activeColor,
    required Color activeBg,
    required Color activeBorder,
  }) {
    final isSelected = _selectedSeverity == severity;

    return Material(
      color: isSelected ? activeBg : AppTheme.surface,
      borderRadius: BorderRadius.circular(AppTheme.radius),
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedSeverity = severity;
          });
        },
        borderRadius: BorderRadius.circular(AppTheme.radius),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.radius),
            border: Border.all(
              color: isSelected ? activeBorder : AppTheme.surfaceBorder,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 20,
                color: isSelected ? activeColor : AppTheme.textSecondary,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? activeColor : AppTheme.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSentConfirmationView(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Sent Banner
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.activeGreenLight,
            borderRadius: BorderRadius.circular(AppTheme.radius),
            border: Border.all(color: AppTheme.activeGreenBorder),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.check_circle_rounded,
                color: AppTheme.activeGreen,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr('broadcast_sent'),
                      style: const TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.activeGreen,
                      ),
                    ),
                    Text.rich(
                      TextSpan(
                        style: const TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 12.5,
                          color: AppTheme.textSecondary,
                        ),
                        children: [
                          const TextSpan(
                            text: 'Relaying through the ',
                          ),
                          buildBrandSpan(
                            context: context,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                          const TextSpan(
                            text: ' network.',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Stats Box
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(AppTheme.radius),
            border: Border.all(color: AppTheme.surfaceBorder),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(context.tr('recipients_reached'), '8', Icons.group_outlined),
              Container(width: 1, height: 40, color: AppTheme.surfaceBorder),
              _buildStatItem(context.tr('relays_count'), '4', Icons.hub_outlined),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Message Content Box
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.surfaceSubtle,
            borderRadius: BorderRadius.circular(AppTheme.radius),
            border: Border.all(color: AppTheme.surfaceBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.tr('broadcast_message'),
                style: const TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: AppTheme.textMuted,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '"$_lastBroadcastedMessage"',
                style: const TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 14.5,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textPrimary,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Buttons
        OutlinedButton(
          onPressed: () {
            setState(() {
              _isSent = false;
            });
          },
          child: Text(context.tr('compose_another')),
        ),
        const SizedBox(height: 10),

        ElevatedButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.tr('return_to_home')),
        ),
      ],
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: AppTheme.textSecondary, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: 12,
            color: AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildRecentBroadcastCard(Message message) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: AppTheme.surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                message.senderName,
                style: const TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              Text(
                message.timeFormatted,
                style: const TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 11,
                  color: AppTheme.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            message.content,
            style: const TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 13,
              color: AppTheme.textSecondary,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}
