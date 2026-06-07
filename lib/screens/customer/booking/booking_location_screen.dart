import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../models/booking.dart';
import '../../../providers/location_provider.dart';
import '../../../widgets/place_autocomplete_field.dart';
import '../../../widgets/maps/trip_route_map.dart';

/// Screen for selecting pickup and dropoff locations
class BookingLocationScreen extends ConsumerStatefulWidget {
  const BookingLocationScreen({super.key});

  @override
  ConsumerState<BookingLocationScreen> createState() =>
      _BookingLocationScreenState();
}

class _BookingLocationScreenState
    extends ConsumerState<BookingLocationScreen> {
  @override
  Widget build(BuildContext context) {
    final locationState = ref.watch(locationSelectionProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Locations'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: Column(
        children: [
          // Location input section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: AppColors.shadow,
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                // Pickup field
                PlaceAutocompleteField(
                  locationType: LocationType.pickup,
                  initialValue: locationState.pickup,
                  hintText: 'Where to pick you up?',
                  onLocationSelected: (location) {
                    if (location.address.isNotEmpty) {
                      ref
                          .read(locationSelectionProvider.notifier)
                          .setPickupFromCoords(location.lat, location.lng);
                    } else {
                      ref.read(locationSelectionProvider.notifier).clearPickup();
                    }
                  },
                  onUseCurrentLocation: () {
                    ref
                        .read(locationSelectionProvider.notifier)
                        .setPickupToCurrentLocation();
                  },
                  onPickFromMap: () {
                    _openMapPicker(LocationType.pickup);
                  },
                ),

                const SizedBox(height: 8),

                // Swap button
                Row(
                  children: [
                    const Expanded(child: Divider()),
                    IconButton(
                      icon: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Icon(
                          Icons.swap_vert,
                          color: AppColors.primary,
                          size: 20,
                        ),
                      ),
                      onPressed: locationState.pickup != null ||
                              locationState.dropoff != null
                          ? () {
                              ref
                                  .read(locationSelectionProvider.notifier)
                                  .swapLocations();
                            }
                          : null,
                    ),
                    const Expanded(child: Divider()),
                  ],
                ),

                const SizedBox(height: 8),

                // Dropoff field
                PlaceAutocompleteField(
                  locationType: LocationType.dropoff,
                  initialValue: locationState.dropoff,
                  hintText: 'Where are you going?',
                  onLocationSelected: (location) {
                    if (location.address.isNotEmpty) {
                      ref
                          .read(locationSelectionProvider.notifier)
                          .setDropoffFromCoords(location.lat, location.lng);
                    } else {
                      ref
                          .read(locationSelectionProvider.notifier)
                          .clearDropoff();
                    }
                  },
                  onPickFromMap: () {
                    _openMapPicker(LocationType.dropoff);
                  },
                ),
              ],
            ),
          ),

          // Map preview / Trip info
          Expanded(
            child: locationState.isComplete
                ? _buildRoutePreview(locationState)
                : _buildEmptyState(),
          ),

          // Loading indicator
          if (locationState.isLoading)
            const LinearProgressIndicator(),

          // Error message
          if (locationState.error != null)
            Container(
              padding: const EdgeInsets.all(12),
              color: AppColors.errorLight,
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: AppColors.error, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      locationState.error!,
                      style: TextStyle(color: AppColors.error),
                    ),
                  ),
                ],
              ),
            ),

          // Continue button
          _buildBottomButton(locationState),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.location_on_outlined,
            size: 64,
            color: AppColors.textLight,
          ),
          const SizedBox(height: 16),
          Text(
            'Enter pickup and dropoff locations',
            style: TextStyle(
              color: AppColors.textMedium,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Search or pick from the map',
            style: TextStyle(
              color: AppColors.textLight,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoutePreview(LocationSelectionState state) {
    return Column(
      children: [
        // Map
        Expanded(
          child: TripRouteMap(
            pickup: state.pickup!,
            dropoff: state.dropoff!,
            routePoints: state.routePoints,
            showTripInfo: false,
            interactive: true,
          ),
        ),

        // Trip summary
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.white,
            border: Border(top: BorderSide(color: AppColors.divider)),
          ),
          child: Row(
            children: [
              // Distance
              Expanded(
                child: _buildInfoTile(
                  icon: Icons.straighten,
                  label: 'Distance',
                  value: '${state.distanceKm?.toStringAsFixed(1) ?? '--'} km',
                ),
              ),
              Container(
                width: 1,
                height: 40,
                color: AppColors.divider,
              ),
              // Estimated time (from route if available, otherwise rough estimate)
              Expanded(
                child: _buildInfoTile(
                  icon: Icons.access_time,
                  label: 'Est. Duration',
                  value: state.durationMinutes != null
                      ? _formatMinutes(state.durationMinutes!)
                      : _formatDuration(state.distanceKm),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        Icon(icon, color: AppColors.primary, size: 24),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: AppColors.textMedium,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            color: AppColors.textDark,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  String _formatDuration(double? distanceKm) {
    if (distanceKm == null) return '--';
    // Rough estimate: 30 km/h average in city traffic
    final minutes = (distanceKm / 30 * 60).round();
    return _formatMinutes(minutes, isEstimate: true);
  }

  String _formatMinutes(int minutes, {bool isEstimate = false}) {
    final prefix = isEstimate ? '~' : '';
    if (minutes < 60) {
      return '$prefix$minutes min';
    }
    final hours = minutes ~/ 60;
    final remainingMins = minutes % 60;
    if (remainingMins == 0) {
      return '$prefix${hours}h';
    }
    return '$prefix${hours}h ${remainingMins}m';
  }

  Widget _buildBottomButton(LocationSelectionState state) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: state.isComplete
                ? () {
                    context.push('/book/datetime');
                  }
                : null,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              disabledBackgroundColor: AppColors.disabled,
            ),
            child: const Text(
              'Continue',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ),
    );
  }

  void _openMapPicker(LocationType type) {
    // TODO: Navigate to full-screen map picker
    // For now, show a placeholder
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => _MapPickerSheet(
          locationType: type,
          onLocationSelected: (location) {
            if (type == LocationType.pickup) {
              ref
                  .read(locationSelectionProvider.notifier)
                  .setPickupFromCoords(location.lat, location.lng);
            } else {
              ref
                  .read(locationSelectionProvider.notifier)
                  .setDropoffFromCoords(location.lat, location.lng);
            }
            Navigator.pop(context);
          },
        ),
      ),
    );
  }
}

/// Map picker sheet
class _MapPickerSheet extends ConsumerWidget {
  final LocationType locationType;
  final ValueChanged<LocationData> onLocationSelected;

  const _MapPickerSheet({
    required this.locationType,
    required this.onLocationSelected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Title
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
                Expanded(
                  child: Text(
                    locationType == LocationType.pickup
                        ? 'Select Pickup Location'
                        : 'Select Dropoff Location',
                    style: Theme.of(context).textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(width: 48), // Balance the close button
              ],
            ),
          ),
          // Map placeholder - would use LocationPickerMap here
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.map_outlined,
                    size: 64,
                    color: AppColors.textLight,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Map picker coming soon',
                    style: TextStyle(color: AppColors.textMedium),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Use search for now',
                    style: TextStyle(
                      color: AppColors.textLight,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
