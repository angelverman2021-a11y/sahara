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

  /// Checks if required Bluetooth & Location runtime permissions are granted
  static Future<bool> checkBluetoothPermissions() async {
    if (!isAndroidDevice) return true;
    try {
      final bool? granted = await _channel.invokeMethod<bool>('checkBluetoothPermissions');
      return granted ?? false;
    } on MissingPluginException {
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Requests required Bluetooth & Location runtime permissions
  static Future<bool> requestBluetoothPermissions() async {
    if (!isAndroidDevice) return true;
    try {
      final bool? granted = await _channel.invokeMethod<bool>('requestBluetoothPermissions');
      return granted ?? false;
    } on MissingPluginException {
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Checks if device Bluetooth hardware is currently enabled
  static Future<bool> isBluetoothEnabled() async {
    if (!isAndroidDevice) return true;
    try {
      final bool? enabled = await _channel.invokeMethod<bool>('isBluetoothEnabled');
      return enabled ?? false;
    } on MissingPluginException {
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Prompts user to enable Bluetooth
  static Future<bool> enableBluetooth() async {
    if (!isAndroidDevice) return true;
    try {
      final bool? success = await _channel.invokeMethod<bool>('enableBluetooth');
      return success ?? false;
    } on MissingPluginException {
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Checks if device location services (GPS/Network) are active
  static Future<bool> isLocationEnabled() async {
    if (!isAndroidDevice) return true;
    try {
      final bool? enabled = await _channel.invokeMethod<bool>('isLocationEnabled');
      return enabled ?? false;
    } on MissingPluginException {
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Starts the Android Foreground Service for maintaining Bluetooth mesh execution while locked
  static Future<bool> startMeshForegroundService() async {
    if (!isAndroidDevice) return true;
    try {
      final bool? success = await _channel.invokeMethod<bool>('startMeshForegroundService');
      return success ?? true;
    } catch (_) {
      return false;
    }
  }

  /// Stops the Android Foreground Service
  static Future<bool> stopMeshForegroundService() async {
    if (!isAndroidDevice) return true;
    try {
      final bool? success = await _channel.invokeMethod<bool>('stopMeshForegroundService');
      return success ?? true;
    } catch (_) {
      return false;
    }
  }

  /// Checks if device screen is currently turned off or non-interactive
  static Future<bool> isScreenOff() async {
    if (!isAndroidDevice) return false;
    try {
      final bool? isOff = await _channel.invokeMethod<bool>('isScreenOff');
      return isOff ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Checks if device is currently locked
  static Future<bool> isDeviceLocked() async {
    if (!isAndroidDevice) return false;
    try {
      final bool? locked = await _channel.invokeMethod<bool>('isDeviceLocked');
      return locked ?? false;
    } catch (_) {
      return false;
    }
  }
}
