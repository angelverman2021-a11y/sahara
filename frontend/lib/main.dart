import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding/onboarding_coordinator.dart';
import 'services/emergency_service.dart';
import 'services/native_bridge.dart';
import 'services/sahara_emergency_service.dart';
import 'services/service_scope.dart';
import 'theme/app_theme.dart';

import 'screens/splash_screen.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set system UI overlay style for clean Indian utility aesthetic
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: AppTheme.surface,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  final emergencyService = SaharaEmergencyService();
  await emergencyService.initialize();
  final isProfileComplete = await NativeBridge.isProfileComplete();

  runApp(SaharaApp(
    emergencyService: emergencyService,
    initialIsOnboarded: isProfileComplete,
    showSplashScreen: true,
  ));
}

class SaharaApp extends StatefulWidget {
  final EmergencyService? emergencyService;
  final EmergencyService? mockService;
  final bool initialIsOnboarded;
  final bool? showSplashScreen;

  const SaharaApp({
    super.key,
    this.emergencyService,
    this.mockService,
    this.initialIsOnboarded = false,
    this.showSplashScreen,
  });

  @override
  State<SaharaApp> createState() => _SaharaAppState();
}

class _SaharaAppState extends State<SaharaApp> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    final activeService = widget.mockService ?? widget.emergencyService;
    if (activeService != null) {
      NotificationService().initialize(
        navigatorKey: _navigatorKey,
        emergencyService: activeService,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeService = widget.mockService ?? widget.emergencyService ?? SaharaEmergencyService();
    final shouldShowSplash = widget.showSplashScreen ?? false;

    return EmergencyServiceScope(
      service: activeService,
      child: MaterialApp(
        navigatorKey: _navigatorKey,
        title: 'Sahara',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        home: shouldShowSplash
            ? SplashScreen(
                mockService: activeService,
                initialIsOnboarded: widget.initialIsOnboarded,
              )
            : (widget.initialIsOnboarded
                ? const HomeScreen()
                : const OnboardingCoordinator()),
      ),
    );
  }
}

