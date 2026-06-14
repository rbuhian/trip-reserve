import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../models/booking.dart';
import '../../../models/enums.dart';
import '../../../models/user.dart';
import '../../../repositories/admin_repository.dart';
import '../../../widgets/status_pill.dart';
import '../../../widgets/trip_lifecycle_stepper.dart';
import 'admin_bookings_screen.dart';

/// Provider for admin booking details
final adminBookingDetailsProvider = FutureProvider.family<Booking?, String>((ref, id) async {
  final repo = ref.watch(adminRepositoryProvider);
  return repo.getBookingById(id);
});

/// Provider for available drivers
final availableDriversProvider = FutureProvider<List<User>>((ref) async {
  final repo = ref.watch(adminRepositoryProvider);
  return repo.getAvailableDrivers();
});

/// Provider for available vehicles
final availableVehiclesProvider = FutureProvider<List<VehicleOption>>((ref) async {
  final repo = ref.watch(adminRepositoryProvider);
  return repo.getAvailableVehicles();
});

class AdminBookingDetailsScreen extends ConsumerStatefulWidget {
  final String bookingId;

  const AdminBookingDetailsScreen({super.key, required this.bookingId});

  @override
  ConsumerState<AdminBookingDetailsScreen> createState() => _AdminBookingDetailsScreenState();
}

class _AdminBookingDetailsScreenState extends ConsumerState<AdminBookingDetailsScreen> {
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final bookingAsync = ref.watch(adminBookingDetailsProvider(widget.bookingId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Booking Details'),
        backgroundColor: AppColors.primaryDark,
        foregroundColor: AppColors.white,
        actions: [
          bookingAsync.whenOrNull(
            data: (booking) {
              if (booking == null) return null;
              return PopupMenuButton<String>(
                onSelected: (value) => _handleMenuAction(value, booking),
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'copy',
                    child: Row(
                      children: [
                        Icon(Icons.copy, size: 18),
                        SizedBox(width: 8),
                        Text('Copy Reference'),
                      ],
                    ),
                  ),
                  if (booking.canCancel) ...[
                    const PopupMenuDivider(),
                    PopupMenuItem(
                      value: 'cancel',
                      child: Row(
                        children: [
                          Icon(Icons.cancel_outlined, size: 18, color: AppColors.error),
                          const SizedBox(width: 8),
                          Text('Cancel Booking', style: TextStyle(color: AppColors.error)),
                        ],
                      ),
                    ),
                  ],
                ],
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
                onPressed: () => ref.invalidate(adminBookingDetailsProvider(widget.bookingId)),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleMenuAction(String action, Booking booking) {
    switch (action) {
      case 'copy':
        Clipboard.setData(ClipboardData(text: booking.referenceNumber));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reference number copied')),
        );
        break;
      case 'cancel':
        _showCancelDialog(booking);
        break;
    }
  }

  Widget _buildContent(BuildContext context, Booking booking) {
    final colorScheme = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Reference and Status
        _buildHeader(booking, colorScheme),

        const SizedBox(height: 20),

        // Trip lifecycle stepper
        TripLifecycleStepper(booking: booking),

        const SizedBox(height: 20),

        // Schedule - Editable
        _buildEditableSection(
          colorScheme,
          title: 'Schedule',
          icon: Icons.calendar_today_outlined,
          onEdit: booking.status == BookingStatus.pending || booking.status == BookingStatus.confirmed
              ? () => _showEditScheduleDialog(booking)
              : null,
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

        // Customer Info
        _buildSection(
          colorScheme,
          title: 'Customer',
          icon: Icons.person_outline,
          child: _buildCustomerInfo(booking, colorScheme),
        ),

        const SizedBox(height: 16),

        // Driver & Vehicle - Editable
        _buildEditableSection(
          colorScheme,
          title: 'Driver & Vehicle',
          icon: Icons.directions_car_outlined,
          onEdit: booking.status != BookingStatus.completed && booking.status != BookingStatus.cancelled
              ? () => _showAssignDriverVehicleDialog(booking)
              : null,
          child: _buildDriverVehicleInfo(booking, colorScheme),
        ),

        const SizedBox(height: 16),

        // Status Management
        if (booking.status != BookingStatus.completed && booking.status != BookingStatus.cancelled) ...[
          _buildSection(
            colorScheme,
            title: 'Status Management',
            icon: Icons.swap_horiz,
            child: _buildStatusActions(booking, colorScheme),
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

        // Cancellation info
        if (booking.status == BookingStatus.cancelled) ...[
          const SizedBox(height: 16),
          _buildSection(
            colorScheme,
            title: 'Cancellation',
            icon: Icons.cancel_outlined,
            child: _buildCancellationInfo(booking, colorScheme),
          ),
        ],

        const SizedBox(height: 32),
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
                Icon(Icons.access_time, size: 14, color: colorScheme.onSurfaceVariant),
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
        border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.3)),
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

  Widget _buildEditableSection(
    ColorScheme colorScheme, {
    required String title,
    required IconData icon,
    required Widget child,
    VoidCallback? onEdit,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
              ),
              if (onEdit != null)
                IconButton(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  style: IconButton.styleFrom(
                    backgroundColor: colorScheme.primary.withOpacity(0.1),
                    foregroundColor: colorScheme.primary,
                    padding: const EdgeInsets.all(8),
                    minimumSize: const Size(32, 32),
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
              Text('Date', style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant)),
              const SizedBox(height: 4),
              Text(
                DateFormat('EEEE, MMMM d, yyyy').format(booking.scheduledDate),
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: colorScheme.onSurface),
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
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: colorScheme.primary),
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
              Text('Pickup', style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant)),
              const SizedBox(height: 2),
              Text(booking.pickupAddress, style: TextStyle(fontSize: 14, color: colorScheme.onSurface)),
              const SizedBox(height: 16),
              Text('Drop-off', style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant)),
              const SizedBox(height: 2),
              Text(booking.dropoffAddress, style: TextStyle(fontSize: 14, color: colorScheme.onSurface)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCustomerInfo(Booking booking, ColorScheme colorScheme) {
    if (booking.customer == null) {
      return Text('Customer info not available', style: TextStyle(color: colorScheme.onSurfaceVariant));
    }

    return Row(
      children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: colorScheme.primary.withOpacity(0.1),
          backgroundImage: booking.customer!.avatarUrl != null ? NetworkImage(booking.customer!.avatarUrl!) : null,
          child: booking.customer!.avatarUrl == null
              ? Text(
                  booking.customer!.fullName.isNotEmpty ? booking.customer!.fullName[0].toUpperCase() : '?',
                  style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.bold),
                )
              : null,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                booking.customer!.fullName,
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: colorScheme.onSurface),
              ),
              if (booking.customer!.phone != null)
                Text(
                  booking.customer!.phone!,
                  style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDriverVehicleInfo(Booking booking, ColorScheme colorScheme) {
    if (booking.driver == null && booking.vehicle == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline, size: 18, color: colorScheme.onSurfaceVariant),
            const SizedBox(width: 12),
            Text(
              'Not assigned yet',
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        if (booking.driver != null)
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: Colors.blue.withOpacity(0.1),
                child: const Icon(Icons.person, size: 18, color: Colors.blue),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(booking.driver!.fullName, style: const TextStyle(fontWeight: FontWeight.w500)),
                    if (booking.driver!.phone != null)
                      Text(booking.driver!.phone!, style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant)),
                  ],
                ),
              ),
            ],
          ),
        if (booking.driver != null && booking.vehicle != null) const SizedBox(height: 12),
        if (booking.vehicle != null)
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: Colors.teal.withOpacity(0.1),
                child: const Icon(Icons.directions_car, size: 18, color: Colors.teal),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(booking.vehicle!.name, style: const TextStyle(fontWeight: FontWeight.w500)),
                    Text(booking.vehicle!.plateNumber, style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant)),
                  ],
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildStatusActions(Booking booking, ColorScheme colorScheme) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (booking.status == BookingStatus.pending)
          _statusActionButton(
            'Confirm',
            Icons.check_circle_outline,
            AppColors.success,
            () => _updateStatus(booking, BookingStatus.confirmed),
          ),
        if (booking.status == BookingStatus.confirmed)
          _statusActionButton(
            'Start Trip',
            Icons.play_circle_outline,
            Colors.blue,
            () => _updateStatus(booking, BookingStatus.inProgress),
          ),
        if (booking.status == BookingStatus.inProgress)
          _statusActionButton(
            'Complete',
            Icons.task_alt,
            AppColors.success,
            () => _updateStatus(booking, BookingStatus.completed),
          ),
        if (booking.canCancel)
          _statusActionButton(
            'Cancel',
            Icons.cancel_outlined,
            AppColors.error,
            () => _showCancelDialog(booking),
          ),
      ],
    );
  }

  Widget _statusActionButton(String label, IconData icon, Color color, VoidCallback onPressed) {
    return OutlinedButton.icon(
      onPressed: _isProcessing ? null : onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color.withOpacity(0.5)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      ),
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
            Text('Total', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: colorScheme.onSurface)),
            Text('₱${booking.totalAmount.toStringAsFixed(2)}',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: colorScheme.primary)),
          ],
        ),
      ],
    );
  }

  Widget _priceRow(String label, double amount, ColorScheme colorScheme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 14, color: colorScheme.onSurfaceVariant)),
        Text('₱${amount.toStringAsFixed(2)}', style: TextStyle(fontSize: 14, color: colorScheme.onSurface)),
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
            style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant),
          ),
        if (booking.cancellationReason != null) ...[
          const SizedBox(height: 8),
          Text('Reason: ${booking.cancellationReason}', style: TextStyle(fontSize: 14, color: colorScheme.onSurface)),
        ],
      ],
    );
  }

  Future<void> _updateStatus(Booking booking, BookingStatus newStatus) async {
    setState(() => _isProcessing = true);

    try {
      final repo = ref.read(adminRepositoryProvider);
      await repo.updateBooking(booking.id, status: newStatus);

      ref.invalidate(adminBookingDetailsProvider(widget.bookingId));
      ref.invalidate(adminBookingsProvider);
      ref.invalidate(bookingCountsProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Booking ${newStatus.displayName.toLowerCase()}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _showCancelDialog(Booking booking) {
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Booking'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to cancel booking ${booking.referenceNumber}?'),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Reason (optional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Keep Booking'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _cancelBooking(booking, reasonController.text.trim());
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Cancel Booking'),
          ),
        ],
      ),
    );
  }

  Future<void> _cancelBooking(Booking booking, String reason) async {
    setState(() => _isProcessing = true);

    try {
      final repo = ref.read(adminRepositoryProvider);
      await repo.cancelBooking(booking.id, reason: reason.isEmpty ? null : reason);

      ref.invalidate(adminBookingDetailsProvider(widget.bookingId));
      ref.invalidate(adminBookingsProvider);
      ref.invalidate(bookingCountsProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Booking cancelled')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _showEditScheduleDialog(Booking booking) {
    DateTime selectedDate = booking.scheduledDate;
    TimeOfDay selectedTime = TimeOfDay(
      hour: int.parse(booking.pickupTime.split(':')[0]),
      minute: int.parse(booking.pickupTime.split(':')[1].split(' ')[0]),
    );

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit Schedule'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.calendar_today),
                title: Text(DateFormat('EEE, MMM d, yyyy').format(selectedDate)),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: selectedDate,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (date != null) setDialogState(() => selectedDate = date);
                },
              ),
              ListTile(
                leading: const Icon(Icons.access_time),
                title: Text(selectedTime.format(context)),
                onTap: () async {
                  final time = await showTimePicker(
                    context: context,
                    initialTime: selectedTime,
                  );
                  if (time != null) setDialogState(() => selectedTime = time);
                },
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                Navigator.pop(context);
                await _updateSchedule(booking, selectedDate, selectedTime);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _updateSchedule(Booking booking, DateTime date, TimeOfDay time) async {
    setState(() => _isProcessing = true);

    try {
      final repo = ref.read(adminRepositoryProvider);
      final timeStr = '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

      await repo.updateBooking(
        booking.id,
        scheduledDate: date,
        pickupTime: timeStr,
      );

      ref.invalidate(adminBookingDetailsProvider(widget.bookingId));
      ref.invalidate(adminBookingsProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Schedule updated')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _showAssignDriverVehicleDialog(Booking booking) {
    final drivers = ref.read(availableDriversProvider);
    final vehicles = ref.read(availableVehiclesProvider);

    String? selectedDriverId = booking.driverId;
    String? selectedVehicleId = booking.vehicleId;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Assign Driver & Vehicle'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Driver', style: TextStyle(fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                drivers.when(
                  data: (driverList) => DropdownButtonFormField<String>(
                    value: selectedDriverId,
                    hint: const Text('Select driver'),
                    isExpanded: true,
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Unassigned')),
                      ...driverList.map((d) => DropdownMenuItem(
                            value: d.id,
                            child: Text(d.fullName),
                          )),
                    ],
                    onChanged: (v) => setDialogState(() => selectedDriverId = v),
                  ),
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (_, __) => const Text('Error loading drivers'),
                ),
                const SizedBox(height: 16),
                const Text('Vehicle', style: TextStyle(fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                vehicles.when(
                  data: (vehicleList) => DropdownButtonFormField<String>(
                    value: selectedVehicleId,
                    hint: const Text('Select vehicle'),
                    isExpanded: true,
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Unassigned')),
                      ...vehicleList.map((v) => DropdownMenuItem(
                            value: v.id,
                            child: Text(v.displayName),
                          )),
                    ],
                    onChanged: (v) => setDialogState(() => selectedVehicleId = v),
                  ),
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (_, __) => const Text('Error loading vehicles'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                Navigator.pop(context);
                await _updateAssignment(booking, selectedDriverId, selectedVehicleId);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _updateAssignment(Booking booking, String? driverId, String? vehicleId) async {
    setState(() => _isProcessing = true);

    try {
      final repo = ref.read(adminRepositoryProvider);
      await repo.updateBooking(
        booking.id,
        driverId: driverId,
        vehicleId: vehicleId,
      );

      ref.invalidate(adminBookingDetailsProvider(widget.bookingId));
      ref.invalidate(adminBookingsProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Assignment updated')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }
}
