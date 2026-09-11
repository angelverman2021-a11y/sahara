import 'package:flutter/material.dart';
import '../services/native_bridge.dart';
import '../services/service_scope.dart';
import '../theme/app_theme.dart';
import '../widgets/app_logo.dart';
import '../widgets/brand_title.dart';
import '../widgets/emergency_broadcast_feed.dart';
import '../widgets/feature_card.dart';
import '../widgets/sos_button.dart';
import '../widgets/status_card.dart';
import 'broadcast_screen.dart';
import 'family_screen.dart';
import 'messages_screen.dart';
import 'nearby_screen.dart';
import 'onboarding/language_screen.dart';
import 'sos_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _syncBattery();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _syncBattery();
    }
  }

  Future<void> _syncBattery() async {
    try {
      final realLevel = await NativeBridge.getBatteryLevel();
      if (mounted) {
        final service = EmergencyServiceScope.of(context);
        service.updateRealBattery(realLevel);
      }
    } catch (_) {}
  }

  void _openLanguagePicker(BuildContext context, dynamic service) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LanguageScreen(
          initialLanguage: service.selectedLanguage,
          onContinue: (lang) {
            service.setLanguage(lang);
            Navigator.pop(context);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final service = EmergencyServiceScope.of(context);
    final meshStatus = service.meshStatus;
    final reachableCount = service.familyMembers.where((m) => m.isReachable).length;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Sahara Official Brand Header + Language Selector
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const AppLogo(height: 30),
                  const SizedBox(width: 10),
                  const BrandTitle(
                    fontSize: 25,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primaryNavy,
                  ),
                  const Spacer(),
                  InkWell(
                    onTap: () => _openLanguagePicker(context, service),
                    borderRadius: BorderRadius.circular(AppTheme.radius),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.blueSurfaceTint,
                        borderRadius: BorderRadius.circular(AppTheme.radius),
                        border: Border.all(color: AppTheme.surfaceBorder),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.language_rounded, size: 14, color: AppTheme.primaryNavy),
                          const SizedBox(width: 5),
                          Text(
                            service.selectedLanguage,
                            style: const TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.primaryNavy,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 3),

              // 2. Subtitle: OFFLINE EMERGENCY MESH NETWORK
              const Text(
                'OFFLINE EMERGENCY MESH NETWORK',
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: AppTheme.textMuted,
                ),
              ),
              const SizedBox(height: 14),

              // 3. Compact Mesh/Network Status (Mesh Active, nearby count, real battery %)
              StatusCard(
                status: meshStatus,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const NearbyScreen()),
                  );
                },
              ),
              const SizedBox(height: 18),

              // 4. Prominent Circular SOS Button (Standalone, centered, not enclosed in a card)
              SosButton(
                isBroadcasting: meshStatus.isBroadcastingSOS,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SosScreen()),
                  );
                },
              ),
              const SizedBox(height: 18),

              // 5. Emergency Broadcast Feed (Live announcements with dividers + distinct send button)
              EmergencyBroadcastFeed(
                announcements: service.announcements,
                onSendBroadcast: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const BroadcastScreen()),
                  );
                },
              ),
              const SizedBox(height: 20),

              // Section Label: Communication & Contacts
              const Text(
                'COMMUNICATION & CONTACTS',
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: AppTheme.textMuted,
                ),
              ),
              const SizedBox(height: 8),

              // 6. Messages
              FeatureCard(
                title: 'Messages',
                subtitle: '${service.conversations.length} conversations • Store-and-forward active',
                icon: Icons.chat_bubble_outline_rounded,
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceSubtle,
                    borderRadius: BorderRadius.circular(AppTheme.radius),
                    border: Border.all(color: AppTheme.surfaceBorder),
                  ),
                  child: Text(
                    '${service.conversations.length}',
                    style: const TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const MessagesScreen()),
                  );
                },
              ),
              const SizedBox(height: 8),

              // 7. Family
              FeatureCard(
                title: 'Family',
                subtitle: '$reachableCount of ${service.familyMembers.length} reachable over mesh',
                icon: Icons.family_restroom_rounded,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppTheme.activeGreen,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: AppTheme.textMuted,
                      size: 20,
                    ),
                  ],
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const FamilyScreen()),
                  );
                },
              ),
              const SizedBox(height: 8),

              // 8. Nearby
              FeatureCard(
                title: 'Nearby',
                subtitle: '${meshStatus.nearbyCount} mesh peers detected in range',
                icon: Icons.radar_rounded,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const NearbyScreen()),
                  );
                },
              ),
              const SizedBox(height: 18),

              // 9. Small offline/P2P information footer
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceSubtle,
                  borderRadius: BorderRadius.circular(AppTheme.radius),
                  border: Border.all(color: AppTheme.surfaceBorder),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.wifi_off_rounded,
                      size: 14,
                      color: AppTheme.textMuted,
                    ),
                    SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'Decentralized P2P Mesh • Works without cellular coverage',
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.textSecondary,
                        ),
                        textAlign: TextAlign.center,
                      ),
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
