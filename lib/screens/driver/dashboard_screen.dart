import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../models/booking.dart';
import '../../models/earnings.dart';
import '../../providers/auth_provider.dart';
import '../../providers/vehicle_provider.dart';
import '../../repositories/booking_repository.dart';
import '../../repositories/earnings_repository.dart';
import '../../widgets/driver_booking_card.dart';

/// Provider for weekly earnings summary
final weeklyEarningsProvider = FutureProvider<EarningsSummary>((ref) async {
  final repo = ref.watch(earningsRepositoryProvider);
  return repo.getWeeklySummary();
});

/// Provider for pending booking requests count
final pendingRequestsCountProvider = FutureProvider<int>((ref) async {
  final repo = ref.watch(bookingRepositoryProvider);
  final requests = await repo.getPendingRequests();
  return requests.length;
});

/// Provider for driver's upcoming bookings (for dashboard preview)
final dashboardUpcomingProvider = FutureProvider<List<BookingListItem>>((ref) async {
  final repo = ref.watch(bookingRepositoryProvider);
  final bookings = await repo.getDriverUpcomingBookings();
  return bookings.take(3).toList();
});

class DriverDashboardScreen extends ConsumerWidget {
  const DriverDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final authUser = ref.watch(authUserProvider);
    final vehicles = ref.watch(myVehiclesProvider);
    final earnings = ref.watch(weeklyEarningsProvider);
    final pendingCount = ref.watch(pendingRequestsCountProvider);
    final upcomingBookings = ref.watch(dashboardUpcomingProvider);

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(weeklyEarningsProvider);
            ref.invalidate(pendingRequestsCountProvider);
            ref.invalidate(dashboardUpcomingProvider);
            ref.invalidate(myVehiclesProvider);
          },
          child: CustomScrollView(
            slivers: [
              // App Bar
              SliverAppBar(
                floating: true,
                backgroundColor: colorScheme.surface,
                title: authUser.when(
                  data: (user) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Good ${_getGreeting()},',
                        style: TextStyle(
                          fontSize: 13,
                          color: colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      Text(
                        user?.firstName ?? 'Driver',
                        style: TextStyle(
                          fontSize: 20,
                          color: colorScheme.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  loading: () => const SizedBox(),
                  error: (_, __) => const Text('Error'),
                ),
                actions: [
                  // Notifications
                  IconButton(
                    onPressed: () {},
                    icon: Badge(
                      smallSize: 8,
                      child: Icon(
                        Icons.notifications_outlined,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  // Profile
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: IconButton(
                      onPressed: () => context.go('/driver/profile'),
                      icon: CircleAvatar(
                        radius: 16,
                        backgroundColor: colorScheme.primary.withOpacity(0.1),
                        child: Icon(
                          Icons.person,
                          size: 18,
                          color: colorScheme.primary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              // Content
              SliverPadding(
                padding: const EdgeInsets.all(20),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // Earnings card (prominent)
                    _buildEarningsCard(context, earnings),

                    const SizedBox(height: 16),

                    // Stats cards row
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            context,
                            icon: Icons.directions_car,
                            iconColor: colorScheme.primary,
                            label: 'Vehicles',
                            value: vehicles.when(
                              data: (v) => v.where((v) => v.isActive).length.toString(),
                              loading: () => '-',
                              error: (_, __) => '0',
                            ),
                            onTap: () => context.go('/driver/vehicles'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStatCard(
                            context,
                            icon: Icons.pending_actions,
                            iconColor: AppColors.accent,
                            label: 'Requests',
                            value: pendingCount.when(
                              data: (count) => count.toString(),
                              loading: () => '-',
                              error: (_, __) => '0',
                            ),
                            onTap: () => context.go('/driver/bookings'),
                            showBadge: pendingCount.valueOrNull != null &&
                                       pendingCount.valueOrNull! > 0,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            context,
                            icon: Icons.check_circle_outline,
                            iconColor: AppColors.success,
                            label: 'Completed',
                            value: earnings.when(
                              data: (e) => e.tripCount.toString(),
                              loading: () => '-',
                              error: (_, __) => '0',
                            ),
                            subtitle: 'This week',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStatCard(
                            context,
                            icon: Icons.hourglass_empty,
                            iconColor: AppColors.warning,
                            label: 'Pending',
                            value: earnings.when(
                              data: (e) => '₱${e.pendingAmount.toStringAsFixed(0)}',
                              loading: () => '-',
                              error: (_, __) => '₱0',
                            ),
                            subtitle: 'To be paid',
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 28),

                    // Quick Actions
                    Text(
                      'Quick Actions',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                    const SizedBox(height: 16),

                    _buildQuickAction(
                      context,
                      icon: Icons.add_circle_outline,
                      iconColor: colorScheme.primary,
                      title: 'Add Vehicle',
                      subtitle: 'Register a new vehicle',
                      onTap: () => context.push('/driver/vehicles/add'),
                    ),

                    const SizedBox(height: 12),

                    _buildQuickAction(
                      context,
                      icon: Icons.event_busy,
                      iconColor: AppColors.accent,
                      title: 'Block Time',
                      subtitle: 'Set unavailable hours',
                      onTap: () => context.go('/driver/calendar'),
                    ),

                    const SizedBox(height: 12),

                    _buildQuickAction(
                      context,
                      icon: Icons.calendar_today,
                      iconColor: AppColors.primary,
                      title: 'View Schedule',
                      subtitle: 'Check your bookings',
                      onTap: () => context.go('/driver/calendar'),
                    ),

                    const SizedBox(height: 28),

                    // Upcoming Trips
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Upcoming Trips',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        TextButton(
                          onPressed: () => context.go('/driver/bookings'),
                          child: const Text('See all'),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Upcoming trips list or empty state
                    upcomingBookings.when(
                      data: (bookings) {
                        if (bookings.isEmpty) {
                          return _buildEmptyTrips(context);
                        }
                        return Column(
                          children: bookings.map((booking) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: DriverBookingCard(
                              booking: booking,
                              onTap: () => context.push('/driver/bookings/${booking.id}'),
                            ),
                          )).toList(),
                        );
                      },
                      loading: () => const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32),
                          child: CircularProgressIndicator(),
                        ),
                      ),
                      error: (_, __) => _buildEmptyTrips(context),
                    ),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'morning';
    if (hour < 17) return 'afternoon';
    return 'evening';
  }

  Widget _buildEarningsCard(BuildContext context, AsyncValue<EarningsSummary> earnings) {
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
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.account_balance_wallet,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Weekly Earnings',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _getCurrentWeekLabel(),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Colors.white70,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          earnings.when(
            data: (e) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '₱${e.totalNet.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Net earnings from ${e.tripCount} trip${e.tripCount != 1 ? 's' : ''}',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
                if (e.totalFees > 0) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildEarningsDetail(
                            'Gross',
                            '₱${e.totalGross.toStringAsFixed(0)}',
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 30,
                          color: Colors.white.withOpacity(0.2),
                        ),
                        Expanded(
                          child: _buildEarningsDetail(
                            'Fees (15%)',
                            '-₱${e.totalFees.toStringAsFixed(0)}',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            loading: () => const Text(
              '₱---',
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            error: (_, __) => const Text(
              '₱0',
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEarningsDetail(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.white.withOpacity(0.7),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  String _getCurrentWeekLabel() {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final weekEnd = weekStart.add(const Duration(days: 6));

    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

    if (weekStart.month == weekEnd.month) {
      return '${months[weekStart.month - 1]} ${weekStart.day}-${weekEnd.day}';
    }
    return '${months[weekStart.month - 1]} ${weekStart.day} - ${months[weekEnd.month - 1]} ${weekEnd.day}';
  }

  Widget _buildStatCard(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    String? subtitle,
    VoidCallback? onTap,
    bool showBadge = false,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: colorScheme.outlineVariant.withOpacity(0.3),
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.textDark.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: iconColor, size: 20),
                ),
                if (showBadge)
                  Container(
                    margin: const EdgeInsets.only(left: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.error,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      'NEW',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11,
                  color: colorScheme.onSurfaceVariant.withOpacity(0.7),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildQuickAction(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: colorScheme.outlineVariant.withOpacity(0.3),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyTrips(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: colorScheme.outlineVariant.withOpacity(0.3),
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.event_available,
            size: 40,
            color: colorScheme.onSurfaceVariant.withOpacity(0.5),
          ),
          const SizedBox(height: 12),
          Text(
            'No upcoming trips',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Accept booking requests to see them here',
            style: TextStyle(
              fontSize: 13,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
