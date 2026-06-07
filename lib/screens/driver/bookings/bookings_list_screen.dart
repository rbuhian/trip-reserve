import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../models/booking.dart';
import '../../../models/enums.dart';
import '../../../models/vehicle.dart';
import '../../../providers/vehicle_provider.dart';
import '../../../repositories/booking_repository.dart';
import '../../../widgets/driver_booking_card.dart';

/// Provider for pending booking requests
final pendingRequestsProvider = FutureProvider<List<BookingListItem>>((ref) async {
  final repo = ref.watch(bookingRepositoryProvider);
  return repo.getPendingRequests();
});

/// Provider for driver's upcoming bookings
final driverUpcomingProvider = FutureProvider<List<BookingListItem>>((ref) async {
  final repo = ref.watch(bookingRepositoryProvider);
  return repo.getDriverUpcomingBookings();
});

/// Provider for driver's completed bookings
final driverCompletedProvider = FutureProvider<List<BookingListItem>>((ref) async {
  final repo = ref.watch(bookingRepositoryProvider);
  return repo.getDriverCompletedBookings();
});

/// Driver bookings list screen with tabs for Pending, Upcoming, Completed
class DriverBookingsListScreen extends ConsumerStatefulWidget {
  const DriverBookingsListScreen({super.key});

  @override
  ConsumerState<DriverBookingsListScreen> createState() => _DriverBookingsListScreenState();
}

class _DriverBookingsListScreenState extends ConsumerState<DriverBookingsListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String? _loadingBookingId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    ref.invalidate(pendingRequestsProvider);
    ref.invalidate(driverUpcomingProvider);
    ref.invalidate(driverCompletedProvider);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Bookings',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: colorScheme.surface,
        bottom: TabBar(
          controller: _tabController,
          labelColor: colorScheme.primary,
          unselectedLabelColor: colorScheme.onSurfaceVariant,
          indicatorColor: colorScheme.primary,
          tabs: const [
            Tab(text: 'Requests'),
            Tab(text: 'Upcoming'),
            Tab(text: 'Completed'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _PendingRequestsTab(
            onRefresh: _refresh,
            loadingBookingId: _loadingBookingId,
            onAccept: (booking) => _showAcceptDialog(booking),
            onDecline: (booking) => _showDeclineDialog(booking),
          ),
          _UpcomingBookingsTab(
            onRefresh: _refresh,
            loadingBookingId: _loadingBookingId,
            onStart: (booking) => _startTrip(booking),
          ),
          _CompletedBookingsTab(onRefresh: _refresh),
        ],
      ),
    );
  }

  Future<void> _showAcceptDialog(BookingListItem booking) async {
    final vehicles = await ref.read(driverVehiclesProvider.future);
    final activeVehicles = vehicles.where((v) => v.isActive).toList();

    if (!mounted) return;

    if (activeVehicles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You need an active vehicle to accept bookings'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    Vehicle? selectedVehicle = activeVehicles.first;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Accept Booking'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Accept booking ${booking.referenceNumber}?',
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              const Text(
                'Select vehicle:',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              ...activeVehicles.map((vehicle) => RadioListTile<Vehicle>(
                    title: Text(vehicle.name),
                    subtitle: Text(vehicle.plateNumber),
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
      await _acceptBooking(booking, selectedVehicle!.id);
    }
  }

  Future<void> _acceptBooking(BookingListItem booking, String vehicleId) async {
    setState(() => _loadingBookingId = booking.id);

    try {
      final repo = ref.read(bookingRepositoryProvider);
      await repo.accept(booking.id, vehicleId: vehicleId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Booking accepted'),
            backgroundColor: Colors.green,
          ),
        );
      }

      _refresh();
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
        setState(() => _loadingBookingId = null);
      }
    }
  }

  Future<void> _showDeclineDialog(BookingListItem booking) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Decline Booking'),
        content: Text(
          'Are you sure you want to decline booking ${booking.referenceNumber}?\n\n'
          'The booking will be available for other drivers.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Decline'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _declineBooking(booking);
    }
  }

  Future<void> _declineBooking(BookingListItem booking) async {
    setState(() => _loadingBookingId = booking.id);

    try {
      final repo = ref.read(bookingRepositoryProvider);
      await repo.decline(booking.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Booking declined')),
        );
      }

      _refresh();
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
        setState(() => _loadingBookingId = null);
      }
    }
  }

  Future<void> _startTrip(BookingListItem booking) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Start Trip'),
        content: Text(
          'Start trip ${booking.referenceNumber}?\n\n'
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
      setState(() => _loadingBookingId = booking.id);

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
        }

        _refresh();
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
          setState(() => _loadingBookingId = null);
        }
      }
    }
  }
}

class _PendingRequestsTab extends ConsumerWidget {
  final VoidCallback onRefresh;
  final String? loadingBookingId;
  final Function(BookingListItem) onAccept;
  final Function(BookingListItem) onDecline;

  const _PendingRequestsTab({
    required this.onRefresh,
    required this.loadingBookingId,
    required this.onAccept,
    required this.onDecline,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookingsAsync = ref.watch(pendingRequestsProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return bookingsAsync.when(
      data: (bookings) {
        if (bookings.isEmpty) {
          return _buildEmptyState(
            colorScheme,
            icon: Icons.inbox_outlined,
            title: 'No pending requests',
            subtitle: 'New booking requests will appear here',
          );
        }

        return RefreshIndicator(
          onRefresh: () async => onRefresh(),
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: bookings.length,
            itemBuilder: (context, index) {
              final booking = bookings[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: DriverBookingCard(
                  booking: booking,
                  isLoading: loadingBookingId == booking.id,
                  onTap: () => context.push('/driver/bookings/${booking.id}'),
                  onAccept: () => onAccept(booking),
                  onDecline: () => onDecline(booking),
                ),
              );
            },
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => _buildErrorState(colorScheme, onRefresh),
    );
  }
}

class _UpcomingBookingsTab extends ConsumerWidget {
  final VoidCallback onRefresh;
  final String? loadingBookingId;
  final Function(BookingListItem) onStart;

  const _UpcomingBookingsTab({
    required this.onRefresh,
    required this.loadingBookingId,
    required this.onStart,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookingsAsync = ref.watch(driverUpcomingProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return bookingsAsync.when(
      data: (bookings) {
        if (bookings.isEmpty) {
          return _buildEmptyState(
            colorScheme,
            icon: Icons.calendar_today_outlined,
            title: 'No upcoming bookings',
            subtitle: 'Accept requests to see them here',
          );
        }

        return RefreshIndicator(
          onRefresh: () async => onRefresh(),
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: bookings.length,
            itemBuilder: (context, index) {
              final booking = bookings[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: DriverBookingCard(
                  booking: booking,
                  isLoading: loadingBookingId == booking.id,
                  onTap: () => context.push('/driver/bookings/${booking.id}'),
                  onStart: booking.canStart ? () => onStart(booking) : null,
                ),
              );
            },
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => _buildErrorState(colorScheme, onRefresh),
    );
  }
}

class _CompletedBookingsTab extends ConsumerWidget {
  final VoidCallback onRefresh;

  const _CompletedBookingsTab({required this.onRefresh});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookingsAsync = ref.watch(driverCompletedProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return bookingsAsync.when(
      data: (bookings) {
        if (bookings.isEmpty) {
          return _buildEmptyState(
            colorScheme,
            icon: Icons.check_circle_outline,
            title: 'No completed trips',
            subtitle: 'Your completed trips will appear here',
          );
        }

        return RefreshIndicator(
          onRefresh: () async => onRefresh(),
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: bookings.length,
            itemBuilder: (context, index) {
              final booking = bookings[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: DriverBookingCard(
                  booking: booking,
                  onTap: () => context.push('/driver/bookings/${booking.id}'),
                ),
              );
            },
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => _buildErrorState(colorScheme, onRefresh),
    );
  }
}

Widget _buildEmptyState(
  ColorScheme colorScheme, {
  required IconData icon,
  required String title,
  required String subtitle,
}) {
  return Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 48,
              color: colorScheme.onSurfaceVariant.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            title,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 15,
              color: colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}

Widget _buildErrorState(ColorScheme colorScheme, VoidCallback onRetry) {
  return Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.error_outline, size: 48, color: colorScheme.error),
        const SizedBox(height: 16),
        Text(
          'Error loading bookings',
          style: TextStyle(color: colorScheme.error),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: onRetry,
          child: const Text('Retry'),
        ),
      ],
    ),
  );
}
