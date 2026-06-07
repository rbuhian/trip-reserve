import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../models/booking.dart';
import '../../../models/enums.dart';
import '../../../repositories/booking_repository.dart';
import '../../../widgets/status_pill.dart';
import 'customer_bookings_screen.dart';

/// Provider for a single booking by ID
final bookingDetailsProvider = FutureProvider.family<Booking?, String>((ref, id) async {
  final repo = ref.watch(bookingRepositoryProvider);
  return repo.getById(id);
});

class BookingDetailsScreen extends ConsumerStatefulWidget {
  final String bookingId;

  const BookingDetailsScreen({super.key, required this.bookingId});

  @override
  ConsumerState<BookingDetailsScreen> createState() => _BookingDetailsScreenState();
}

class _BookingDetailsScreenState extends ConsumerState<BookingDetailsScreen> {
  bool _isCancelling = false;

  Future<void> _cancelBooking(Booking booking) async {
    // Show confirmation dialog
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => _CancelBookingDialog(booking: booking),
    );

    if (reason == null) return; // User cancelled

    setState(() => _isCancelling = true);

    try {
      final repo = ref.read(bookingRepositoryProvider);
      await repo.cancel(booking.id, reason: reason.isEmpty ? null : reason);

      // Refresh providers
      ref.invalidate(bookingDetailsProvider(widget.bookingId));
      ref.invalidate(upcomingBookingsProvider);
      ref.invalidate(pastBookingsProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Booking cancelled successfully'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isCancelling = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final bookingAsync = ref.watch(bookingDetailsProvider(widget.bookingId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Booking Details'),
        backgroundColor: colorScheme.surface,
        actions: [
          bookingAsync.whenOrNull(
            data: (booking) {
              if (booking == null) return null;
              return IconButton(
                icon: const Icon(Icons.copy),
                tooltip: 'Copy reference number',
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: booking.referenceNumber));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Reference number copied'),
                      behavior: SnackBarBehavior.floating,
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
              );
            },
          ) ?? const SizedBox(),
        ],
      ),
      body: bookingAsync.when(
        data: (booking) {
          if (booking == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 48, color: colorScheme.error),
                  const SizedBox(height: 16),
                  const Text('Booking not found'),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () => context.pop(),
                    child: const Text('Go back'),
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
                onPressed: () => ref.invalidate(bookingDetailsProvider(widget.bookingId)),
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

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Reference and Status
        _buildHeader(booking, colorScheme),

        const SizedBox(height: 24),

        // Date and Time
        _buildSection(
          colorScheme,
          title: 'Schedule',
          icon: Icons.calendar_today_outlined,
          child: _buildScheduleInfo(booking, colorScheme),
        ),

        const SizedBox(height: 16),

        // Route
        _buildSection(
          colorScheme,
          title: 'Route',
          icon: Icons.route,
          child: _buildRouteInfo(booking, colorScheme),
        ),

        const SizedBox(height: 16),

        // Driver and Vehicle
        if (booking.driver != null || booking.vehicle != null) ...[
          _buildSection(
            colorScheme,
            title: 'Driver & Vehicle',
            icon: Icons.directions_car_outlined,
            child: _buildDriverVehicleInfo(booking, colorScheme),
          ),
          const SizedBox(height: 16),
        ],

        // Price breakdown
        _buildSection(
          colorScheme,
          title: 'Price Details',
          icon: Icons.receipt_long_outlined,
          child: _buildPriceBreakdown(booking, colorScheme),
        ),

        const SizedBox(height: 16),

        // Trip details
        _buildSection(
          colorScheme,
          title: 'Trip Info',
          icon: Icons.info_outline,
          child: _buildTripInfo(booking, colorScheme),
        ),

        // Cancellation info
        if (booking.status == BookingStatus.cancelled &&
            booking.cancellationReason != null) ...[
          const SizedBox(height: 16),
          _buildSection(
            colorScheme,
            title: 'Cancellation',
            icon: Icons.cancel_outlined,
            child: _buildCancellationInfo(booking, colorScheme),
          ),
        ],

        const SizedBox(height: 32),

        // Cancel button
        if (booking.canCancel) ...[
          _buildCancellationDeadline(booking, colorScheme),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _isCancelling ? null : () => _cancelBooking(booking),
            icon: _isCancelling
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.cancel_outlined),
            label: Text(_isCancelling ? 'Cancelling...' : 'Cancel Booking'),
            style: OutlinedButton.styleFrom(
              foregroundColor: colorScheme.error,
              side: BorderSide(color: colorScheme.error.withOpacity(0.5)),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ],

        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildHeader(Booking booking, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Reference',
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    booking.referenceNumber,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: colorScheme.primary,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
              StatusPill(status: booking.status),
            ],
          ),
          if (booking.createdAt != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  Icons.access_time,
                  size: 14,
                  color: colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Text(
                  'Booked on ${DateFormat('MMM d, yyyy \'at\' h:mm a').format(booking.createdAt!)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSection(
    ColorScheme colorScheme, {
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.outlineVariant.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildScheduleInfo(Booking booking, ColorScheme colorScheme) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Date',
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                DateFormat('EEEE, MMMM d, yyyy').format(booking.scheduledDate),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: colorScheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            booking.pickupTime,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: colorScheme.primary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRouteInfo(Booking booking, ColorScheme colorScheme) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Icon(Icons.trip_origin, size: 16, color: AppColors.success),
            Container(
              width: 2,
              height: 32,
              margin: const EdgeInsets.symmetric(vertical: 4),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [AppColors.success, AppColors.error],
                ),
              ),
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
              const SizedBox(height: 16),
              Text(
                'Drop-off',
                style: TextStyle(
                  fontSize: 11,
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
    );
  }

  Widget _buildDriverVehicleInfo(Booking booking, ColorScheme colorScheme) {
    return Column(
      children: [
        if (booking.driver != null)
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: colorScheme.primary.withOpacity(0.1),
                backgroundImage: booking.driver!.avatarUrl != null
                    ? NetworkImage(booking.driver!.avatarUrl!)
                    : null,
                child: booking.driver!.avatarUrl == null
                    ? Text(
                        booking.driver!.fullName.isNotEmpty
                            ? booking.driver!.fullName[0].toUpperCase()
                            : '?',
                        style: TextStyle(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      booking.driver!.fullName,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    if (booking.driver!.phone != null)
                      Text(
                        booking.driver!.phone!,
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
        if (booking.driver != null && booking.vehicle != null)
          const SizedBox(height: 12),
        if (booking.vehicle != null)
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.directions_car,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      booking.vehicle!.name,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      booking.vehicle!.plateNumber,
                      style: TextStyle(
                        fontSize: 13,
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildPriceBreakdown(Booking booking, ColorScheme colorScheme) {
    return Column(
      children: [
        _priceRow('Base fare', booking.baseFare, colorScheme),
        const SizedBox(height: 8),
        _priceRow('Distance fee (${booking.distanceText})', booking.distanceFee, colorScheme),
        if (booking.addonsFee > 0) ...[
          const SizedBox(height: 8),
          _priceRow('Add-ons', booking.addonsFee, colorScheme),
        ],
        const SizedBox(height: 12),
        Divider(color: colorScheme.outlineVariant.withOpacity(0.5)),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Total',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: colorScheme.onSurface,
              ),
            ),
            Text(
              '₱${booking.totalAmount.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: colorScheme.primary,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _priceRow(String label, double amount, ColorScheme colorScheme) {
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
          '₱${amount.toStringAsFixed(2)}',
          style: TextStyle(
            fontSize: 14,
            color: colorScheme.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _buildTripInfo(Booking booking, ColorScheme colorScheme) {
    return Row(
      children: [
        Expanded(
          child: _infoItem(
            'Distance',
            booking.distanceText,
            Icons.straighten,
            colorScheme,
          ),
        ),
        Container(
          width: 1,
          height: 40,
          color: colorScheme.outlineVariant.withOpacity(0.5),
        ),
        Expanded(
          child: _infoItem(
            'Duration',
            booking.durationText,
            Icons.schedule,
            colorScheme,
          ),
        ),
      ],
    );
  }

  Widget _infoItem(String label, String value, IconData icon, ColorScheme colorScheme) {
    return Column(
      children: [
        Icon(icon, size: 20, color: colorScheme.onSurfaceVariant),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
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

  Widget _buildCancellationInfo(Booking booking, ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (booking.cancelledAt != null)
          Text(
            'Cancelled on ${DateFormat('MMM d, yyyy \'at\' h:mm a').format(booking.cancelledAt!)}',
            style: TextStyle(
              fontSize: 13,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        if (booking.cancellationReason != null) ...[
          const SizedBox(height: 8),
          Text(
            'Reason: ${booking.cancellationReason}',
            style: TextStyle(
              fontSize: 14,
              color: colorScheme.onSurface,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCancellationDeadline(Booking booking, ColorScheme colorScheme) {
    // Calculate deadline (e.g., 24 hours before pickup)
    final pickupDateTime = DateTime(
      booking.scheduledDate.year,
      booking.scheduledDate.month,
      booking.scheduledDate.day,
      int.parse(booking.pickupTime.split(':')[0]),
      int.parse(booking.pickupTime.split(':')[1].split(' ')[0]),
    );
    final deadline = pickupDateTime.subtract(const Duration(hours: 24));
    final now = DateTime.now();

    if (now.isAfter(deadline)) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.warning.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.warning.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Icon(Icons.warning_amber, size: 20, color: AppColors.warning),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Late cancellation may apply additional fees',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.warning,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 20, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Free cancellation until ${DateFormat('MMM d \'at\' h:mm a').format(deadline)}',
              style: TextStyle(
                fontSize: 13,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Dialog for cancelling a booking
class _CancelBookingDialog extends StatefulWidget {
  final Booking booking;

  const _CancelBookingDialog({required this.booking});

  @override
  State<_CancelBookingDialog> createState() => _CancelBookingDialogState();
}

class _CancelBookingDialogState extends State<_CancelBookingDialog> {
  final _reasonController = TextEditingController();
  String? _selectedReason;

  final _reasons = [
    'Change of plans',
    'Found alternative transportation',
    'Emergency',
    'Weather conditions',
    'Other',
  ];

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AlertDialog(
      title: const Text('Cancel Booking?'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to cancel booking ${widget.booking.referenceNumber}?',
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            Text(
              'Reason (optional)',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _reasons.map((reason) {
                final isSelected = _selectedReason == reason;
                return ChoiceChip(
                  label: Text(reason),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      _selectedReason = selected ? reason : null;
                      if (reason != 'Other') {
                        _reasonController.clear();
                      }
                    });
                  },
                );
              }).toList(),
            ),
            if (_selectedReason == 'Other') ...[
              const SizedBox(height: 12),
              TextField(
                controller: _reasonController,
                decoration: const InputDecoration(
                  hintText: 'Please specify...',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Keep Booking'),
        ),
        TextButton(
          onPressed: () {
            final reason = _selectedReason == 'Other'
                ? _reasonController.text.trim()
                : _selectedReason;
            Navigator.pop(context, reason ?? '');
          },
          style: TextButton.styleFrom(foregroundColor: colorScheme.error),
          child: const Text('Cancel Booking'),
        ),
      ],
    );
  }
}
