import 'package:flutter/material.dart';
import '../models/person.dart';
import '../services/service_scope.dart';
import '../theme/app_theme.dart';
import '../utils/app_localizations.dart';
import 'chat_screen.dart';

class MessagesScreen extends StatelessWidget {
  const MessagesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = EmergencyServiceScope.of(context);
    final conversations = service.conversations;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(context.tr('emergency_messages')),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Notice Bar
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: AppTheme.surfaceSubtle,
              child: Row(
                children: [
                  const Icon(Icons.hub_outlined, size: 16, color: AppTheme.activeGreen),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      context.tr('p2p_notice'),
                      style: const TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Conversation List
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: conversations.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final person = conversations[index];
                  final messages = service.getMessages(person.id);
                  final lastMessage = messages.isNotEmpty ? messages.last : null;

                  return _ConversationTile(
                    person: person,
                    previewText: lastMessage?.content ?? 'No messages yet',
                    timeText: _formatLastMessageTime(person.id, lastMessage?.timeFormatted),
                    hopsText: '${person.hops} ${person.hops == 1 ? "hop" : "hops"}',
                    isUrgent: person.relation == PersonRelation.emergencyTeam,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChatScreen(person: person),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _formatLastMessageTime(String personId, String? timeFormatted) {
    if (personId == 'fam_mother') return '2 min ago';
    if (personId == 'contact_rahul') return '5 min ago';
    if (personId == 'contact_emergency_team') return '12 min ago';
    return timeFormatted ?? 'Recently';
  }
}

class _ConversationTile extends StatelessWidget {
  final Person person;
  final String previewText;
  final String timeText;
  final String hopsText;
  final bool isUrgent;
  final VoidCallback onTap;

  const _ConversationTile({
    required this.person,
    required this.previewText,
    required this.timeText,
    required this.hopsText,
    required this.isUrgent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isReachable = person.isReachable;

    return Material(
      color: AppTheme.surface,
      borderRadius: BorderRadius.circular(AppTheme.radius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.radius),
            border: Border.all(
              color: isUrgent ? AppTheme.emergencyRedBorder : AppTheme.surfaceBorder,
              width: 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: isUrgent ? AppTheme.emergencyRedLight : AppTheme.surfaceSubtle,
                  borderRadius: BorderRadius.circular(AppTheme.radius),
                  border: Border.all(
                    color: isUrgent ? AppTheme.emergencyRedBorder : AppTheme.surfaceBorder,
                  ),
                ),
                child: Center(
                  child: Text(
                    person.name.isNotEmpty ? person.name[0].toUpperCase() : '?',
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: isUrgent ? AppTheme.emergencyRed : AppTheme.textPrimary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            person.name,
                            style: const TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: 14.5,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          timeText,
                          style: const TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: 12,
                            color: AppTheme.textMuted,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      previewText,
                      style: const TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                        height: 1.25,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text(
                          hopsText,
                          style: const TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.relayAmber,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Text('•', style: TextStyle(color: AppTheme.surfaceBorderStrong, fontSize: 10)),
                        const SizedBox(width: 6),
                        Text(
                          isReachable ? 'Reachable' : 'Offline relay',
                          style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                            color: isReachable ? AppTheme.activeGreen : AppTheme.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
