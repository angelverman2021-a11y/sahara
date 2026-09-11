import 'dart:async';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

enum LocationResultStatus {
  success,
  serviceDisabled,
  permissionDenied,
  permissionDeniedForever,
  timeout,
  error,
}

class LocationResult {
  final LocationResultStatus status;
  final Position? position;
  final String? readableAddress;
  final String formattedCoordinates;
  final String? errorMessage;

  const LocationResult({
    required this.status,
    this.position,
    this.readableAddress,
    this.formattedCoordinates = '',
    this.errorMessage,
  });

  bool get isSuccess => status == LocationResultStatus.success && position != null;

  String get displayText {
    if (readableAddress != null && readableAddress!.isNotEmpty) {
      return '$readableAddress ($formattedCoordinates)';
    }
    return formattedCoordinates;
  }
}

class LocationHelper {
  /// Check if location services are enabled on the device
  static Future<bool> isServiceEnabled() async {
    try {
      return await Geolocator.isLocationServiceEnabled();
    } catch (_) {
      return false;
    }
  }

  /// Check current app location permission
  static Future<LocationPermission> checkPermission() async {
    try {
      return await Geolocator.checkPermission();
    } catch (_) {
      return LocationPermission.denied;
    }
  }

  /// Request app location permission
  static Future<LocationPermission> requestPermission() async {
    try {
      return await Geolocator.requestPermission();
    } catch (_) {
      return LocationPermission.denied;
    }
  }

  /// Opens Android system Location Settings so user can toggle GPS on
  static Future<bool> openLocationSettings() async {
    try {
      return await Geolocator.openLocationSettings();
    } catch (_) {
      return false;
    }
  }

  /// Opens Android system App Settings for Sahara so user can grant permissions
  static Future<bool> openAppSettings() async {
    try {
      return await Geolocator.openAppSettings();
    } catch (_) {
      return false;
    }
  }

  /// Cleanly format latitude and longitude with N/S, E/W
  static String formatCoordinates(double lat, double lon, [double? accuracy]) {
    final latDir = lat >= 0 ? 'N' : 'S';
    final lonDir = lon >= 0 ? 'E' : 'W';
    final latFormatted = '${lat.abs().toStringAsFixed(4)}° $latDir';
    final lonFormatted = '${lon.abs().toStringAsFixed(4)}° $lonDir';
    if (accuracy != null && accuracy > 0) {
      return '$latFormatted, $lonFormatted (±${accuracy.toStringAsFixed(0)}m)';
    }
    return '$latFormatted, $lonFormatted';
  }

  /// Obtain current location on-demand.
  /// Does NOT run background tracking.
  static Future<LocationResult> getCurrentOnDemandLocation({
    Duration timeout = const Duration(seconds: 12),
  }) async {
    // 1. Verify Location Service
    final serviceEnabled = await isServiceEnabled();
    if (!serviceEnabled) {
      return const LocationResult(
        status: LocationResultStatus.serviceDisabled,
        errorMessage: 'Location services are disabled on this device.',
      );
    }

    // 2. Verify Permission
    var permission = await checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await requestPermission();
      if (permission == LocationPermission.denied) {
        return const LocationResult(
          status: LocationResultStatus.permissionDenied,
          errorMessage: 'Location permission was denied.',
        );
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return const LocationResult(
        status: LocationResultStatus.permissionDeniedForever,
        errorMessage: 'Location permission is permanently denied in system settings.',
      );
    }

    // 3. Acquire Position
    Position? position;
    try {
      position = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: timeout,
        ),
      );
    } catch (_) {
      try {
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: Duration(seconds: 6),
          ),
        );
      } catch (_) {
        try {
          position = await Geolocator.getLastKnownPosition();
        } catch (_) {}
      }
    }

    if (position == null) {
      return const LocationResult(
        status: LocationResultStatus.timeout,
        errorMessage: 'Could not obtain a GPS fix. Please retry or enter location manually.',
      );
    }

    final coordsStr = formatCoordinates(position.latitude, position.longitude, position.accuracy);

    // 4. Reverse Geocode (graceful fallback if offline)
    String? address;
    try {
      final placemarks = await Geocoding().placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        final parts = [
          p.subLocality,
          p.locality,
          p.subAdministrativeArea,
          p.administrativeArea,
        ].where((s) => s != null && s.trim().isNotEmpty).toSet().toList();
        if (parts.isNotEmpty) {
          address = parts.join(', ');
        }
      }
    } catch (_) {
      address = null;
    }

    return LocationResult(
      status: LocationResultStatus.success,
      position: position,
      readableAddress: address,
      formattedCoordinates: coordsStr,
    );
  }
}
