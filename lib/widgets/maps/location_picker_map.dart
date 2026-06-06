import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../core/theme/app_colors.dart';
import '../../models/booking.dart';
import '../../providers/location_provider.dart';
import '../../services/maps_service.dart';

/// A map widget for picking a single location
class LocationPickerMap extends ConsumerStatefulWidget {
  /// Initial center position
  final LatLng? initialPosition;

  /// Initial zoom level
  final double initialZoom;

  /// Callback when a location is selected
  final ValueChanged<LocationData>? onLocationSelected;

  /// Whether to show current location button
  final bool showMyLocationButton;

  /// Whether to center on current location initially
  final bool centerOnCurrentLocation;

  /// Custom marker icon (optional)
  final BitmapDescriptor? markerIcon;

  const LocationPickerMap({
    super.key,
    this.initialPosition,
    this.initialZoom = 15,
    this.onLocationSelected,
    this.showMyLocationButton = true,
    this.centerOnCurrentLocation = true,
    this.markerIcon,
  });

  @override
  ConsumerState<LocationPickerMap> createState() => _LocationPickerMapState();
}

class _LocationPickerMapState extends ConsumerState<LocationPickerMap> {
  GoogleMapController? _mapController;
  LatLng? _selectedPosition;
  bool _isLoading = false;

  // Default center: Cebu City, Philippines
  static const _defaultCenter = LatLng(10.3157, 123.8854);

  @override
  Widget build(BuildContext context) {
    final currentPosition = ref.watch(currentPositionProvider);
    final mapsService = ref.watch(mapsServiceProvider);

    // Determine initial camera position
    LatLng initialCenter = widget.initialPosition ?? _defaultCenter;
    if (widget.centerOnCurrentLocation) {
      currentPosition.whenData((position) {
        if (position != null) {
          initialCenter = LatLng(position.latitude, position.longitude);
        }
      });
    }

    return Stack(
      children: [
        GoogleMap(
          initialCameraPosition: CameraPosition(
            target: initialCenter,
            zoom: widget.initialZoom,
          ),
          onMapCreated: (controller) {
            _mapController = controller;
            // Move to current location if enabled
            if (widget.centerOnCurrentLocation) {
              currentPosition.whenData((position) {
                if (position != null) {
                  controller.animateCamera(
                    CameraUpdate.newLatLng(
                      LatLng(position.latitude, position.longitude),
                    ),
                  );
                }
              });
            }
          },
          onTap: (latLng) => _handleMapTap(latLng, mapsService),
          markers: _selectedPosition != null
              ? {
                  Marker(
                    markerId: const MarkerId('selected'),
                    position: _selectedPosition!,
                    icon: widget.markerIcon ??
                        BitmapDescriptor.defaultMarkerWithHue(
                          BitmapDescriptor.hueRed,
                        ),
                  ),
                }
              : {},
          myLocationEnabled: true,
          myLocationButtonEnabled: false, // We'll add our own
          zoomControlsEnabled: false,
          mapToolbarEnabled: false,
        ),

        // Center marker indicator
        Center(
          child: IgnorePointer(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.location_on,
                  size: 40,
                  color: Theme.of(context).colorScheme.primary,
                ),
                Container(
                  width: 4,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Loading indicator
        if (_isLoading)
          Container(
            color: AppColors.textDark.withOpacity(0.26),
            child: const Center(
              child: CircularProgressIndicator(),
            ),
          ),

        // My location button
        if (widget.showMyLocationButton)
          Positioned(
            right: 16,
            bottom: 100,
            child: FloatingActionButton.small(
              heroTag: 'my_location',
              onPressed: _goToCurrentLocation,
              child: const Icon(Icons.my_location),
            ),
          ),

        // Confirm button
        Positioned(
          left: 16,
          right: 16,
          bottom: 24,
          child: ElevatedButton.icon(
            onPressed: _isLoading ? null : _confirmCenterLocation,
            icon: const Icon(Icons.check),
            label: const Text('Confirm Location'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _handleMapTap(LatLng latLng, MapsService mapsService) async {
    setState(() {
      _selectedPosition = latLng;
      _isLoading = true;
    });

    try {
      final location = await mapsService.reverseGeocode(
        latLng.latitude,
        latLng.longitude,
      );
      widget.onLocationSelected?.call(location);
    } catch (e) {
      // Create location with coordinates only
      widget.onLocationSelected?.call(LocationData(
        address: '${latLng.latitude.toStringAsFixed(6)}, ${latLng.longitude.toStringAsFixed(6)}',
        lat: latLng.latitude,
        lng: latLng.longitude,
      ));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _confirmCenterLocation() async {
    if (_mapController == null) return;

    setState(() => _isLoading = true);

    try {
      final bounds = await _mapController!.getVisibleRegion();
      final centerLat = (bounds.northeast.latitude + bounds.southwest.latitude) / 2;
      final centerLng = (bounds.northeast.longitude + bounds.southwest.longitude) / 2;

      final mapsService = ref.read(mapsServiceProvider);
      final location = await mapsService.reverseGeocode(centerLat, centerLng);

      setState(() {
        _selectedPosition = LatLng(centerLat, centerLng);
      });

      widget.onLocationSelected?.call(location);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to get address: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _goToCurrentLocation() async {
    final currentPosition = await ref.read(currentPositionProvider.future);
    if (currentPosition != null && _mapController != null) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLng(
          LatLng(currentPosition.latitude, currentPosition.longitude),
        ),
      );
    }
  }
}
