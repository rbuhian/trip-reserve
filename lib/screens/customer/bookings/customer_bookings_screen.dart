import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../models/booking.dart';
import '../../../models/enums.dart';
import '../../../providers/booking_provider.dart';
import '../../../providers/message_provider.dart';
import '../../../widgets/booking_card.dart';

/// Customer bookings list screen with tabs for upcoming and past
class CustomerBookingsScreen extends ConsumerStatefulWidget {
  const CustomerBookingsScreen({super.key});

  @override
  ConsumerState<CustomerBookingsScreen> createState() => _CustomerBookingsScreenState();
}

class _CustomerBookingsScreenState extends ConsumerState<CustomerBookingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    ref.invalidate(upcomingBookingsProvider);
    ref.invalidate(pastBookingsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Bookings'),
        backgroundColor: AppColors.primaryDark,
        foregroundColor: AppColors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.white,
          unselectedLabelColor: AppColors.white.withOpacity(0.6),
          indicatorColor: AppColors.accent,
          tabs: const [
            Tab(text: 'Upcoming'),
            Tab(text: 'Past'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _UpcomingBookingsTab(onRefresh: _refresh),
          _PastBookingsTab(onRefresh: _refresh),
        ],
      ),
    );
  }
}

class _UpcomingBookingsTab extends ConsumerWidget {
  final VoidCallback onRefresh;

  const _UpcomingBookingsTab({required this.onRefresh});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookingsAsync = ref.watch(upcomingBookingsProvider);
    final unread = ref.watch(unreadCountsProvider).valueOrNull ?? const {};
    final colorScheme = Theme.of(context).colorScheme;

    return bookingsAsync.when(
      data: (bookings) {
        if (bookings.isEmpty) {
          return _buildEmptyState(
            context,
            icon: Icons.calendar_today_outlined,
            title: 'No upcoming bookings',
            subtitle: 'Your upcoming trips will appear here',
            showBookButton: true,
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
                child: BookingCard(
                  booking: booking,
                  unreadCount: unread[booking.id] ?? 0,
                  onTap: () => context.push('/bookings/${booking.id}'),
                ),
              );
            },
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
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
              onPressed: onRefresh,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PastBookingsTab extends ConsumerWidget {
  final VoidCallback onRefresh;

  const _PastBookingsTab({required this.onRefresh});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookingsAsync = ref.watch(pastBookingsProvider);
    final unread = ref.watch(unreadCountsProvider).valueOrNull ?? const {};
    final colorScheme = Theme.of(context).colorScheme;

    return bookingsAsync.when(
      data: (bookings) {
        if (bookings.isEmpty) {
          return _buildEmptyState(
            context,
            icon: Icons.history,
            title: 'No past bookings',
            subtitle: 'Your completed and cancelled trips will appear here',
            showBookButton: false,
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
                child: BookingCard(
                  booking: booking,
                  unreadCount: unread[booking.id] ?? 0,
                  onTap: () => context.push('/bookings/${booking.id}'),
                ),
              );
            },
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
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
              onPressed: onRefresh,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

Widget _buildEmptyState(
  BuildContext context, {
  required IconData icon,
  required String title,
  required String subtitle,
  required bool showBookButton,
}) {
  final colorScheme = Theme.of(context).colorScheme;

  return Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: colorScheme.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 48,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 14,
              color: colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          if (showBookButton) ...[
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => context.go('/book'),
              icon: const Icon(Icons.add),
              label: const Text('Book a Ride'),
            ),
          ],
        ],
      ),
    ),
  );
}
