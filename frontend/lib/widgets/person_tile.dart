import 'package:flutter/material.dart';
import '../models/person.dart';
import '../theme/app_theme.dart';
import '../utils/app_localizations.dart';

class PersonTile extends StatelessWidget {
  final Person person;
  final VoidCallback onTap;
  final VoidCallback? onMessageTap;
  final VoidCallback? onPingTap;
  final VoidCallback? onAddAsFamilyTap;

  const PersonTile({
    super.key,
    required this.person,
    required this.onTap,
    this.onMessageTap,
    this.onPingTap,
    this.onAddAsFamilyTap,
  });

  @override
  Widget build(BuildContext context) {
    final isReachable = person.isReachable;
    final displayName = (person.name.isNotEmpty &&
            person.name != 'SAHARA User' &&
            person.name != 'Sahara User')
        ? person.name
        : (person.phoneNumber?.isNotEmpty == true
            ? person.phoneNumber!
            : (person.id.startsWith('NODE_')
                ? 'Mesh Peer (${person.id.substring(person.id.length >= 4 ? person.id.length - 4 : 0)})'
                : person.id));

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(
          color: person.status == PersonStatus.sosActive
              ? AppTheme.emergencyRed
              : AppTheme.surfaceBorder,
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppTheme.radius),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Square utility avatar
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: isReachable
                            ? AppTheme.activeGreenLight
                            : AppTheme.surfaceSubtle,
                        borderRadius: BorderRadius.circular(AppTheme.radius),
                        border: Border.all(
                          color: isReachable
                              ? AppTheme.activeGreenBorder
                              : AppTheme.surfaceBorder,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                          style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: isReachable
                                ? AppTheme.activeGreen
                                : AppTheme.textSecondary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Details
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  displayName,
                                  style: const TextStyle(
                                    fontFamily: AppTheme.fontFamily,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.textPrimary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: AppTheme.surfaceSubtle,
                                  borderRadius: BorderRadius.circular(AppTheme.radius),
                                  border: Border.all(color: AppTheme.surfaceBorder),
                                ),
                                child: Text(
                                  person.relationLabel,
                                  style: const TextStyle(
                                    fontFamily: AppTheme.fontFamily,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),

                          // Reachability & Hops
                          Row(
                            children: [
                              Container(
                                width: 7,
                                height: 7,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isReachable ? AppTheme.activeGreen : AppTheme.textMuted,
                                ),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                isReachable
                                    ? '${context.tr('reachable')} • ${person.hops == 1 ? context.tr('hop') : context.tr('hops', {'count': person.hops.toString()})}'
                                    : '${context.tr('unreachable')} • ${person.lastSeen}',
                                style: TextStyle(
                                  fontFamily: AppTheme.fontFamily,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w500,
                                  color: isReachable ? AppTheme.activeGreen : AppTheme.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    if (onMessageTap != null)
                      IconButton(
                        icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
                        color: AppTheme.textSecondary,
                        tooltip: '${context.tr('message')} ${person.name}',
                        onPressed: onMessageTap,
                      ),
                  ],
                ),

                // Actions (Ping / Add as family)
                if (onPingTap != null || onAddAsFamilyTap != null) ...[
                  const SizedBox(height: 10),
                  const Divider(height: 1),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      if (onPingTap != null)
                        SizedBox(
                          height: 34,
                          child: OutlinedButton.icon(
                            onPressed: onPingTap,
                            icon: const Icon(Icons.sensors_rounded, size: 14),
                            label: Text(
                              context.tr('ping'),
                              style: const TextStyle(
                                fontFamily: AppTheme.fontFamily,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.textPrimary,
                              side: const BorderSide(color: AppTheme.surfaceBorderStrong),
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(AppTheme.radius),
                              ),
                            ),
                          ),
                        ),
                      if (onAddAsFamilyTap != null)
                        SizedBox(
                          height: 34,
                          child: OutlinedButton.icon(
                            onPressed: onAddAsFamilyTap,
                            icon: const Icon(Icons.person_add_alt_1_rounded, size: 14),
                            label: Text(
                              context.tr('add_to_family'),
                              style: const TextStyle(
                                fontFamily: AppTheme.fontFamily,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.primaryNavy,
                              backgroundColor: AppTheme.blueSurfaceTint.withValues(alpha: 0.5),
                              side: const BorderSide(color: AppTheme.secondaryBlue, width: 1),
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(AppTheme.radius),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
