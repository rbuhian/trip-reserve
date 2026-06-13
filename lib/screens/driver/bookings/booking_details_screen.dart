import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../../../models/booking.dart';
import '../../../models/enums.dart';
import '../../../models/vehicle.dart';
import '../../../providers/message_provider.dart';
import '../../../providers/vehicle_provider.dart';
import '../../../repositories/booking_repository.dart';
import '../../../widgets/status_pill.dart';
import '../../../widgets/trip_lifecycle_stepper.dart';
import 'bookings_list_screen.dart';

/// Provider for driver booking details
final driverBookingDetailsProvider = FutureProvider.autoDispose.family<Booking?, String>((ref, id) async {
  final repo = ref.watch(bookingRepositoryProvider);
  return repo.getById(id);
});

/// Driver's view of booking details with actions
class DriverBookingDetailsScreen extends ConsumerStatefulWidget {
  final String bookingId;

  const DriverBookingDetailsScreen({super.key, required this.bookingId});

  @override
  ConsumerState<DriverBookingDetailsScreen> createState() => _DriverBookingDetailsScreenState();
}

class _DriverBookingDetailsScreenState extends ConsumerState<DriverBookingDetailsScreen> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final bookingAsync = ref.watch(driverBookingDetailsProvider(widget.bookingId));
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Booking Details'),
      ),
      body: bookingAsync.when(
        data: (booking) {
          if (booking == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: colorScheme.error),
                  const SizedBox(height: 16),
                  const Text('Booking not found'),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () => context.pop(),
                    child: const Text('Go Back'),
                  ),
                ],
              ),
            );
          }

          return _buildContent(context, booking);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48, color: colorScheme.error),
              const SizedBox(height: 16),
              Text('Error: ${error.toString()}'),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => ref.invalidate(driverBookingDetailsProvider(widget.bookingId)),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, Booking booking) {
    final colorScheme = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header card with reference and status
          _buildHeaderCard(context, booking),

          const SizedBox(height: 20),

          // Trip lifecycle stepper
          TripLifecycleStepper(booking: booking),

          const SizedBox(height: 20),

          // Customer info card
          _buildCustomerCard(context, booking),

          const SizedBox(height: 20),

          // Schedule card
          _buildScheduleCard(context, booking),

          const SizedBox(height: 20),

          // Route card
          _buildRouteCard(context, booking),

          const SizedBox(height: 20),

          // Trip details card
          _buildTripDetailsCard(context, booking),

          const SizedBox(height: 20),

          // Price card
          _buildPriceCard(context, booking),

          // Action buttons based on status
          if (_shouldShowActions(booking)) ...[
            const SizedBox(height: 24),
            _buildActionButtons(context, booking),
          ],

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  bool _shouldShowActions(Booking booking) {
    return booking.status == BookingStatus.pending ||
        booking.status == BookingStatus.confirmed ||
        booking.status == BookingStatus.inProgress;
  }

  Widget _buildHeaderCard(BuildContext context, Booking booking) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colorScheme.primary,
            colorScheme.primary.withOpacity(0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                booking.referenceNumber,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: 1,
                ),
              ),
              StatusPill(
                status: booking.status,
                fontSize: 12,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Booked on ${DateFormat('MMM d, yyyy').format(booking.createdAt ?? DateTime.now())}',
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerCard(BuildContext context, Booking booking) {
    final colorScheme = Theme.of(context).colorScheme;
    final customer = booking.customer;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.person_outline, size: 18, color: colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                'Customer',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: colorScheme.primary.withOpacity(0.1),
                backgroundImage: customer?.avatarUrl != null
                    ? NetworkImage(customer!.avatarUrl!)
                    : null,
                child: customer?.avatarUrl == null
                    ? Text(
                        _getInitials(customer?.fullName ?? 'NA'),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.primary,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      customer?.fullName ?? 'Unknown Customer',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    if (customer?.phone != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        customer!.phone!,
                        style: TextStyle(
                          fontSize: 14,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              // Call button
              if (customer?.phone != null)
                IconButton(
                  onPressed: () => _callCustomer(customer!.phone!),
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.success.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.phone, color: AppColors.success, size: 20),
                  ),
                ),
            ],
          ),
          if (_canMessage(booking)) ...[
            const SizedBox(height: 16),
            _buildMessageButton(booking),
          ],
        ],
      ),
    );
  }

  /// A message thread is available once the trip is in a messageable state
  /// (confirmed / in progress / completed) and the customer exists.
  bool _canMessage(Booking booking) {
    const messageable = {
      BookingStatus.confirmed,
      BookingStatus.inProgress,
      BookingStatus.completed,
    };
    return booking.customer != null && messageable.contains(booking.status);
  }

  Widget _buildMessageButton(Booking booking) {
    final colorScheme = Theme.of(context).colorScheme;
    final unread = ref.watch(unreadCountsProvider).valueOrNull ?? const {};
    final unreadCount = unread[booking.id] ?? 0;

    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () => context.push(
          '/driver/bookings/${booking.id}/chat',
          extra: booking.customer?.fullName,
        ),
        icon: const Icon(Icons.chat_bubble_outline, size: 18),
        label: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Message customer'),
            if (unreadCount > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  unreadCount > 99 ? '99+' : '$unreadCount',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.white,
                  ),
                ),
              ),
            ],
          ],
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: colorScheme.primary,
          side: BorderSide(color: colorScheme.primary.withOpacity(0.4)),
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  Widget _buildScheduleCard(BuildContext context, Booking booking) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.calendar_today_outlined, size: 18, color: colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                'Schedule',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildScheduleItem(
                  context,
                  icon: Icons.event,
                  label: 'Date',
                  value: _formatDate(booking.scheduledDate),
                ),
              ),
              Container(
                width: 1,
                height: 40,
                color: colorScheme.outlineVariant.withOpacity(0.3),
              ),
              Expanded(
                child: _buildScheduleItem(
                  context,
                  icon: Icons.access_time,
                  label: 'Pickup Time',
                  value: booking.pickupTime,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        children: [
          Icon(icon, size: 24, color: colorScheme.onSurfaceVariant),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRouteCard(BuildContext context, Booking booking) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.route, size: 18, color: colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                'Route',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.primary,
                ),
              ),
              const Spacer(),
              // Navigate button
              TextButton.icon(
                onPressed: () => _openNavigation(booking),
                icon: const Icon(Icons.navigation, size: 16),
                label: const Text('Navigate'),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  Icon(Icons.trip_origin, size: 16, color: AppColors.success),
                  Container(
                    width: 2,
                    height: 40,
                    color: colorScheme.outlineVariant,
                  ),
                  Icon(Icons.location_on, size: 16, color: AppColors.error),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pickup',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      booking.pickupAddress,
                      style: TextStyle(
                        fontSize: 14,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Dropoff',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      booking.dropoffAddress,
                      style: TextStyle(
                        fontSize: 14,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTripDetailsCard(BuildContext context, Booking booking) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, size: 18, color: colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                'Trip Details',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Category and bags info
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: _getCategoryColor(booking.category).withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _getCategoryColor(booking.category).withOpacity(0.2),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _getCategoryIcon(booking.category),
                  size: 20,
                  color: _getCategoryColor(booking.category),
                ),
                const SizedBox(width: 8),
                Text(
                  booking.category.displayName,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _getCategoryColor(booking.category),
                  ),
                ),
                const Spacer(),
                Icon(
                  Icons.luggage,
                  size: 16,
                  color: colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Text(
                  '${booking.numBags} bag${booking.numBags != 1 ? 's' : ''}',
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),

          // Additional info if present
          if (booking.additionalInfo != null && booking.additionalInfo!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.note_alt_outlined,
                        size: 16,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Customer Notes',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    booking.additionalInfo!,
                    style: TextStyle(
                      fontSize: 14,
                      fontStyle: FontStyle.italic,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildDetailItem(
                  context,
                  icon: Icons.straighten,
                  label: 'Distance',
                  value: booking.distanceText,
                ),
              ),
              Expanded(
                child: _buildDetailItem(
                  context,
                  icon: Icons.timer_outlined,
                  label: 'Est. Duration',
                  value: booking.durationText,
                ),
              ),
            ],
          ),
          if (booking.vehicle != null) ...[
            const SizedBox(height: 16),
            Divider(color: colorScheme.outlineVariant.withOpacity(0.3)),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(Icons.directions_car_outlined, size: 20, color: colorScheme.onSurfaceVariant),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        booking.vehicle!.name,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      Text(
                        booking.vehicle!.plateNumber,
                        style: TextStyle(
                          fontSize: 13,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  IconData _getCategoryIcon(VehicleCategory category) {
    switch (category) {
      case VehicleCategory.sedan:
        return Icons.directions_car;
      case VehicleCategory.mpvSuv:
        return Icons.airport_shuttle;
      case VehicleCategory.van:
        return Icons.directions_bus;
    }
  }

  Color _getCategoryColor(VehicleCategory category) {
    switch (category) {
      case VehicleCategory.sedan:
        return AppColors.primary;
      case VehicleCategory.mpvSuv:
        return AppColors.primaryLight;
      case VehicleCategory.van:
        return AppColors.success;
    }
  }

  Widget _buildDetailItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        Icon(icon, size: 20, color: colorScheme.onSurfaceVariant),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPriceCard(BuildContext context, Booking booking) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.payments_outlined, size: 18, color: colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                'Fare',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildPriceRow(context, 'Base Fare', booking.baseFare),
          const SizedBox(height: 8),
          _buildPriceRow(context, 'Distance Fee', booking.distanceFee),
          if (booking.addonsFee > 0) ...[
            const SizedBox(height: 8),
            _buildPriceRow(context, 'Add-ons', booking.addonsFee),
          ],
          const SizedBox(height: 12),
          Divider(color: colorScheme.outlineVariant.withOpacity(0.3)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
              ),
              Text(
                '₱${booking.totalAmount.toStringAsFixed(0)}',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: colorScheme.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPriceRow(BuildContext context, String label, double amount) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        Text(
          '₱${amount.toStringAsFixed(0)}',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: colorScheme.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context, Booking booking) {
    final colorScheme = Theme.of(context).colorScheme;

    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: CircularProgressIndicator(),
        ),
      );
    }

    switch (booking.status) {
      case BookingStatus.pending:
        return SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () => _showAcceptDialog(booking),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.success,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: const Text('Accept'),
          ),
        );

      case BookingStatus.confirmed:
        return SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () => _startTrip(booking),
            icon: const Icon(Icons.play_arrow),
            label: const Text('Start Trip'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        );

      case BookingStatus.inProgress:
        return SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () => _completeTrip(booking),
            icon: const Icon(Icons.check_circle_outline),
            label: const Text('Complete Trip'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.success,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        );

      default:
        return const SizedBox.shrink();
    }
  }

  Future<void> _showAcceptDialog(Booking booking) async {
    final vehicles = await ref.read(myVehiclesProvider.future);
    // Filter to active vehicles that can accept the booking's category
    final eligibleVehicles = vehicles
        .where((v) => v.isActive && v.category.canAcceptCategory(booking.category))
        .toList();

    if (!mounted) return;

    if (eligibleVehicles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'You need an active ${booking.category.displayName} or larger vehicle to accept this booking',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    Vehicle? selectedVehicle = eligibleVehicles.first;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Accept Booking'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _getCategoryIcon(booking.category),
                      size: 16,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Category: ${booking.category.displayName}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text('Select vehicle for this trip:'),
              const SizedBox(height: 8),
              ...eligibleVehicles.map((vehicle) => RadioListTile<Vehicle>(
                    title: Text(vehicle.name),
                    subtitle: Text('${vehicle.plateNumber} • ${vehicle.category.displayName}'),
                    value: vehicle,
                    groupValue: selectedVehicle,
                    onChanged: (v) => setDialogState(() => selectedVehicle = v),
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  )),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Accept'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true && selectedVehicle != null) {
      await _acceptBooking(booking.id, selectedVehicle!.id);
    }
  }

  Future<void> _acceptBooking(String bookingId, String vehicleId) async {
    setState(() => _isLoading = true);

    try {
      final repo = ref.read(bookingRepositoryProvider);
      await repo.accept(bookingId, vehicleId: vehicleId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Booking accepted'),
            backgroundColor: Colors.green,
          ),
        );
        ref.invalidate(driverBookingDetailsProvider(widget.bookingId));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _startTrip(Booking booking) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Start Trip'),
        content: const Text(
          'Start this trip?\n\n'
          'Make sure you have picked up the customer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Start'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isLoading = true);

      try {
        final repo = ref.read(bookingRepositoryProvider);
        await repo.startTrip(booking.id);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Trip started'),
              backgroundColor: Colors.green,
            ),
          );
          ref.invalidate(driverBookingDetailsProvider(widget.bookingId));
          ref.invalidate(pendingRequestsProvider);
          ref.invalidate(driverUpcomingProvider);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  Future<void> _completeTrip(Booking booking) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Complete Trip'),
        content: const Text(
          'Mark this trip as completed?\n\n'
          'Make sure the customer has reached their destination.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.success),
            child: const Text('Complete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isLoading = true);

      try {
        final repo = ref.read(bookingRepositoryProvider);
        await repo.completeTrip(booking.id);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Trip completed!'),
              backgroundColor: Colors.green,
            ),
          );
          ref.invalidate(driverBookingDetailsProvider(widget.bookingId));
          ref.invalidate(driverUpcomingProvider);
          ref.invalidate(driverHistoryProvider);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  Future<void> _callCustomer(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _openNavigation(Booking booking) async {
    // Open Google Maps with directions
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1'
      '&origin=${booking.pickupLat},${booking.pickupLng}'
      '&destination=${booking.dropoffLat},${booking.dropoffLng}'
      '&travelmode=driving',
    );

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final bookingDate = DateTime(date.year, date.month, date.day);

    if (bookingDate == today) {
      return 'Today';
    } else if (bookingDate == tomorrow) {
      return 'Tomorrow';
    } else {
      return DateFormat('EEE, MMM d, yyyy').format(date);
    }
  }

  String _getInitials(String name) {
    final parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return parts[0].substring(0, parts[0].length.clamp(0, 2)).toUpperCase();
  }
}
