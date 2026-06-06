import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../models/booking.dart';
import '../services/location_service.dart';
import '../services/maps_service.dart';

/// Provider for LocationService
final locationServiceProvider = Provider<LocationService>((ref) {
  return LocationService();
});

/// Provider for MapsService
final mapsServiceProvider = Provider<MapsService>((ref) {
  return MapsService();
});

/// Provider for current device position
///
/// Returns null if location is unavailable
final currentPositionProvider = FutureProvider<Position?>((ref) async {
  final locationService = ref.watch(locationServiceProvider);

  try {
    return await locationService.getCurrentPosition();
  } on LocationServiceException {
    return null;
  }
});

/// Provider for current position as LocationData (with address)
final currentLocationProvider = FutureProvider<LocationData?>((ref) async {
  final position = await ref.watch(currentPositionProvider.future);
  if (position == null) return null;

  final mapsService = ref.watch(mapsServiceProvider);

  try {
    return await mapsService.reverseGeocode(position.latitude, position.longitude);
  } on MapsServiceException {
    // Return location with coordinates only if reverse geocoding fails
    return LocationData(
      address: 'Current Location',
      lat: position.latitude,
      lng: position.longitude,
    );
  }
});

/// Provider for location permission status
final locationPermissionProvider = FutureProvider<LocationPermission>((ref) async {
  final locationService = ref.watch(locationServiceProvider);
  return await locationService.checkPermission();
});

/// Provider for checking if location services are enabled
final locationServiceEnabledProvider = FutureProvider<bool>((ref) async {
  final locationService = ref.watch(locationServiceProvider);
  return await locationService.isLocationServiceEnabled();
});

/// StateNotifier for managing pickup/dropoff location selection
class LocationSelectionNotifier extends StateNotifier<LocationSelectionState> {
  final MapsService _mapsService;
  final LocationService _locationService;

  LocationSelectionNotifier(this._mapsService, this._locationService)
      : super(const LocationSelectionState());

  /// Set pickup location from address
  Future<void> setPickupFromAddress(String address) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final location = await _mapsService.geocodeAddress(address);
      state = state.copyWith(pickup: location, isLoading: false);
    } on MapsServiceException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
    }
  }

  /// Set pickup location from coordinates
  Future<void> setPickupFromCoords(double lat, double lng) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final location = await _mapsService.reverseGeocode(lat, lng);
      state = state.copyWith(pickup: location, isLoading: false);
    } on MapsServiceException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
    }
  }

  /// Set pickup to current device location
  Future<void> setPickupToCurrentLocation() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final position = await _locationService.getCurrentPosition();
      final location = await _mapsService.reverseGeocode(
        position.latitude,
        position.longitude,
      );
      state = state.copyWith(pickup: location, isLoading: false);
    } on LocationServiceException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
    } on MapsServiceException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
    }
  }

  /// Set dropoff location from address
  Future<void> setDropoffFromAddress(String address) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final location = await _mapsService.geocodeAddress(address);
      state = state.copyWith(dropoff: location, isLoading: false);
    } on MapsServiceException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
    }
  }

  /// Set dropoff location from coordinates
  Future<void> setDropoffFromCoords(double lat, double lng) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final location = await _mapsService.reverseGeocode(lat, lng);
      state = state.copyWith(dropoff: location, isLoading: false);
    } on MapsServiceException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
    }
  }

  /// Clear pickup location
  void clearPickup() {
    state = state.copyWith(pickup: null);
  }

  /// Clear dropoff location
  void clearDropoff() {
    state = state.copyWith(dropoff: null);
  }

  /// Clear all locations
  void clearAll() {
    state = const LocationSelectionState();
  }

  /// Swap pickup and dropoff
  void swapLocations() {
    state = state.copyWith(
      pickup: state.dropoff,
      dropoff: state.pickup,
    );
  }
}

/// State for location selection
class LocationSelectionState {
  final LocationData? pickup;
  final LocationData? dropoff;
  final bool isLoading;
  final String? error;

  const LocationSelectionState({
    this.pickup,
    this.dropoff,
    this.isLoading = false,
    this.error,
  });

  LocationSelectionState copyWith({
    LocationData? pickup,
    LocationData? dropoff,
    bool? isLoading,
    String? error,
  }) {
    return LocationSelectionState(
      pickup: pickup ?? this.pickup,
      dropoff: dropoff ?? this.dropoff,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  /// Check if both locations are set
  bool get isComplete => pickup != null && dropoff != null;

  /// Calculate distance in kilometers (if both locations set)
  double? get distanceKm {
    if (!isComplete) return null;
    final meters = Geolocator.distanceBetween(
      pickup!.lat,
      pickup!.lng,
      dropoff!.lat,
      dropoff!.lng,
    );
    return meters / 1000;
  }
}

/// Provider for location selection state
final locationSelectionProvider =
    StateNotifierProvider<LocationSelectionNotifier, LocationSelectionState>(
  (ref) {
    final mapsService = ref.watch(mapsServiceProvider);
    final locationService = ref.watch(locationServiceProvider);
    return LocationSelectionNotifier(mapsService, locationService);
  },
);
