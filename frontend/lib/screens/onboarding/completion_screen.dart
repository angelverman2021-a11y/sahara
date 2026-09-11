import 'package:flutter/material.dart';
import '../../models/user_profile.dart';
import '../../theme/app_theme.dart';
import '../../utils/app_localizations.dart';
import '../../widgets/brand_title.dart';

class CompletionScreen extends StatelessWidget {
  final UserProfile profile;
  final VoidCallback onFinish;

  const CompletionScreen({
    super.key,
    required this.profile,
    required this.onFinish,
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

              // Success emblem
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppTheme.activeGreenLight,
                  borderRadius: BorderRadius.circular(AppTheme.radius),
                  border: Border.all(color: AppTheme.activeGreenBorder),
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: AppTheme.activeGreen,
                  size: 32,
                ),
              ),
              const SizedBox(height: 22),

              Text(
                context.tr('profile_complete'),
                style: const TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 8),

              Text(
                context.tr('ready_to_connect'),
                style: const TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 14.5,
                  color: AppTheme.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),

              // Summary Box (Indian utility style)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceSubtle,
                  borderRadius: BorderRadius.circular(AppTheme.radius),
                  border: Border.all(color: AppTheme.surfaceBorder),
                ),
                child: Column(
                  children: [
                    _summaryRow(context.tr('full_name'), profile.fullName.isNotEmpty ? profile.fullName : 'Not specified'),
                    const Divider(height: 16),
                    _summaryRow(context.tr('contact_number'), profile.phoneNumber.isNotEmpty ? profile.phoneNumber : 'Not specified'),
                    const Divider(height: 16),
                    _summaryRow(context.tr('language_preference'), profile.language),
                    const Divider(height: 16),
                    _summaryRow(context.tr('emergency_contacts'), '${profile.emergencyContacts.length} added'),
                  ],
                ),
              ),

              const Spacer(),

              // Continue to *Sahara* Button
              ElevatedButton(
                onPressed: onFinish,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.textPrimary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radius),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${context.tr('continue_btn')} ',
                      style: const TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const BrandTitle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _summaryRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: 13,
            color: AppTheme.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: 13.5,
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
