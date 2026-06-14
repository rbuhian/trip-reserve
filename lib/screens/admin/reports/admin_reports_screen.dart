import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../repositories/admin_repository.dart';

/// Provider for daily trips report (last 7 days)
final dailyTripsReportProvider = FutureProvider<List<DailyTripsReport>>((ref) async {
  final repo = ref.watch(adminRepositoryProvider);
  final now = DateTime.now();
  final startDate = now.subtract(const Duration(days: 6));
  return repo.getDailyTripsReport(
    startDate: DateTime(startDate.year, startDate.month, startDate.day),
    endDate: DateTime(now.year, now.month, now.day),
  );
});

/// Provider for monthly revenue report (current year)
final monthlyRevenueReportProvider = FutureProvider<List<MonthlyRevenueReport>>((ref) async {
  final repo = ref.watch(adminRepositoryProvider);
  return repo.getMonthlyRevenueReport(DateTime.now().year);
});

/// Provider for fleet utilization report (last 30 days)
final fleetUtilizationReportProvider = FutureProvider<FleetUtilizationReport>((ref) async {
  final repo = ref.watch(adminRepositoryProvider);
  final now = DateTime.now();
  final startDate = now.subtract(const Duration(days: 29));
  return repo.getFleetUtilizationReport(
    startDate: DateTime(startDate.year, startDate.month, startDate.day),
    endDate: DateTime(now.year, now.month, now.day),
  );
});

class AdminReportsScreen extends ConsumerStatefulWidget {
  /// Initial tab: 0 = Trips, 1 = Revenue, 2 = Fleet.
  final int initialTab;

  const AdminReportsScreen({super.key, this.initialTab = 0});

  @override
  ConsumerState<AdminReportsScreen> createState() => _AdminReportsScreenState();
}

class _AdminReportsScreenState extends ConsumerState<AdminReportsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 2),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports & Analytics'),
        backgroundColor: AppColors.primaryDark,
        foregroundColor: AppColors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.accent,
          unselectedLabelColor: Colors.white70,
          indicatorColor: AppColors.accent,
          tabs: const [
            Tab(text: 'Trips'),
            Tab(text: 'Revenue'),
            Tab(text: 'Fleet'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _DailyTripsTab(),
          _MonthlyRevenueTab(),
          _FleetUtilizationTab(),
        ],
      ),
    );
  }
}

/// Daily Trips Report Tab
class _DailyTripsTab extends ConsumerWidget {
  const _DailyTripsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final report = ref.watch(dailyTripsReportProvider);

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(dailyTripsReportProvider),
      child: report.when(
        data: (data) {
          final totalTrips = data.fold(0, (sum, d) => sum + d.totalTrips);
          final completedTrips = data.fold(0, (sum, d) => sum + d.completedTrips);
          final cancelledTrips = data.fold(0, (sum, d) => sum + d.cancelledTrips);
          final totalRevenue = data.fold(0.0, (sum, d) => sum + d.revenue);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Summary Cards
                Row(
                  children: [
                    Expanded(
                      child: _SummaryCard(
                        title: 'Total Trips',
                        value: totalTrips.toString(),
                        subtitle: 'Last 7 days',
                        icon: Icons.directions_car,
                        color: colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _SummaryCard(
                        title: 'Completed',
                        value: completedTrips.toString(),
                        subtitle: '${totalTrips > 0 ? (completedTrips / totalTrips * 100).toStringAsFixed(0) : 0}% rate',
                        icon: Icons.check_circle_outline,
                        color: AppColors.success,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _SummaryCard(
                        title: 'Cancelled',
                        value: cancelledTrips.toString(),
                        subtitle: '${totalTrips > 0 ? (cancelledTrips / totalTrips * 100).toStringAsFixed(0) : 0}% rate',
                        icon: Icons.cancel_outlined,
                        color: AppColors.error,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _SummaryCard(
                        title: 'Revenue',
                        value: '₱${_formatCurrency(totalRevenue)}',
                        subtitle: 'From completed',
                        icon: Icons.payments_outlined,
                        color: AppColors.accent,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 28),

                // Daily Trips Chart
                Text(
                  'Daily Trips',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  height: 220,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: colorScheme.outlineVariant.withOpacity(0.3),
                    ),
                  ),
                  child: _DailyTripsChart(data: data),
                ),

                const SizedBox(height: 28),

                // Daily Breakdown Table
                Text(
                  'Daily Breakdown',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 12),
                ...data.reversed.map((day) => _DailyReportRow(report: day)),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48, color: colorScheme.error),
              const SizedBox(height: 16),
              const Text('Failed to load report'),
              TextButton(
                onPressed: () => ref.invalidate(dailyTripsReportProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Monthly Revenue Report Tab
class _MonthlyRevenueTab extends ConsumerWidget {
  const _MonthlyRevenueTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final report = ref.watch(monthlyRevenueReportProvider);

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(monthlyRevenueReportProvider),
      child: report.when(
        data: (data) {
          final totalRevenue = data.fold(0.0, (sum, m) => sum + m.revenue);
          final totalTrips = data.fold(0, (sum, m) => sum + m.tripCount);
          final avgPerMonth = data.isNotEmpty ? totalRevenue / 12 : 0.0;
          final currentMonth = data.isNotEmpty ? data[DateTime.now().month - 1] : null;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Summary Cards
                Row(
                  children: [
                    Expanded(
                      child: _SummaryCard(
                        title: 'YTD Revenue',
                        value: '₱${_formatCurrency(totalRevenue)}',
                        subtitle: DateTime.now().year.toString(),
                        icon: Icons.payments_outlined,
                        color: colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _SummaryCard(
                        title: 'This Month',
                        value: '₱${_formatCurrency(currentMonth?.revenue ?? 0)}',
                        subtitle: '${currentMonth?.tripCount ?? 0} trips',
                        icon: Icons.calendar_month,
                        color: AppColors.success,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _SummaryCard(
                        title: 'Avg/Month',
                        value: '₱${_formatCurrency(avgPerMonth)}',
                        subtitle: 'Average monthly',
                        icon: Icons.trending_up,
                        color: AppColors.accent,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _SummaryCard(
                        title: 'Total Trips',
                        value: totalTrips.toString(),
                        subtitle: 'Year to date',
                        icon: Icons.directions_car,
                        color: Colors.purple,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 28),

                // Monthly Revenue Chart
                Text(
                  'Monthly Revenue (${DateTime.now().year})',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  height: 260,
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: colorScheme.outlineVariant.withOpacity(0.3),
                    ),
                  ),
                  child: _MonthlyRevenueChart(data: data),
                ),

                const SizedBox(height: 28),

                // Monthly Breakdown Table
                Text(
                  'Monthly Breakdown',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 12),
                ...data.where((m) => m.revenue > 0 || m.tripCount > 0).map(
                      (month) => _MonthlyReportRow(report: month),
                    ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48, color: colorScheme.error),
              const SizedBox(height: 16),
              const Text('Failed to load report'),
              TextButton(
                onPressed: () => ref.invalidate(monthlyRevenueReportProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Fleet Utilization Report Tab
class _FleetUtilizationTab extends ConsumerWidget {
  const _FleetUtilizationTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final report = ref.watch(fleetUtilizationReportProvider);

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(fleetUtilizationReportProvider),
      child: report.when(
        data: (data) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Summary Cards
                Row(
                  children: [
                    Expanded(
                      child: _SummaryCard(
                        title: 'Avg Utilization',
                        value: '${data.averageUtilization.toStringAsFixed(0)}%',
                        subtitle: 'Last 30 days',
                        icon: Icons.speed,
                        color: colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _SummaryCard(
                        title: 'Active Vehicles',
                        value: data.totalVehicles.toString(),
                        subtitle: 'In fleet',
                        icon: Icons.directions_car,
                        color: AppColors.success,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _SummaryCard(
                        title: 'Total Trips',
                        value: data.totalTrips.toString(),
                        subtitle: 'All vehicles',
                        icon: Icons.route,
                        color: AppColors.accent,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _SummaryCard(
                        title: 'Total Revenue',
                        value: '₱${_formatCurrency(data.totalRevenue)}',
                        subtitle: 'From fleet',
                        icon: Icons.payments_outlined,
                        color: Colors.purple,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 28),

                // Fleet Utilization Chart
                Text(
                  'Vehicle Utilization',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 16),
                if (data.vehicleUtilizations.isNotEmpty)
                  Container(
                    height: 220,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: colorScheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: colorScheme.outlineVariant.withOpacity(0.3),
                      ),
                    ),
                    child: _FleetUtilizationChart(data: data.vehicleUtilizations),
                  )
                else
                  Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Center(
                      child: Text(
                        'No vehicle data available',
                        style: TextStyle(color: colorScheme.onSurfaceVariant),
                      ),
                    ),
                  ),

                const SizedBox(height: 28),

                // Per-Vehicle Breakdown
                Text(
                  'Per-Vehicle Breakdown',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 12),
                ...data.vehicleUtilizations.map(
                  (vehicle) => _VehicleUtilizationRow(utilization: vehicle),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48, color: colorScheme.error),
              const SizedBox(height: 16),
              const Text('Failed to load report'),
              TextButton(
                onPressed: () => ref.invalidate(fleetUtilizationReportProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// CHART WIDGETS
// ============================================================

class _DailyTripsChart extends StatelessWidget {
  final List<DailyTripsReport> data;

  const _DailyTripsChart({required this.data});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final dateFormat = DateFormat('E');

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: data.map((d) => d.totalTrips.toDouble()).reduce((a, b) => a > b ? a : b) * 1.2,
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => colorScheme.inverseSurface,
            tooltipRoundedRadius: 8,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final day = data[group.x.toInt()];
              return BarTooltipItem(
                '${DateFormat('MMM d').format(day.date)}\n${day.totalTrips} trips',
                TextStyle(
                  color: colorScheme.onInverseSurface,
                  fontSize: 12,
                ),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                if (value.toInt() >= data.length) return const SizedBox();
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    dateFormat.format(data[value.toInt()].date),
                    style: TextStyle(
                      fontSize: 11,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                );
              },
              reservedSize: 28,
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                return Text(
                  value.toInt().toString(),
                  style: TextStyle(
                    fontSize: 10,
                    color: colorScheme.onSurfaceVariant,
                  ),
                );
              },
              reservedSize: 28,
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 2,
          getDrawingHorizontalLine: (value) => FlLine(
            color: colorScheme.outlineVariant.withOpacity(0.3),
            strokeWidth: 1,
          ),
        ),
        barGroups: data.asMap().entries.map((entry) {
          final index = entry.key;
          final day = entry.value;
          return BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: day.totalTrips.toDouble(),
                color: colorScheme.primary,
                width: 24,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _MonthlyRevenueChart extends StatelessWidget {
  final List<MonthlyRevenueReport> data;

  const _MonthlyRevenueChart({required this.data});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final maxRevenue = data.map((m) => m.revenue).reduce((a, b) => a > b ? a : b);

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxRevenue * 1.2,
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => colorScheme.inverseSurface,
            tooltipRoundedRadius: 8,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final month = data[group.x.toInt()];
              return BarTooltipItem(
                '${month.monthName}\n₱${_formatCurrency(month.revenue)}',
                TextStyle(
                  color: colorScheme.onInverseSurface,
                  fontSize: 12,
                ),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                if (value.toInt() >= data.length) return const SizedBox();
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    data[value.toInt()].monthName,
                    style: TextStyle(
                      fontSize: 9,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                );
              },
              reservedSize: 28,
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                return Text(
                  _formatCurrency(value),
                  style: TextStyle(
                    fontSize: 9,
                    color: colorScheme.onSurfaceVariant,
                  ),
                );
              },
              reservedSize: 40,
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (value) => FlLine(
            color: colorScheme.outlineVariant.withOpacity(0.3),
            strokeWidth: 1,
          ),
        ),
        barGroups: data.asMap().entries.map((entry) {
          final index = entry.key;
          final month = entry.value;
          final isCurrentMonth = index == DateTime.now().month - 1;
          return BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: month.revenue,
                color: isCurrentMonth ? colorScheme.primary : colorScheme.primary.withOpacity(0.5),
                width: 16,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _FleetUtilizationChart extends StatelessWidget {
  final List<VehicleUtilization> data;

  const _FleetUtilizationChart({required this.data});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final displayData = data.take(6).toList(); // Show top 6 vehicles

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: 100,
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => colorScheme.inverseSurface,
            tooltipRoundedRadius: 8,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final vehicle = displayData[group.x.toInt()];
              return BarTooltipItem(
                '${vehicle.vehicleName}\n${vehicle.utilizationPercent.toStringAsFixed(0)}%',
                TextStyle(
                  color: colorScheme.onInverseSurface,
                  fontSize: 12,
                ),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                if (value.toInt() >= displayData.length) return const SizedBox();
                final vehicle = displayData[value.toInt()];
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    vehicle.plateNumber.length > 6
                        ? vehicle.plateNumber.substring(0, 6)
                        : vehicle.plateNumber,
                    style: TextStyle(
                      fontSize: 9,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                );
              },
              reservedSize: 28,
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 25,
              getTitlesWidget: (value, meta) {
                return Text(
                  '${value.toInt()}%',
                  style: TextStyle(
                    fontSize: 10,
                    color: colorScheme.onSurfaceVariant,
                  ),
                );
              },
              reservedSize: 35,
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 25,
          getDrawingHorizontalLine: (value) => FlLine(
            color: colorScheme.outlineVariant.withOpacity(0.3),
            strokeWidth: 1,
          ),
        ),
        barGroups: displayData.asMap().entries.map((entry) {
          final index = entry.key;
          final vehicle = entry.value;
          return BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: vehicle.utilizationPercent,
                color: _getUtilizationColor(vehicle.utilizationPercent),
                width: 24,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Color _getUtilizationColor(double percent) {
    if (percent >= 70) return AppColors.success;
    if (percent >= 40) return AppColors.warning;
    return AppColors.error;
  }
}

// ============================================================
// HELPER WIDGETS
// ============================================================

class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;

  const _SummaryCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: colorScheme.outlineVariant.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 18, color: color),
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 11,
              color: colorScheme.onSurfaceVariant.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }
}

class _DailyReportRow extends StatelessWidget {
  final DailyTripsReport report;

  const _DailyReportRow({required this.report});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final dateFormat = DateFormat('EEE, MMM d');

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.outlineVariant.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              dateFormat.format(report.date),
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: _buildStat('Total', report.totalTrips.toString(), colorScheme.primary),
          ),
          Expanded(
            child: _buildStat('Done', report.completedTrips.toString(), AppColors.success),
          ),
          Expanded(
            child: _buildStat('Cancel', report.cancelledTrips.toString(), AppColors.error),
          ),
        ],
      ),
    );
  }

  Widget _buildStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: color.withOpacity(0.7),
          ),
        ),
      ],
    );
  }
}

class _MonthlyReportRow extends StatelessWidget {
  final MonthlyRevenueReport report;

  const _MonthlyReportRow({required this.report});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isCurrentMonth = report.month == DateTime.now().month;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isCurrentMonth
            ? colorScheme.primaryContainer.withOpacity(0.3)
            : colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCurrentMonth
              ? colorScheme.primary.withOpacity(0.3)
              : colorScheme.outlineVariant.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Text(
                  report.monthName,
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                    color: isCurrentMonth ? colorScheme.primary : null,
                  ),
                ),
                if (isCurrentMonth) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: colorScheme.primary,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'NOW',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onPrimary,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Text(
            '${report.tripCount} trips',
            style: TextStyle(
              fontSize: 13,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 16),
          Text(
            '₱${_formatCurrency(report.revenue)}',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _VehicleUtilizationRow extends StatelessWidget {
  final VehicleUtilization utilization;

  const _VehicleUtilizationRow({required this.utilization});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.outlineVariant.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.directions_car,
              size: 20,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  utilization.vehicleName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
                Text(
                  '${utilization.plateNumber} • ${utilization.totalTrips} trips',
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _getUtilizationColor(utilization.utilizationPercent),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${utilization.utilizationPercent.toStringAsFixed(0)}%',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: _getUtilizationColor(utilization.utilizationPercent),
                    ),
                  ),
                ],
              ),
              Text(
                '₱${_formatCurrency(utilization.totalRevenue)}',
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getUtilizationColor(double percent) {
    if (percent >= 70) return AppColors.success;
    if (percent >= 40) return AppColors.warning;
    return AppColors.error;
  }
}

String _formatCurrency(double amount) {
  if (amount >= 1000000) {
    return '${(amount / 1000000).toStringAsFixed(1)}M';
  } else if (amount >= 1000) {
    return '${(amount / 1000).toStringAsFixed(1)}K';
  }
  return amount.toStringAsFixed(0);
}
