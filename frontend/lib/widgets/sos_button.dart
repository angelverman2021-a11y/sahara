import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class SosButton extends StatelessWidget {
  final VoidCallback onTap;
  final bool isBroadcasting;

  const SosButton({
    super.key,
    required this.onTap,
    this.isBroadcasting = false,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Semantics(
        button: true,
        label: isBroadcasting ? 'SOS Active' : 'Emergency SOS Button',
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isBroadcasting ? AppTheme.emergencyRedDark : AppTheme.emergencyRed,
              boxShadow: [
                BoxShadow(
                  color: (isBroadcasting ? AppTheme.emergencyRedDark : AppTheme.emergencyRed)
                      .withValues(alpha: 0.28),
                  blurRadius: 16,
                  spreadRadius: 2,
                  offset: const Offset(0, 4),
                ),
              ],
              border: Border.all(
                color: isBroadcasting ? Colors.white : AppTheme.emergencyRedBorder,
                width: 3.5,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isBroadcasting ? Icons.notifications_active_rounded : Icons.warning_amber_rounded,
                  color: Colors.white,
                  size: 26,
                ),
                const SizedBox(height: 2),
                Text(
                  isBroadcasting ? 'ACTIVE' : 'SOS',
                  style: const TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                    color: Colors.white,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  isBroadcasting ? 'DISTRESS ON' : 'EMERGENCY',
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                    color: Colors.white.withValues(alpha: 0.92),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

