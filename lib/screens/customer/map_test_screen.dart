import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../models/booking.dart';
import '../../providers/location_provider.dart';
import '../../widgets/maps/maps.dart';

/// Temporary screen to test Google Maps integration
class MapTestScreen extends ConsumerWidget {
  const MapTestScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final locationSelection = ref.watch(locationSelectionProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Map Test'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Current location status
            _buildSection(
              context,
              title: 'Current Location',
              child: _buildCurrentLocationCard(ref, colorScheme),
            ),

            const SizedBox(height: 24),

            // Pickup search
            _buildSection(
              context,
              title: 'Pickup Location',
              child: LocationSearchField(
                hint: 'Enter pickup address',
                prefixIcon: Icons.trip_origin,
                prefixIconColor: AppColors.markerPickup,
                value: locationSelection.pickup,
                onLocationSelected: (location) {
                  ref.read(locationSelectionProvider.notifier)
                      .setPickupFromCoords(location.lat, location.lng);
                },
                onClear: () {
                  ref.read(locationSelectionProvider.notifier).clearPickup();
                },
              ),
            ),

            const SizedBox(height: 16),

            // Dropoff search
            _buildSection(
              context,
              title: 'Dropoff Location',
              child: LocationSearchField(
                hint: 'Enter destination address',
                prefixIcon: Icons.location_on,
                prefixIconColor: AppColors.markerDropoff,
                value: locationSelection.dropoff,
                onLocationSelected: (location) {
                  ref.read(locationSelectionProvider.notifier)
                      .setDropoffFromCoords(location.lat, location.lng);
                },
                onClear: () {
                  ref.read(locationSelectionProvider.notifier).clearDropoff();
                },
              ),
            ),

            const SizedBox(height: 8),

            // Swap button
            if (locationSelection.pickup != null || locationSelection.dropoff != null)
              Center(
                child: TextButton.icon(
                  onPressed: () {
                    ref.read(locationSelectionProvider.notifier).swapLocations();
                  },
                  icon: const Icon(Icons.swap_vert),
                  label: const Text('Swap locations'),
                ),
              ),

            const SizedBox(height: 24),

            // Route map (if both locations selected)
            if (locationSelection.isComplete) ...[
              _buildSection(
                context,
                title: 'Route Preview',
                child: TripRouteMap(
                  pickup: locationSelection.pickup!,
                  dropoff: locationSelection.dropoff!,
                  height: 300,
                ),
              ),

              const SizedBox(height: 16),

              // Distance info
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildInfoItem(
                      context,
                      icon: Icons.straighten,
                      label: 'Distance',
                      value: '${locationSelection.distanceKm?.toStringAsFixed(1)} km',
                    ),
                    _buildInfoItem(
                      context,
                      icon: Icons.access_time,
                      label: 'Est. Time',
                      value: '~${((locationSelection.distanceKm ?? 0) / 30 * 60).round()} min',
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),

            // Pick on map button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _openMapPicker(context, ref),
                icon: const Icon(Icons.map),
                label: const Text('Pick Location on Map'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Use current location button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  ref.read(locationSelectionProvider.notifier)
                      .setPickupToCurrentLocation();
                },
                icon: const Icon(Icons.my_location),
                label: const Text('Set Pickup to Current Location'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(BuildContext context, {required String title, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }

  Widget _buildCurrentLocationCard(WidgetRef ref, ColorScheme colorScheme) {
    final currentLocation = ref.watch(currentLocationProvider);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.5)),
      ),
      child: currentLocation.when(
        data: (location) => Row(
          children: [
            Icon(Icons.my_location, color: colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    location?.address ?? 'Location unavailable',
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  if (location != null)
                    Text(
                      '${location.lat.toStringAsFixed(6)}, ${location.lng.toStringAsFixed(6)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
            Icon(
              location != null ? Icons.check_circle : Icons.error_outline,
              color: location != null ? AppColors.markerPickup : colorScheme.error,
            ),
          ],
        ),
        loading: () => Row(
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(width: 12),
            const Text('Getting current location...'),
          ],
        ),
        error: (error, _) => Row(
          children: [
            Icon(Icons.location_off, color: colorScheme.error),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Location error: $error',
                style: TextStyle(color: colorScheme.error),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        Icon(icon, color: colorScheme.primary),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Future<void> _openMapPicker(BuildContext context, WidgetRef ref) async {
    final result = await Navigator.push<LocationData>(
      context,
      MaterialPageRoute(
        builder: (context) => const _FullMapPickerScreen(),
      ),
    );

    if (result != null) {
      ref.read(locationSelectionProvider.notifier)
          .setDropoffFromCoords(result.lat, result.lng);
    }
  }
}

/// Full screen map picker
class _FullMapPickerScreen extends ConsumerWidget {
  const _FullMapPickerScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pick Location'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: LocationPickerMap(
        onLocationSelected: (location) {
          Navigator.pop(context, location);
        },
      ),
    );
  }
}
