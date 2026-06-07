import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/booking.dart';
import '../models/enums.dart';
import '../models/user.dart' as app_user;
import '../providers/supabase_provider.dart';

/// Provider for AdminRepository
final adminRepositoryProvider = Provider<AdminRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return AdminRepository(client);
});

/// Dashboard statistics
class DashboardStats {
  final int tripsToday;
  final int tripsTodayChange; // vs average
  final double revenueMtd;
  final double revenueMtdChange; // % change vs last month
  final double fleetUtilization; // % of vehicles with bookings
  final int activeVehicles;
  final int totalVehicles;

  DashboardStats({
    required this.tripsToday,
    required this.tripsTodayChange,
    required this.revenueMtd,
    required this.revenueMtdChange,
    required this.fleetUtilization,
    required this.activeVehicles,
    required this.totalVehicles,
  });

  factory DashboardStats.empty() => DashboardStats(
    tripsToday: 0,
    tripsTodayChange: 0,
    revenueMtd: 0,
    revenueMtdChange: 0,
    fleetUtilization: 0,
    activeVehicles: 0,
    totalVehicles: 0,
  );
}

/// Repository for admin operations
class AdminRepository {
  final SupabaseClient _client;

  AdminRepository(this._client);

  SupabaseQueryBuilder get _bookingsTable => _client.from('bookings');
  SupabaseQueryBuilder get _vehiclesTable => _client.from('vehicles');
  SupabaseQueryBuilder get _usersTable => _client.from('users');

  /// Get dashboard statistics
  Future<DashboardStats> getDashboardStats() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final monthStart = DateTime(now.year, now.month, 1);
    final lastMonthStart = DateTime(now.year, now.month - 1, 1);
    final lastMonthEnd = DateTime(now.year, now.month, 1);

    // Get trips today
    final tripsToday = await _getTripsForDate(today);

    // Calculate average daily trips (last 30 days)
    final thirtyDaysAgo = today.subtract(const Duration(days: 30));
    final last30DaysTrips = await _getCompletedTripsInRange(thirtyDaysAgo, today);
    final avgDailyTrips = last30DaysTrips / 30;
    final tripsTodayChange = avgDailyTrips > 0
        ? ((tripsToday - avgDailyTrips) / avgDailyTrips * 100).round()
        : 0;

    // Get revenue MTD
    final revenueMtd = await _getRevenueInRange(monthStart, now);

    // Get last month revenue for comparison
    final lastMonthRevenue = await _getRevenueInRange(lastMonthStart, lastMonthEnd);
    final revenueMtdChange = lastMonthRevenue > 0
        ? ((revenueMtd - lastMonthRevenue) / lastMonthRevenue * 100)
        : 0;

    // Get vehicle stats
    final vehicleStats = await _getVehicleStats();

    // Calculate fleet utilization (vehicles with bookings today / active vehicles)
    final vehiclesWithBookingsToday = await _getVehiclesWithBookingsOnDate(today);
    final fleetUtilization = vehicleStats['active']! > 0
        ? (vehiclesWithBookingsToday / vehicleStats['active']! * 100)
        : 0;

    return DashboardStats(
      tripsToday: tripsToday,
      tripsTodayChange: tripsTodayChange,
      revenueMtd: revenueMtd,
      revenueMtdChange: revenueMtdChange,
      fleetUtilization: fleetUtilization,
      activeVehicles: vehicleStats['active']!,
      totalVehicles: vehicleStats['total']!,
    );
  }

  /// Get trips count for a specific date
  Future<int> _getTripsForDate(DateTime date) async {
    final dateStr = date.toIso8601String().split('T')[0];

    final response = await _bookingsTable
        .select('id')
        .eq('scheduled_date', dateStr)
        .inFilter('status', ['confirmed', 'in_progress', 'completed']);

    return (response as List).length;
  }

  /// Get completed trips count in date range
  Future<int> _getCompletedTripsInRange(DateTime start, DateTime end) async {
    final response = await _bookingsTable
        .select('id')
        .gte('scheduled_date', start.toIso8601String().split('T')[0])
        .lt('scheduled_date', end.toIso8601String().split('T')[0])
        .eq('status', 'completed');

    return (response as List).length;
  }

  /// Get total revenue in date range
  Future<double> _getRevenueInRange(DateTime start, DateTime end) async {
    final response = await _bookingsTable
        .select('total_amount')
        .gte('completed_at', start.toIso8601String())
        .lt('completed_at', end.toIso8601String())
        .eq('status', 'completed');

    double total = 0;
    for (final row in response as List) {
      total += (row['total_amount'] as num).toDouble();
    }

    return total;
  }

  /// Get vehicle statistics
  Future<Map<String, int>> _getVehicleStats() async {
    final response = await _vehiclesTable.select('id, is_active');

    final vehicles = response as List;
    final active = vehicles.where((v) => v['is_active'] == true).length;

    return {
      'total': vehicles.length,
      'active': active,
    };
  }

  /// Get count of vehicles with bookings on a date
  Future<int> _getVehiclesWithBookingsOnDate(DateTime date) async {
    final dateStr = date.toIso8601String().split('T')[0];

    final response = await _bookingsTable
        .select('vehicle_id')
        .eq('scheduled_date', dateStr)
        .inFilter('status', ['confirmed', 'in_progress', 'completed'])
        .not('vehicle_id', 'is', null);

    // Count unique vehicle IDs
    final vehicleIds = <String>{};
    for (final row in response as List) {
      if (row['vehicle_id'] != null) {
        vehicleIds.add(row['vehicle_id'] as String);
      }
    }

    return vehicleIds.length;
  }

  /// Get recent bookings for admin dashboard
  Future<List<BookingListItem>> getRecentBookings({int limit = 10}) async {
    final response = await _bookingsTable
        .select('''
          id, reference_number, status,
          pickup_address, dropoff_address,
          scheduled_date, pickup_time, total_amount, created_at,
          customer:users!customer_id(id, full_name, phone, avatar_url),
          driver:users!driver_id(id, full_name, phone, avatar_url),
          vehicle:vehicles!vehicle_id(id, name, plate_number, capacity, image_url)
        ''')
        .order('created_at', ascending: false)
        .limit(limit);

    return (response as List)
        .map((json) => BookingListItem.fromJson(json))
        .toList();
  }

  /// Get all bookings with optional filters
  Future<List<BookingListItem>> getAllBookings({
    BookingStatus? status,
    int limit = 50,
    int offset = 0,
  }) async {
    var query = _bookingsTable
        .select('''
          id, reference_number, status,
          pickup_address, dropoff_address,
          scheduled_date, pickup_time, total_amount, created_at,
          customer:users!customer_id(id, full_name, phone, avatar_url),
          driver:users!driver_id(id, full_name, phone, avatar_url),
          vehicle:vehicles!vehicle_id(id, name, plate_number, capacity, image_url)
        ''');

    if (status != null) {
      query = query.eq('status', status.name);
    }

    final response = await query
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);

    return (response as List)
        .map((json) => BookingListItem.fromJson(json))
        .toList();
  }

  /// Get booking counts by status
  Future<Map<BookingStatus, int>> getBookingCountsByStatus() async {
    final counts = <BookingStatus, int>{};

    for (final status in BookingStatus.values) {
      final response = await _bookingsTable
          .select('id')
          .eq('status', status.name);

      counts[status] = (response as List).length;
    }

    return counts;
  }

  // ============================================================
  // USER MANAGEMENT
  // ============================================================

  /// Get all users with optional filters
  Future<List<app_user.User>> getAllUsers({
    UserRole? role,
    bool? isActive,
    String? searchQuery,
    int limit = 50,
    int offset = 0,
  }) async {
    var query = _usersTable.select();

    if (role != null) {
      query = query.eq('role', role.name);
    }

    if (isActive != null) {
      query = query.eq('is_active', isActive);
    }

    final response = await query
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);

    var users = (response as List)
        .map((json) => app_user.User.fromJson(json))
        .toList();

    // Filter by search query if provided
    if (searchQuery != null && searchQuery.isNotEmpty) {
      final lowerQuery = searchQuery.toLowerCase();
      users = users.where((user) {
        return user.fullName.toLowerCase().contains(lowerQuery) ||
            user.email.toLowerCase().contains(lowerQuery) ||
            (user.phone?.contains(lowerQuery) ?? false);
      }).toList();
    }

    return users;
  }

  /// Get user by ID
  Future<app_user.User?> getUserById(String id) async {
    final response = await _usersTable
        .select()
        .eq('id', id)
        .maybeSingle();

    if (response == null) return null;
    return app_user.User.fromJson(response);
  }

  /// Update user details
  Future<app_user.User> updateUser(String id, Map<String, dynamic> updates) async {
    updates['updated_at'] = DateTime.now().toIso8601String();

    final response = await _usersTable
        .update(updates)
        .eq('id', id)
        .select()
        .single();

    return app_user.User.fromJson(response);
  }

  /// Deactivate user
  Future<void> deactivateUser(String id) async {
    await _usersTable
        .update({
          'is_active': false,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', id);
  }

  /// Reactivate user
  Future<void> reactivateUser(String id) async {
    await _usersTable
        .update({
          'is_active': true,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', id);
  }

  /// Get user counts by role
  Future<Map<UserRole, int>> getUserCountsByRole() async {
    final counts = <UserRole, int>{};

    for (final role in UserRole.values) {
      final response = await _usersTable
          .select('id')
          .eq('role', role.name);

      counts[role] = (response as List).length;
    }

    return counts;
  }

  // ============================================================
  // REPORTS
  // ============================================================

  /// Get daily trips report for a date range
  Future<List<DailyTripsReport>> getDailyTripsReport({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final reports = <DailyTripsReport>[];
    var currentDate = startDate;

    while (!currentDate.isAfter(endDate)) {
      final dateStr = currentDate.toIso8601String().split('T')[0];

      final response = await _bookingsTable
          .select('id, status, total_amount')
          .eq('scheduled_date', dateStr);

      final bookings = response as List;
      final completed = bookings.where((b) => b['status'] == 'completed').length;
      final cancelled = bookings.where((b) => b['status'] == 'cancelled').length;
      final pending = bookings.where((b) =>
          b['status'] == 'pending' ||
          b['status'] == 'confirmed' ||
          b['status'] == 'in_progress'
      ).length;

      double revenue = 0;
      for (final b in bookings.where((b) => b['status'] == 'completed')) {
        revenue += (b['total_amount'] as num).toDouble();
      }

      reports.add(DailyTripsReport(
        date: currentDate,
        totalTrips: bookings.length,
        completedTrips: completed,
        cancelledTrips: cancelled,
        pendingTrips: pending,
        revenue: revenue,
      ));

      currentDate = currentDate.add(const Duration(days: 1));
    }

    return reports;
  }

  /// Get monthly revenue report for the year
  Future<List<MonthlyRevenueReport>> getMonthlyRevenueReport(int year) async {
    final reports = <MonthlyRevenueReport>[];

    for (int month = 1; month <= 12; month++) {
      final monthStart = DateTime(year, month, 1);
      final monthEnd = DateTime(year, month + 1, 1);

      final response = await _bookingsTable
          .select('total_amount')
          .gte('completed_at', monthStart.toIso8601String())
          .lt('completed_at', monthEnd.toIso8601String())
          .eq('status', 'completed');

      double revenue = 0;
      int tripCount = 0;
      for (final row in response as List) {
        revenue += (row['total_amount'] as num).toDouble();
        tripCount++;
      }

      reports.add(MonthlyRevenueReport(
        year: year,
        month: month,
        revenue: revenue,
        tripCount: tripCount,
      ));
    }

    return reports;
  }

  /// Get fleet utilization report
  Future<FleetUtilizationReport> getFleetUtilizationReport({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    // Get all active vehicles
    final vehiclesResponse = await _vehiclesTable
        .select('id, name, plate_number')
        .eq('is_active', true);

    final vehicles = vehiclesResponse as List;
    final vehicleUtilizations = <VehicleUtilization>[];

    final totalDays = endDate.difference(startDate).inDays + 1;

    for (final vehicle in vehicles) {
      final vehicleId = vehicle['id'] as String;

      // Get bookings for this vehicle in the date range
      final bookingsResponse = await _bookingsTable
          .select('id, scheduled_date, total_amount, status')
          .eq('vehicle_id', vehicleId)
          .gte('scheduled_date', startDate.toIso8601String().split('T')[0])
          .lte('scheduled_date', endDate.toIso8601String().split('T')[0])
          .inFilter('status', ['confirmed', 'in_progress', 'completed']);

      final bookings = bookingsResponse as List;

      // Count unique days with bookings
      final bookedDays = <String>{};
      double totalRevenue = 0;

      for (final booking in bookings) {
        bookedDays.add(booking['scheduled_date'] as String);
        if (booking['status'] == 'completed') {
          totalRevenue += (booking['total_amount'] as num).toDouble();
        }
      }

      final utilizationPercent = totalDays > 0
          ? (bookedDays.length / totalDays * 100)
          : 0.0;

      vehicleUtilizations.add(VehicleUtilization(
        vehicleId: vehicleId,
        vehicleName: vehicle['name'] as String,
        plateNumber: vehicle['plate_number'] as String,
        totalDays: totalDays,
        bookedDays: bookedDays.length,
        utilizationPercent: utilizationPercent,
        totalTrips: bookings.length,
        totalRevenue: totalRevenue,
      ));
    }

    // Sort by utilization descending
    vehicleUtilizations.sort((a, b) => b.utilizationPercent.compareTo(a.utilizationPercent));

    // Calculate overall stats
    final totalVehicles = vehicles.length;
    final avgUtilization = vehicleUtilizations.isNotEmpty
        ? vehicleUtilizations.map((v) => v.utilizationPercent).reduce((a, b) => a + b) / vehicleUtilizations.length
        : 0.0;
    final totalTrips = vehicleUtilizations.map((v) => v.totalTrips).fold(0, (a, b) => a + b);
    final totalRevenue = vehicleUtilizations.map((v) => v.totalRevenue).fold(0.0, (a, b) => a + b);

    return FleetUtilizationReport(
      startDate: startDate,
      endDate: endDate,
      totalVehicles: totalVehicles,
      averageUtilization: avgUtilization,
      totalTrips: totalTrips,
      totalRevenue: totalRevenue,
      vehicleUtilizations: vehicleUtilizations,
    );
  }
}

// ============================================================
// REPORT MODELS
// ============================================================

/// Daily trips report
class DailyTripsReport {
  final DateTime date;
  final int totalTrips;
  final int completedTrips;
  final int cancelledTrips;
  final int pendingTrips;
  final double revenue;

  DailyTripsReport({
    required this.date,
    required this.totalTrips,
    required this.completedTrips,
    required this.cancelledTrips,
    required this.pendingTrips,
    required this.revenue,
  });
}

/// Monthly revenue report
class MonthlyRevenueReport {
  final int year;
  final int month;
  final double revenue;
  final int tripCount;

  MonthlyRevenueReport({
    required this.year,
    required this.month,
    required this.revenue,
    required this.tripCount,
  });

  String get monthName {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month - 1];
  }
}

/// Vehicle utilization data
class VehicleUtilization {
  final String vehicleId;
  final String vehicleName;
  final String plateNumber;
  final int totalDays;
  final int bookedDays;
  final double utilizationPercent;
  final int totalTrips;
  final double totalRevenue;

  VehicleUtilization({
    required this.vehicleId,
    required this.vehicleName,
    required this.plateNumber,
    required this.totalDays,
    required this.bookedDays,
    required this.utilizationPercent,
    required this.totalTrips,
    required this.totalRevenue,
  });
}

/// Fleet utilization report
class FleetUtilizationReport {
  final DateTime startDate;
  final DateTime endDate;
  final int totalVehicles;
  final double averageUtilization;
  final int totalTrips;
  final double totalRevenue;
  final List<VehicleUtilization> vehicleUtilizations;

  FleetUtilizationReport({
    required this.startDate,
    required this.endDate,
    required this.totalVehicles,
    required this.averageUtilization,
    required this.totalTrips,
    required this.totalRevenue,
    required this.vehicleUtilizations,
  });
}
