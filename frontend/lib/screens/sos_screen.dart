import 'package:flutter/material.dart';
import '../services/service_scope.dart';
import '../theme/app_theme.dart';
import '../widgets/brand_title.dart';
import 'nearby_screen.dart';

class SosScreen extends StatefulWidget {
  const SosScreen({super.key});

  @override
  State<SosScreen> createState() => _SosScreenState();
}

class _SosScreenState extends State<SosScreen> {
  bool _confirmedLocally = false;

  @override
  Widget build(BuildContext context) {
    final service = EmergencyServiceScope.of(context);
    final meshStatus = service.meshStatus;
    final isSent = _confirmedLocally || meshStatus.isBroadcastingSOS;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(isSent ? 'Emergency Beacon Active' : 'Emergency SOS'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: isSent
              ? _buildSosSentView(context, service, meshStatus)
              : _buildConfirmationPrompt(context, service, meshStatus),
        ),
      ),
    );
  }

  // Pre-confirmation State
  Widget _buildConfirmationPrompt(BuildContext context, dynamic service, dynamic meshStatus) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Urgent Warning Emblem
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.emergencyRedLight,
            borderRadius: BorderRadius.circular(AppTheme.radius),
            border: Border.all(color: AppTheme.emergencyRedBorder),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                color: AppTheme.emergencyRed,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'HIGH PRIORITY DISTRESS ALERT',
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                        color: AppTheme.emergencyRed,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text.rich(
                      TextSpan(
                        style: const TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 12.5,
                          color: AppTheme.textSecondary,
                        ),
                        children: [
                          const TextSpan(text: 'Broadcast via '),
                          buildBrandSpan(
                            context: context,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                          const TextSpan(text: ' offline mesh'),
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

        const Text(
          'Send Emergency SOS?',
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'An emergency distress beacon containing your GPS coordinates and battery level will immediately broadcast to ${meshStatus.nearbyCount} nearby devices and emergency volunteers across the offline mesh.',
          style: const TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: 14,
            color: AppTheme.textSecondary,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 20),

        // Emergency Status Details Box
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(AppTheme.radius),
            border: Border.all(color: AppTheme.surfaceBorder),
          ),
          child: Column(
            children: [
              _buildDetailRow(
                icon: Icons.location_on_outlined,
                iconColor: AppTheme.activeGreen,
                label: 'Current Mock Location',
                value: 'Available (28.5355° N, 77.3910° E)',
                subValue: 'GPS fix: ±5m accuracy',
              ),
              const Divider(height: 20),
              _buildDetailRow(
                icon: Icons.battery_charging_full_rounded,
                iconColor: AppTheme.activeGreen,
                label: 'Battery Level (Real Device)',
                value: '${meshStatus.batteryLevel}%',
                subValue: 'Direct from Android BatteryManager',
              ),
              const Divider(height: 20),
              _buildDetailRow(
                icon: Icons.priority_high_rounded,
                iconColor: AppTheme.emergencyRed,
                label: 'Emergency Priority',
                value: 'HIGH',
                subValue: 'Store-and-forward flooding enabled',
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),

        // Prominent Confirmation Button
        ElevatedButton(
          onPressed: () {
            setState(() {
              _confirmedLocally = true;
            });
            service.triggerSOS();
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.emergencyRed,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radius),
            ),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.crisis_alert_rounded, size: 20),
              SizedBox(width: 8),
              Text(
                'CONFIRM EMERGENCY SOS',
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // Cancel / Back Button
        OutlinedButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel and Return'),
        ),
      ],
    );
  }

  // Post-confirmation State ("SOS SENT")
  Widget _buildSosSentView(BuildContext context, dynamic service, dynamic meshStatus) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Sent Banner
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.emergencyRedLight,
            borderRadius: BorderRadius.circular(AppTheme.radius),
            border: Border.all(color: AppTheme.emergencyRedBorder, width: 1.5),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppTheme.emergencyRed,
                  borderRadius: BorderRadius.circular(AppTheme.radius),
                ),
                child: const Icon(Icons.sensors_rounded, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SOS SENT',
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                        color: AppTheme.emergencyRed,
                      ),
                    ),
                    Text(
                      'Distress beacon actively transmitting to mesh',
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        Text.rich(
          TextSpan(
            style: const TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 14,
              color: AppTheme.textSecondary,
            ),
            children: [
              const TextSpan(
                text: 'Your emergency alert has been sent to the nearby ',
              ),
              buildBrandSpan(
                context: context,
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
              const TextSpan(
                text: ' network.',
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // Live Status Box
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(AppTheme.radius),
            border: Border.all(color: AppTheme.surfaceBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'BROADCAST TELEMETRY',
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: AppTheme.textMuted,
                ),
              ),
              const SizedBox(height: 12),
              _buildLiveStatusRow(
                dotColor: AppTheme.activeGreen,
                title: 'Status',
                value: 'Broadcasting',
              ),
              const SizedBox(height: 8),
              _buildLiveStatusRow(
                dotColor: AppTheme.relayAmber,
                title: 'Relays',
                value: 'Relays available (4 active)',
              ),
              const SizedBox(height: 8),
              _buildLiveStatusRow(
                dotColor: AppTheme.emergencyRed,
                title: 'Priority',
                value: 'HIGH',
              ),
              const Divider(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Battery Level:', style: TextStyle(fontFamily: AppTheme.fontFamily, color: AppTheme.textSecondary, fontSize: 13)),
                  Text('${meshStatus.batteryLevel}%', style: const TextStyle(fontFamily: AppTheme.fontFamily, color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
                ],
              ),
              const SizedBox(height: 4),
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Coordinates:', style: TextStyle(fontFamily: AppTheme.fontFamily, color: AppTheme.textSecondary, fontSize: 13)),
                  Text('28.5355° N, 77.3910° E', style: TextStyle(fontFamily: AppTheme.fontFamily, color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Action Buttons
        OutlinedButton.icon(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const NearbyScreen()),
            );
          },
          icon: const Icon(Icons.people_outline, size: 18),
          label: const Text('View Nearby Responders'),
        ),
        const SizedBox(height: 10),

        ElevatedButton.icon(
          onPressed: () {
            service.cancelSOS();
            setState(() {
              _confirmedLocally = false;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Emergency SOS broadcast cancelled.'),
              ),
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.surfaceSubtle,
            foregroundColor: AppTheme.emergencyRed,
            side: const BorderSide(color: AppTheme.emergencyRedBorder),
          ),
          icon: const Icon(Icons.cancel_outlined, size: 18),
          label: const Text('Cancel SOS Broadcast'),
        ),
      ],
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    required String subValue,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: AppTheme.surfaceSubtle,
            borderRadius: BorderRadius.circular(AppTheme.radius),
          ),
          child: Icon(icon, color: iconColor, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                subValue,
                style: const TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 11.5,
                  color: AppTheme.textMuted,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLiveStatusRow({
    required Color dotColor,
    required String title,
    required String value,
  }) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: dotColor,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '$title: ',
          style: const TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: 13.5,
            fontWeight: FontWeight.w500,
            color: AppTheme.textSecondary,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
      ],
    );
  }
}
