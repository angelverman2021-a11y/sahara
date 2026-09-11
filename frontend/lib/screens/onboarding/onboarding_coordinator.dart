import 'package:flutter/material.dart';
import '../../models/user_profile.dart';
import '../../services/service_scope.dart';
import '../home_screen.dart';
import 'completion_screen.dart';
import 'emergency_contacts_screen.dart';
import 'language_screen.dart';
import 'personal_details_screen.dart';
import 'welcome_screen.dart';

class OnboardingCoordinator extends StatefulWidget {
  const OnboardingCoordinator({super.key});

  @override
  State<OnboardingCoordinator> createState() => _OnboardingCoordinatorState();
}

class _OnboardingCoordinatorState extends State<OnboardingCoordinator> {
  int _step = 0;
  UserProfile _profile = const UserProfile();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final service = EmergencyServiceScope.of(context);
      if (service.userProfile != null) {
        setState(() {
          _profile = service.userProfile!;
        });
      }
    });
  }

  void _nextStep() {
    if (_step < 4) {
      setState(() {
        _step++;
      });
    }
  }

  void _prevStep() {
    if (_step > 0) {
      setState(() {
        _step--;
      });
    }
  }

  Future<void> _finishOnboarding() async {
    final service = EmergencyServiceScope.of(context);
    final completedProfile = _profile.copyWith(isCompleted: true);
    await service.saveUserProfile(completedProfile);

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _step == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _step > 0) {
          _prevStep();
        }
      },
      child: _buildCurrentScreen(),
    );
  }

  Widget _buildCurrentScreen() {
    switch (_step) {
      case 0:
        return WelcomeScreen(
          onGetStarted: _nextStep,
        );
      case 1:
        return LanguageScreen(
          initialLanguage: _profile.language,
          onContinue: (language) {
            final service = EmergencyServiceScope.of(context);
            service.setLanguage(language);
            setState(() {
              _profile = _profile.copyWith(language: language);
            });
            _nextStep();
          },
        );
      case 2:
        return PersonalDetailsScreen(
          initialName: _profile.fullName,
          initialPhone: _profile.phoneNumber,
          initialDob: _profile.dateOfBirth,
          initialLocation: _profile.currentLocation,
          initialPhotoPath: _profile.photoPath,
          onContinue: ({
            required String name,
            required String phone,
            required String dob,
            required String location,
            String? photoPath,
          }) {
            setState(() {
              _profile = _profile.copyWith(
                fullName: name,
                phoneNumber: phone,
                dateOfBirth: dob,
                currentLocation: location,
                photoPath: photoPath,
              );
            });
            _nextStep();
          },
        );
      case 3:
        return EmergencyContactsScreen(
          initialContacts: _profile.emergencyContacts,
          onContinue: (contacts) {
            setState(() {
              _profile = _profile.copyWith(emergencyContacts: contacts);
            });
            _nextStep();
          },
        );
      case 4:
        return CompletionScreen(
          profile: _profile,
          onFinish: _finishOnboarding,
        );
      default:
        return const SizedBox.shrink();
    }
  }
}
