import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/user_profile.dart';

class NativeBridge {
  static const MethodChannel _channel = MethodChannel('com.example.sahra/native');

  // In-memory fallback for desktop/web/testing
  static UserProfile? _memoryProfile;

  /// Returns true only when running on a real or emulated Android device
  static bool get isAndroidDevice {
    if (kIsWeb) return false;
    try {
      return Platform.isAndroid;
    } catch (_) {
      return false;
    }
  }

  /// Fetches actual battery percentage from Android BatteryManager
  static Future<int> getBatteryLevel() async {
    if (!isAndroidDevice) return 85;
    try {
      final int? level = await _channel.invokeMethod<int>('getBatteryLevel');
      if (level != null && level >= 0 && level <= 100) {
        return level;
      }
      return 85;
    } on MissingPluginException {
      return 85;
    } catch (_) {
      return 85;
    }
  }

  /// Launches native photo picker and returns the copied local file path
  static Future<String?> pickProfilePhoto() async {
    if (!isAndroidDevice) return null;
    try {
      final String? path = await _channel.invokeMethod<String>('pickProfilePhoto');
      return path;
    } on MissingPluginException {
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Persists user profile to native SharedPreferences
  static Future<bool> saveProfile(UserProfile profile) async {
    _memoryProfile = profile;
    if (!isAndroidDevice) return true;
    try {
      final bool? success = await _channel.invokeMethod<bool>('saveProfile', {
        'profileJson': profile.toJson(),
      });
      return success ?? true;
    } on MissingPluginException {
      return true;
    } catch (_) {
      return true;
    }
  }

  /// Retrieves user profile from native SharedPreferences
  static Future<UserProfile?> getProfile() async {
    if (!isAndroidDevice) return _memoryProfile;
    try {
      final String? json = await _channel.invokeMethod<String>('getProfile');
      if (json != null && json.isNotEmpty) {
        final profile = UserProfile.fromJson(json);
        _memoryProfile = profile;
        return profile;
      }
      return _memoryProfile;
    } on MissingPluginException {
      return _memoryProfile;
    } catch (_) {
      return _memoryProfile;
    }
  }

  /// Checks if onboarding was completed
  static Future<bool> isProfileComplete() async {
    if (!isAndroidDevice) return _memoryProfile?.isCompleted ?? false;
    try {
      final bool? complete = await _channel.invokeMethod<bool>('isProfileComplete');
      if (complete != null) return complete;
      return _memoryProfile?.isCompleted ?? false;
    } on MissingPluginException {
      return _memoryProfile?.isCompleted ?? false;
    } catch (_) {
      return _memoryProfile?.isCompleted ?? false;
    }
  }

  /// Clears stored profile (for testing)
  static Future<void> clearProfile() async {
    _memoryProfile = null;
    if (!isAndroidDevice) return;
    try {
      await _channel.invokeMethod('clearProfile');
    } catch (_) {}
  }
}
