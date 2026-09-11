import 'package:flutter/material.dart';
import '../models/mesh_status.dart';
import '../theme/app_theme.dart';
import '../utils/app_localizations.dart';

class StatusCard extends StatelessWidget {
  final MeshStatus status;
  final VoidCallback? onTap;

  const StatusCard({
    super.key,
    required this.status,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radius),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.radius),
          border: Border.all(
            color: status.isBroadcastingSOS
                ? AppTheme.emergencyRed
                : AppTheme.surfaceBorder,
            width: status.isBroadcastingSOS ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            // Mesh availability text (green dot removed per requirement)
            Text(
              '${status.nearbyCount} meshes available',
              style: const TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              '|',
              style: TextStyle(color: AppTheme.surfaceBorderStrong, fontSize: 13),
            ),
            const SizedBox(width: 8),

            // Active mesh network status
            Expanded(
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      status.isMeshActive ? context.tr('mesh_active') : context.tr('mesh_inactive'),
                      style: const TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),

            // Real Battery percentage from Android BatteryManager
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  status.batteryLevel > 20
                      ? Icons.battery_charging_full_rounded
                      : Icons.battery_alert_rounded,
                  size: 17,
                  color: status.batteryLevel > 20
                      ? AppTheme.activeGreen
                      : AppTheme.emergencyRed,
                ),
                const SizedBox(width: 4),
                Text(
                  '${status.batteryLevel}%',
                  style: const TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
