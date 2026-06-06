import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../core/theme/app_colors.dart';
import '../../models/booking.dart';
import '../../providers/location_provider.dart';

/// A map widget for displaying a trip route between pickup and dropoff
class TripRouteMap extends ConsumerStatefulWidget {
  /// Pickup location
  final LocationData pickup;

  /// Dropoff location
  final LocationData dropoff;

  /// Custom route points (optional, defaults to straight line)
  final List<LatLng>? routePoints;

  /// Whether to show distance/duration info overlay
  final bool showTripInfo;

  /// Map height
  final double? height;

  /// Whether to allow map interaction
  final bool interactive;

  /// Route line color
  final Color routeColor;

  /// Padding around the route bounds
  final double boundsPadding;

  const TripRouteMap({
    super.key,
    required this.pickup,
    required this.dropoff,
    this.routePoints,
    this.showTripInfo = true,
    this.height,
    this.interactive = true,
    this.routeColor = AppColors.primary,
    this.boundsPadding = 60,
  });

  @override
  ConsumerState<TripRouteMap> createState() => _TripRouteMapState();
}

class _TripRouteMapState extends ConsumerState<TripRouteMap> {
  GoogleMapController? _mapController;

  @override
  Widget build(BuildContext context) {
    final mapsService = ref.watch(mapsServiceProvider);
    final theme = Theme.of(context);

    // Create markers
    final markers = <Marker>{
      mapsService.createPickupMarker(widget.pickup),
      mapsService.createDropoffMarker(widget.dropoff),
    };

    // Create polyline
    final polylines = <Polyline>{
      Polyline(
        polylineId: const PolylineId('route'),
        points: widget.routePoints ??
            [
              LatLng(widget.pickup.lat, widget.pickup.lng),
              LatLng(widget.dropoff.lat, widget.dropoff.lng),
            ],
        color: widget.routeColor,
        width: 4,
      ),
    };

    // Calculate bounds
    final bounds = mapsService.boundsFromLocations(widget.pickup, widget.dropoff);

    // Calculate center
    final centerLat = (widget.pickup.lat + widget.dropoff.lat) / 2;
    final centerLng = (widget.pickup.lng + widget.dropoff.lng) / 2;

    return SizedBox(
      height: widget.height,
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: LatLng(centerLat, centerLng),
                zoom: 12,
              ),
              onMapCreated: (controller) {
                _mapController = controller;
                // Fit bounds after map is created
                Future.delayed(const Duration(milliseconds: 100), () {
                  controller.animateCamera(
                    CameraUpdate.newLatLngBounds(bounds, widget.boundsPadding),
                  );
                });
              },
              markers: markers,
              polylines: polylines,
              myLocationEnabled: false,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              mapToolbarEnabled: false,
              scrollGesturesEnabled: widget.interactive,
              zoomGesturesEnabled: widget.interactive,
              rotateGesturesEnabled: widget.interactive,
              tiltGesturesEnabled: widget.interactive,
            ),
          ),

          // Trip info overlay
          if (widget.showTripInfo)
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: _buildTripInfoCard(theme),
            ),

          // Zoom controls (if interactive)
          if (widget.interactive)
            Positioned(
              right: 12,
              top: 12,
              child: Column(
                children: [
                  _buildZoomButton(Icons.add, () {
                    _mapController?.animateCamera(CameraUpdate.zoomIn());
                  }),
                  const SizedBox(height: 4),
                  _buildZoomButton(Icons.remove, () {
                    _mapController?.animateCamera(CameraUpdate.zoomOut());
                  }),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTripInfoCard(ThemeData theme) {
    // Calculate distance using the provider
    final locationService = ref.read(locationServiceProvider);
    final distanceMeters = locationService.calculateDistance(
      widget.pickup.lat,
      widget.pickup.lng,
      widget.dropoff.lat,
      widget.dropoff.lng,
    );
    final distanceKm = distanceMeters / 1000;

    // Estimate duration (rough estimate: 30 km/h average speed)
    final durationMinutes = (distanceKm / 30 * 60).round();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: AppColors.textDark.withOpacity(0.1),
            blurRadius: 8,
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildLocationRow(
                  Icons.trip_origin,
                  AppColors.markerPickup,
                  widget.pickup.address,
                ),
                const SizedBox(height: 4),
                _buildLocationRow(
                  Icons.location_on,
                  AppColors.markerDropoff,
                  widget.dropoff.address,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${distanceKm.toStringAsFixed(1)} km',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '~$durationMinutes min',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLocationRow(IconData icon, Color color, String address) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            address,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    );
  }

  Widget _buildZoomButton(IconData icon, VoidCallback onPressed) {
    return Material(
      elevation: 2,
      borderRadius: BorderRadius.circular(4),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Icon(icon, size: 20),
        ),
      ),
    );
  }
}
