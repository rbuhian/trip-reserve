import 'dart:async';

import 'package:geolocator/geolocator.dart';

/// Service for handling device location
class LocationService {
  /// Check if location services are enabled
  Future<bool> isLocationServiceEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }

  /// Check current permission status
  Future<LocationPermission> checkPermission() async {
    return await Geolocator.checkPermission();
  }

  /// Request location permission
  Future<LocationPermission> requestPermission() async {
    return await Geolocator.requestPermission();
  }

  /// Get current position
  ///
  /// Throws [LocationServiceException] if location is unavailable or denied
  Future<Position> getCurrentPosition({
    LocationAccuracy accuracy = LocationAccuracy.high,
    Duration? timeout,
  }) async {
    // Check if location services are enabled
    final serviceEnabled = await isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw LocationServiceException(
        'Location services are disabled',
        code: LocationErrorCode.serviceDisabled,
      );
    }

    // Check permission
    var permission = await checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await requestPermission();
      if (permission == LocationPermission.denied) {
        throw LocationServiceException(
          'Location permission denied',
          code: LocationErrorCode.permissionDenied,
        );
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw LocationServiceException(
        'Location permission permanently denied. Please enable it in settings.',
        code: LocationErrorCode.permissionDeniedForever,
      );
    }

    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: accuracy,
        timeLimit: timeout ?? const Duration(seconds: 15),
      );
    } on TimeoutException {
      throw LocationServiceException(
        'Location request timed out',
        code: LocationErrorCode.timeout,
      );
    } catch (e) {
      throw LocationServiceException(
        'Failed to get location: $e',
        code: LocationErrorCode.unknown,
      );
    }
  }

  /// Get last known position (faster but may be stale)
  Future<Position?> getLastKnownPosition() async {
    return await Geolocator.getLastKnownPosition();
  }

  /// Stream of position updates
  ///
  /// Use for real-time tracking during trips
  Stream<Position> getPositionStream({
    LocationAccuracy accuracy = LocationAccuracy.high,
    int distanceFilter = 10, // meters
    Duration? interval,
  }) {
    final settings = LocationSettings(
      accuracy: accuracy,
      distanceFilter: distanceFilter,
    );

    return Geolocator.getPositionStream(locationSettings: settings);
  }

  /// Calculate distance between two points in meters
  double calculateDistance(
    double startLat,
    double startLng,
    double endLat,
    double endLng,
  ) {
    return Geolocator.distanceBetween(startLat, startLng, endLat, endLng);
  }

  /// Calculate bearing between two points in degrees
  double calculateBearing(
    double startLat,
    double startLng,
    double endLat,
    double endLng,
  ) {
    return Geolocator.bearingBetween(startLat, startLng, endLat, endLng);
  }

  /// Open device location settings
  Future<bool> openLocationSettings() async {
    return await Geolocator.openLocationSettings();
  }

  /// Open app settings (for permission management)
  Future<bool> openAppSettings() async {
    return await Geolocator.openAppSettings();
  }
}

/// Error codes for location service errors
enum LocationErrorCode {
  serviceDisabled,
  permissionDenied,
  permissionDeniedForever,
  timeout,
  unknown,
}

/// Custom exception for location errors
class LocationServiceException implements Exception {
  final String message;
  final LocationErrorCode code;

  LocationServiceException(this.message, {required this.code});

  @override
  String toString() => message;

  /// Whether the user should be prompted to open settings
  bool get shouldOpenSettings =>
      code == LocationErrorCode.serviceDisabled ||
      code == LocationErrorCode.permissionDeniedForever;
}
