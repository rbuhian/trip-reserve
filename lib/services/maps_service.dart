import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../core/theme/app_colors.dart';
import '../models/booking.dart';

/// Service for maps and geocoding functionality
class MapsService {
  /// Convert address to coordinates (geocoding)
  ///
  /// Returns the first result or throws [MapsServiceException] if not found
  Future<LocationData> geocodeAddress(String address) async {
    try {
      final locations = await locationFromAddress(address);

      if (locations.isEmpty) {
        throw MapsServiceException(
          'No location found for this address',
          code: MapsErrorCode.noResults,
        );
      }

      final location = locations.first;
      return LocationData(
        address: address,
        lat: location.latitude,
        lng: location.longitude,
      );
    } catch (e) {
      if (e is MapsServiceException) rethrow;
      throw MapsServiceException(
        'Failed to geocode address: $e',
        code: MapsErrorCode.geocodingFailed,
      );
    }
  }

  /// Convert coordinates to address (reverse geocoding)
  ///
  /// Returns the formatted address or throws [MapsServiceException]
  Future<LocationData> reverseGeocode(double lat, double lng) async {
    try {
      final placemarks = await placemarkFromCoordinates(lat, lng);

      if (placemarks.isEmpty) {
        throw MapsServiceException(
          'No address found for this location',
          code: MapsErrorCode.noResults,
        );
      }

      final place = placemarks.first;
      final address = _formatPlacemark(place);

      return LocationData(
        address: address,
        lat: lat,
        lng: lng,
      );
    } catch (e) {
      if (e is MapsServiceException) rethrow;
      throw MapsServiceException(
        'Failed to reverse geocode: $e',
        code: MapsErrorCode.geocodingFailed,
      );
    }
  }

  /// Format a placemark into a readable address
  String _formatPlacemark(Placemark place) {
    final parts = <String>[];

    // Street number and name
    if (place.street != null && place.street!.isNotEmpty) {
      parts.add(place.street!);
    }

    // Sublocality (barangay in Philippines)
    if (place.subLocality != null && place.subLocality!.isNotEmpty) {
      parts.add(place.subLocality!);
    }

    // Locality (city)
    if (place.locality != null && place.locality!.isNotEmpty) {
      parts.add(place.locality!);
    }

    // Administrative area (province/region)
    if (place.administrativeArea != null && place.administrativeArea!.isNotEmpty) {
      parts.add(place.administrativeArea!);
    }

    return parts.join(', ');
  }

  /// Calculate the bounds that contain two points
  LatLngBounds boundsFromLocations(LocationData pickup, LocationData dropoff) {
    final south = pickup.lat < dropoff.lat ? pickup.lat : dropoff.lat;
    final north = pickup.lat > dropoff.lat ? pickup.lat : dropoff.lat;
    final west = pickup.lng < dropoff.lng ? pickup.lng : dropoff.lng;
    final east = pickup.lng > dropoff.lng ? pickup.lng : dropoff.lng;

    return LatLngBounds(
      southwest: LatLng(south, west),
      northeast: LatLng(north, east),
    );
  }

  /// Get map camera position centered on a location
  CameraPosition getCameraPosition(LocationData location, {double zoom = 15}) {
    return CameraPosition(
      target: LatLng(location.lat, location.lng),
      zoom: zoom,
    );
  }

  /// Get map camera position centered on coordinates
  CameraPosition getCameraPositionFromCoords(
    double lat,
    double lng, {
    double zoom = 15,
  }) {
    return CameraPosition(
      target: LatLng(lat, lng),
      zoom: zoom,
    );
  }

  /// Create a marker for pickup location
  Marker createPickupMarker(LocationData location, {VoidCallback? onTap}) {
    return Marker(
      markerId: const MarkerId('pickup'),
      position: LatLng(location.lat, location.lng),
      infoWindow: InfoWindow(
        title: 'Pickup',
        snippet: location.address,
      ),
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
      onTap: onTap,
    );
  }

  /// Create a marker for dropoff location
  Marker createDropoffMarker(LocationData location, {VoidCallback? onTap}) {
    return Marker(
      markerId: const MarkerId('dropoff'),
      position: LatLng(location.lat, location.lng),
      infoWindow: InfoWindow(
        title: 'Drop-off',
        snippet: location.address,
      ),
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      onTap: onTap,
    );
  }

  /// Create a marker for current location
  Marker createCurrentLocationMarker(double lat, double lng) {
    return Marker(
      markerId: const MarkerId('current_location'),
      position: LatLng(lat, lng),
      infoWindow: const InfoWindow(title: 'You are here'),
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
    );
  }

  /// Create a polyline between two points
  Polyline createRoutePolyline(
    LocationData pickup,
    LocationData dropoff, {
    List<LatLng>? routePoints,
  }) {
    final points = routePoints ??
        [
          LatLng(pickup.lat, pickup.lng),
          LatLng(dropoff.lat, dropoff.lng),
        ];

    return Polyline(
      polylineId: const PolylineId('route'),
      points: points,
      color: AppColors.primary,
      width: 4,
    );
  }
}

/// Error codes for maps service errors
enum MapsErrorCode {
  noResults,
  geocodingFailed,
  networkError,
  unknown,
}

/// Custom exception for maps errors
class MapsServiceException implements Exception {
  final String message;
  final MapsErrorCode code;

  MapsServiceException(this.message, {required this.code});

  @override
  String toString() => message;
}
