import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../models/booking.dart';
import '../../providers/auth_provider.dart';
import '../../repositories/admin_repository.dart';
import '../../widgets/booking_card.dart';
import '../../widgets/kpi_card.dart';

/// Provider for dashboard stats
final dashboardStatsProvider = FutureProvider<DashboardStats>((ref) async {
  final repo = ref.watch(adminRepositoryProvider);
  return repo.getDashboardStats();
});

/// Provider for recent bookings
final recentBookingsProvider = FutureProvider<List<BookingListItem>>((ref) async {
  final repo = ref.watch(adminRepositoryProvider);
  return repo.getRecentBookings(limit: 5);
});

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final authUser = ref.watch(authUserProvider);
    final stats = ref.watch(dashboardStatsProvider);
    final recentBookings = ref.watch(recentBookingsProvider);

    return Scaffold(
      // top: false so the SliverAppBar paints behind the status bar (navy),
      // instead of a white strip above the header.
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(dashboardStatsProvider);
            ref.invalidate(recentBookingsProvider);
          },
          child: CustomScrollView(
            slivers: [
              // App Bar
              SliverAppBar(
                floating: true,
                pinned: true,
                toolbarHeight: 70,
                backgroundColor: AppColors.primaryDark,
                foregroundColor: AppColors.white,
                title: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Admin Dashboard',
                      style: TextStyle(
                        fontSize: 20,
                        color: AppColors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    authUser.when(
                      data: (user) => Text(
                        'Welcome back, ${user?.firstName ?? 'Admin'}',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.white.withOpacity(0.8),
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      loading: () => const SizedBox(),
                      error: (_, __) => const SizedBox(),
                    ),
                  ],
                ),
                actions: [
                  IconButton(
                    onPressed: () {},
                    icon: Badge(
                      smallSize: 8,
                      child: const Icon(
                        Icons.notifications_outlined,
                        color: AppColors.white,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: IconButton(
                      onPressed: () => _showProfileMenu(context, ref),
                      icon: CircleAvatar(
                        radius: 16,
                        backgroundColor: AppColors.white.withOpacity(0.15),
                        child: const Icon(
                          Icons.person,
                          size: 18,
                          color: AppColors.white,
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
                    // Revenue MTD - Featured card
                    stats.when(
                      data: (s) => KpiCardLarge(
                        title: 'Revenue MTD',
                        value: '₱${_formatCurrency(s.revenueMtd)}',
                        subtitle: 'Month to date',
                        icon: Icons.payments_outlined,
                        backgroundColor: colorScheme.primary,
                        changePercent: s.revenueMtdChange,
                        changeLabel: 'vs last month',
                      ),
                      loading: () => const KpiCardLarge(
                        title: 'Revenue MTD',
                        value: '---',
                        icon: Icons.payments_outlined,
                        isLoading: true,
                      ),
                      error: (_, __) => const KpiCardLarge(
                        title: 'Revenue MTD',
                        value: '₱0',
                        icon: Icons.payments_outlined,
                      ),
                    ),

                    const SizedBox(height: 16),

                    // KPI Grid
                    Row(
                      children: [
                        Expanded(
                          child: stats.when(
                            data: (s) => KpiCard(
                              title: 'Trips Today',
                              value: s.tripsToday.toString(),
                              icon: Icons.directions_car,
                              iconColor: AppColors.success,
                              changePercent: s.tripsTodayChange.toDouble(),
                              changeLabel: 'vs avg',
                              onTap: () => context.go('/admin/bookings'),
                            ),
                            loading: () => const KpiCard(
                              title: 'Trips Today',
                              value: '-',
                              icon: Icons.directions_car,
                              iconColor: AppColors.success,
                              isLoading: true,
                            ),
                            error: (_, __) => const KpiCard(
                              title: 'Trips Today',
                              value: '0',
                              icon: Icons.directions_car,
                              iconColor: AppColors.success,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: stats.when(
                            data: (s) => KpiCard(
                              title: 'Fleet Utilization',
                              value: '${s.fleetUtilization.toStringAsFixed(0)}%',
                              subtitle: '${s.activeVehicles} active vehicles',
                              icon: Icons.local_shipping_outlined,
                              iconColor: AppColors.accent,
                              onTap: () => context.push('/admin/reports?tab=2'),
                            ),
                            loading: () => const KpiCard(
                              title: 'Fleet Utilization',
                              value: '-',
                              icon: Icons.local_shipping_outlined,
                              iconColor: AppColors.accent,
                              isLoading: true,
                            ),
                            error: (_, __) => const KpiCard(
                              title: 'Fleet Utilization',
                              value: '0%',
                              icon: Icons.local_shipping_outlined,
                              iconColor: AppColors.accent,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(
                          child: stats.when(
                            data: (s) => KpiCard(
                              title: 'Active Vehicles',
                              value: s.activeVehicles.toString(),
                              subtitle: 'of ${s.totalVehicles} total',
                              icon: Icons.directions_car_filled_outlined,
                              iconColor: colorScheme.primary,
                              onTap: () => context.push('/admin/reports?tab=2'),
                            ),
                            loading: () => KpiCard(
                              title: 'Active Vehicles',
                              value: '-',
                              icon: Icons.directions_car_filled_outlined,
                              iconColor: colorScheme.primary,
                              isLoading: true,
                            ),
                            error: (_, __) => KpiCard(
                              title: 'Active Vehicles',
                              value: '0',
                              icon: Icons.directions_car_filled_outlined,
                              iconColor: colorScheme.primary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: KpiCard(
                            title: 'View Reports',
                            value: '',
                            subtitle: 'Analytics & insights',
                            icon: Icons.analytics_outlined,
                            iconColor: AppColors.warning,
                            onTap: () => context.push('/admin/reports'),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 28),

                    // Recent Bookings
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Recent Bookings',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        TextButton(
                          onPressed: () => context.go('/admin/bookings'),
                          child: const Text('See all'),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    recentBookings.when(
                      data: (bookings) {
                        if (bookings.isEmpty) {
                          return _buildEmptyBookings(context);
                        }
                        return Column(
                          children: bookings.map((booking) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: BookingCardCompact(
                              booking: booking,
                              onTap: () => context.push('/admin/bookings/${booking.id}'),
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
                      error: (_, __) => _buildEmptyBookings(context),
                    ),

                    const SizedBox(height: 20),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showProfileMenu(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: const Text('My Profile'),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.settings_outlined),
              title: const Text('Settings'),
              onTap: () {
                Navigator.pop(context);
                context.go('/admin/settings');
              },
            ),
            const Divider(),
            ListTile(
              leading: Icon(Icons.logout, color: colorScheme.error),
              title: Text('Sign Out', style: TextStyle(color: colorScheme.error)),
              onTap: () {
                Navigator.pop(context);
                ref.read(authActionsProvider.notifier).signOut();
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyBookings(BuildContext context) {
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
            Icons.receipt_long_outlined,
            size: 40,
            color: colorScheme.onSurfaceVariant.withOpacity(0.5),
          ),
          const SizedBox(height: 12),
          Text(
            'No bookings yet',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Recent bookings will appear here',
            style: TextStyle(
              fontSize: 13,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  String _formatCurrency(double amount) {
    if (amount >= 1000000) {
      return '${(amount / 1000000).toStringAsFixed(1)}M';
    } else if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(1)}K';
    }
    return amount.toStringAsFixed(0);
  }
}
