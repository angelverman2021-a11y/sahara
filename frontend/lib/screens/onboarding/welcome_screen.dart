import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../utils/app_localizations.dart';
import '../../widgets/app_logo.dart';
import '../../widgets/brand_title.dart';

class WelcomeScreen extends StatelessWidget {
  final VoidCallback onGetStarted;

  const WelcomeScreen({
    super.key,
    required this.onGetStarted,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(),

              // Official Sahara Logo (Substantially enlarged, sitting directly on background)
              const Center(
                child: AppLogo(
                  height: 150,
                  width: 280,
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 24),

              // Italic Sahara Branding
              const Row(
                children: [
                  Text(
                    'Welcome to ',
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                      letterSpacing: -0.3,
                    ),
                  ),
                  BrandTitle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primaryNavy,
                  ),
                ],
              ),
              const SizedBox(height: 8),

              const Text(
                'Offline Emergency Communication',
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.secondaryBlue,
                ),
              ),
              const SizedBox(height: 12),

              const Text(
                'Create your emergency profile so responders, volunteers, and family members can identify and reach you during disasters.',
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 14,
                  color: AppTheme.textSecondary,
                  height: 1.45,
                ),
              ),

              const Spacer(),

              // Reassurance Note
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.blueSurfaceTint,
                  borderRadius: BorderRadius.circular(AppTheme.radius),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.wifi_off_rounded, size: 16, color: AppTheme.primaryNavy),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Stored locally on your device for decentralized mesh discovery.',
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 12,
                          color: AppTheme.primaryNavy,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Get Started Button
              ElevatedButton(
                onPressed: onGetStarted,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryNavy,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radius),
                  ),
                ),
                child: Text(
                  context.tr('get_started'),
                  style: const TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}
