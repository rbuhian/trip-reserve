import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../models/booking.dart';
import '../../../models/enums.dart';
import '../../../repositories/admin_repository.dart';
import '../../../widgets/booking_card.dart';

/// Provider for all bookings with optional status filter
final adminBookingsProvider = FutureProvider.family<List<BookingListItem>, BookingStatus?>((ref, status) async {
  final repo = ref.watch(adminRepositoryProvider);
  return repo.getAllBookings(status: status);
});

/// Provider for booking counts by status
final bookingCountsProvider = FutureProvider<Map<BookingStatus, int>>((ref) async {
  final repo = ref.watch(adminRepositoryProvider);
  return repo.getBookingCountsByStatus();
});

class AdminBookingsScreen extends ConsumerStatefulWidget {
  const AdminBookingsScreen({super.key});

  @override
  ConsumerState<AdminBookingsScreen> createState() => _AdminBookingsScreenState();
}

class _AdminBookingsScreenState extends ConsumerState<AdminBookingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  static const _tabs = [
    (label: 'All', status: null),
    (label: 'Pending', status: BookingStatus.pending),
    (label: 'Confirmed', status: BookingStatus.confirmed),
    (label: 'In Progress', status: BookingStatus.inProgress),
    (label: 'Completed', status: BookingStatus.completed),
    (label: 'Cancelled', status: BookingStatus.cancelled),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final counts = ref.watch(bookingCountsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('All Bookings'),
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          labelColor: colorScheme.primary,
          unselectedLabelColor: colorScheme.onSurfaceVariant,
          indicatorColor: colorScheme.primary,
          tabs: _tabs.map((tab) {
            final count = tab.status == null
                ? counts.valueOrNull?.values.fold<int>(0, (a, b) => a + b) ?? 0
                : counts.valueOrNull?[tab.status] ?? 0;
            return Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(tab.label),
                  if (count > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        count.toString(),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            );
          }).toList(),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: _tabs.map((tab) => _BookingsList(status: tab.status)).toList(),
      ),
    );
  }
}

class _BookingsList extends ConsumerWidget {
  final BookingStatus? status;

  const _BookingsList({this.status});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final bookings = ref.watch(adminBookingsProvider(status));

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(adminBookingsProvider(status));
        ref.invalidate(bookingCountsProvider);
      },
      child: bookings.when(
        data: (items) {
          if (items.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.receipt_long_outlined,
                    size: 64,
                    color: colorScheme.onSurfaceVariant.withOpacity(0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No bookings found',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    status == null
                        ? 'Bookings will appear here'
                        : 'No ${status!.displayName.toLowerCase()} bookings',
                    style: TextStyle(
                      fontSize: 14,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final booking = items[index];
              return BookingCardCompact(
                booking: booking,
                onTap: () => context.push('/admin/bookings/${booking.id}'),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48, color: colorScheme.error),
              const SizedBox(height: 16),
              Text('Failed to load bookings'),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => ref.invalidate(adminBookingsProvider(status)),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
