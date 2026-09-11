import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding/onboarding_coordinator.dart';
import 'services/mock_service.dart';
import 'services/native_bridge.dart';
import 'services/service_scope.dart';
import 'theme/app_theme.dart';

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

  final mockService = MockService();
  final isProfileComplete = await NativeBridge.isProfileComplete();

  runApp(SaharaApp(
    mockService: mockService,
    initialIsOnboarded: isProfileComplete,
  ));
}

class SaharaApp extends StatelessWidget {
  final MockService mockService;
  final bool initialIsOnboarded;

  const SaharaApp({
    super.key,
    required this.mockService,
    this.initialIsOnboarded = false,
  });

  @override
  Widget build(BuildContext context) {
    return EmergencyServiceScope(
      service: mockService,
      child: MaterialApp(
        title: 'Sahara',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        home: initialIsOnboarded
            ? const HomeScreen()
            : const OnboardingCoordinator(),
      ),
    );
  }
}
