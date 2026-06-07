import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/earnings.dart';
import '../providers/supabase_provider.dart';

/// Provider for EarningsRepository
final earningsRepositoryProvider = Provider<EarningsRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return EarningsRepository(client);
});

/// Repository for driver earnings operations
class EarningsRepository {
  final SupabaseClient _client;

  EarningsRepository(this._client);

  SupabaseQueryBuilder get _table => _client.from('driver_earnings');

  /// Get current user's ID
  String? get _currentUserId => _client.auth.currentUser?.id;

  /// Get weekly earnings summary for the current driver
  Future<EarningsSummary> getWeeklySummary() async {
    if (_currentUserId == null) {
      throw Exception('User not authenticated');
    }

    final now = DateTime.now();
    // Get start of current week (Monday)
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final periodStart = DateTime(weekStart.year, weekStart.month, weekStart.day);
    final periodEnd = periodStart.add(const Duration(days: 7));

    return _getSummaryForPeriod(periodStart, periodEnd);
  }

  /// Get monthly earnings summary for the current driver
  Future<EarningsSummary> getMonthlySummary() async {
    if (_currentUserId == null) {
      throw Exception('User not authenticated');
    }

    final now = DateTime.now();
    final periodStart = DateTime(now.year, now.month, 1);
    final periodEnd = DateTime(now.year, now.month + 1, 1);

    return _getSummaryForPeriod(periodStart, periodEnd);
  }

  /// Get earnings summary for a specific period
  Future<EarningsSummary> _getSummaryForPeriod(
    DateTime periodStart,
    DateTime periodEnd,
  ) async {
    final response = await _table
        .select()
        .eq('driver_id', _currentUserId!)
        .gte('created_at', periodStart.toIso8601String())
        .lt('created_at', periodEnd.toIso8601String());

    final earnings = (response as List)
        .map((json) => DriverEarning.fromJson(json))
        .toList();

    if (earnings.isEmpty) {
      return EarningsSummary.empty(
        periodStart: periodStart,
        periodEnd: periodEnd,
      );
    }

    double totalGross = 0;
    double totalFees = 0;
    double totalNet = 0;
    double pendingAmount = 0;
    double paidAmount = 0;

    for (final earning in earnings) {
      totalGross += earning.grossAmount;
      totalFees += earning.platformFee;
      totalNet += earning.netAmount;

      if (earning.status == EarningsStatus.pending) {
        pendingAmount += earning.netAmount;
      } else {
        paidAmount += earning.netAmount;
      }
    }

    return EarningsSummary(
      totalGross: totalGross,
      totalFees: totalFees,
      totalNet: totalNet,
      pendingAmount: pendingAmount,
      paidAmount: paidAmount,
      tripCount: earnings.length,
      periodStart: periodStart,
      periodEnd: periodEnd,
    );
  }

  /// Get all earnings for the current driver
  Future<List<DriverEarning>> getAll({int limit = 50}) async {
    if (_currentUserId == null) {
      throw Exception('User not authenticated');
    }

    final response = await _table
        .select()
        .eq('driver_id', _currentUserId!)
        .order('created_at', ascending: false)
        .limit(limit);

    return (response as List)
        .map((json) => DriverEarning.fromJson(json))
        .toList();
  }

  /// Get pending earnings for the current driver
  Future<List<DriverEarning>> getPending() async {
    if (_currentUserId == null) {
      throw Exception('User not authenticated');
    }

    final response = await _table
        .select()
        .eq('driver_id', _currentUserId!)
        .eq('status', 'pending')
        .order('created_at', ascending: false);

    return (response as List)
        .map((json) => DriverEarning.fromJson(json))
        .toList();
  }

  /// Get total pending amount
  Future<double> getTotalPending() async {
    if (_currentUserId == null) {
      throw Exception('User not authenticated');
    }

    final response = await _table
        .select('net_amount')
        .eq('driver_id', _currentUserId!)
        .eq('status', 'pending');

    double total = 0;
    for (final row in response as List) {
      total += (row['net_amount'] as num).toDouble();
    }

    return total;
  }

  /// Get completed trips count for current week
  Future<int> getWeeklyTripCount() async {
    if (_currentUserId == null) {
      throw Exception('User not authenticated');
    }

    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final periodStart = DateTime(weekStart.year, weekStart.month, weekStart.day);

    final response = await _table
        .select('id')
        .eq('driver_id', _currentUserId!)
        .gte('created_at', periodStart.toIso8601String());

    return (response as List).length;
  }

  /// Get total completed trips count
  Future<int> getTotalTripCount() async {
    if (_currentUserId == null) {
      throw Exception('User not authenticated');
    }

    final response = await _table
        .select('id')
        .eq('driver_id', _currentUserId!);

    return (response as List).length;
  }
}
