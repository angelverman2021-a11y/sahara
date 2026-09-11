import 'package:flutter/material.dart';
import '../services/emergency_service.dart';
import '../services/native_bridge.dart';
import '../services/notification_service.dart';
import '../services/service_scope.dart';
import 'broadcast_screen.dart';
import 'chat_screen.dart';
import 'home_screen.dart';
import 'onboarding/onboarding_coordinator.dart';

/// Clean, minimal, official public-service splash screen with white background
/// and centered Sahara logo.
class SplashScreen extends StatefulWidget {
  final EmergencyService? mockService;
  final bool? initialIsOnboarded;

  const SplashScreen({
    super.key,
    this.mockService,
    this.initialIsOnboarded,
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // 1. Give splash a brief professional presence
    await Future.delayed(const Duration(milliseconds: 900));

    if (!mounted) return;

    final service = widget.mockService ?? EmergencyServiceScope.of(context);
    final isOnboarded = widget.initialIsOnboarded ?? (await NativeBridge.isProfileComplete());

    // 2. Check if launched from a notification intent
    final initialAction = await NotificationService().getInitialNotificationAction();

    if (!mounted) return;

    if (initialAction != null) {
      final action = initialAction['action'];
      if (action == 'open_broadcast') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => isOnboarded ? const HomeScreen() : const OnboardingCoordinator(),
          ),
        );
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const BroadcastScreen()),
        );
        return;
      } else if (action == 'open_chat') {
        final personId = initialAction['personId'];
        final person = service.allKnownPeople.firstWhere(
          (p) => p.id == personId,
          orElse: () => service.conversations.first,
        );
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => isOnboarded ? const HomeScreen() : const OnboardingCoordinator(),
          ),
        );
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ChatScreen(person: person)),
        );
        return;
      }
    }

    // 3. Normal navigation
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (ctx, a1, a2) => isOnboarded ? const HomeScreen() : const OnboardingCoordinator(),
        transitionsBuilder: (ctx, animation, secondaryAnimation, child) => FadeTransition(
          opacity: animation,
          child: child,
        ),
        transitionDuration: const Duration(milliseconds: 250),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Image.asset(
          'assets/images/sahara_logo.png',
          width: 220,
          fit: BoxFit.contain,
          semanticLabel: 'Sahara Emergency Network',
        ),
      ),
    );
  }
}
