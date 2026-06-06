import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/availability_block.dart';
import '../providers/supabase_provider.dart';

/// Provider for AvailabilityRepository
final availabilityRepositoryProvider = Provider<AvailabilityRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return AvailabilityRepository(client);
});

/// Repository for availability block operations
class AvailabilityRepository {
  final SupabaseClient _client;

  AvailabilityRepository(this._client);

  SupabaseQueryBuilder get _table => _client.from('availability_blocks');

  /// Get current user's ID
  String? get _currentUserId => _client.auth.currentUser?.id;

  /// Get all blocks for the current driver in a date range
  Future<List<AvailabilityBlock>> getBlocksInRange({
    required DateTime startDate,
    required DateTime endDate,
    String? vehicleId,
  }) async {
    if (_currentUserId == null) {
      throw Exception('User not authenticated');
    }

    var query = _table
        .select()
        .eq('driver_id', _currentUserId!)
        .gte('block_date', startDate.toIso8601String().split('T')[0])
        .lte('block_date', endDate.toIso8601String().split('T')[0]);

    if (vehicleId != null) {
      query = query.eq('vehicle_id', vehicleId);
    }

    final response = await query.order('block_date');

    return (response as List)
        .map((json) => AvailabilityBlock.fromJson(json))
        .toList();
  }

  /// Get blocks for a specific date
  Future<List<AvailabilityBlock>> getBlocksForDate(DateTime date) async {
    if (_currentUserId == null) {
      throw Exception('User not authenticated');
    }

    final dateStr = date.toIso8601String().split('T')[0];

    final response = await _table
        .select()
        .eq('driver_id', _currentUserId!)
        .eq('block_date', dateStr)
        .order('start_time');

    return (response as List)
        .map((json) => AvailabilityBlock.fromJson(json))
        .toList();
  }

  /// Get blocks for a month (for calendar display)
  Future<Map<DateTime, List<AvailabilityBlock>>> getBlocksForMonth(
    int year,
    int month,
  ) async {
    final startDate = DateTime(year, month, 1);
    final endDate = DateTime(year, month + 1, 0); // Last day of month

    final blocks = await getBlocksInRange(
      startDate: startDate,
      endDate: endDate,
    );

    // Group by date
    final Map<DateTime, List<AvailabilityBlock>> grouped = {};
    for (final block in blocks) {
      final date = DateTime(
        block.blockDate.year,
        block.blockDate.month,
        block.blockDate.day,
      );
      grouped.putIfAbsent(date, () => []).add(block);
    }

    return grouped;
  }

  /// Create a new availability block
  Future<AvailabilityBlock> create(AvailabilityBlockCreate data) async {
    if (_currentUserId == null) {
      throw Exception('User not authenticated');
    }

    final response = await _table
        .insert({
          ...data.toJson(),
          'driver_id': _currentUserId,
        })
        .select()
        .single();

    return AvailabilityBlock.fromJson(response);
  }

  /// Create a full-day block
  Future<AvailabilityBlock> blockFullDay({
    required DateTime date,
    required String reason,
    String? vehicleId,
    String? notes,
  }) async {
    return create(AvailabilityBlockCreate(
      blockDate: date,
      isFullDay: true,
      reason: _parseReason(reason),
      vehicleId: vehicleId,
      notes: notes,
    ));
  }

  /// Create a partial-day block
  Future<AvailabilityBlock> blockTimeSlot({
    required DateTime date,
    required String startTime,
    required String endTime,
    required String reason,
    String? vehicleId,
    String? notes,
  }) async {
    return create(AvailabilityBlockCreate(
      blockDate: date,
      isFullDay: false,
      startTime: startTime,
      endTime: endTime,
      reason: _parseReason(reason),
      vehicleId: vehicleId,
      notes: notes,
    ));
  }

  /// Update a block
  Future<AvailabilityBlock> update(
    String id,
    AvailabilityBlockCreate data,
  ) async {
    final response = await _table
        .update(data.toJson())
        .eq('id', id)
        .select()
        .single();

    return AvailabilityBlock.fromJson(response);
  }

  /// Delete a block
  Future<void> delete(String id) async {
    await _table.delete().eq('id', id);
  }

  /// Delete all blocks for a specific date
  Future<void> deleteBlocksForDate(DateTime date) async {
    if (_currentUserId == null) {
      throw Exception('User not authenticated');
    }

    final dateStr = date.toIso8601String().split('T')[0];

    await _table
        .delete()
        .eq('driver_id', _currentUserId!)
        .eq('block_date', dateStr)
        .isFilter('booking_id', null); // Don't delete booking-related blocks
  }

  /// Check if a time slot is available
  Future<bool> isTimeSlotAvailable({
    required DateTime date,
    required String startTime,
    required String endTime,
    String? vehicleId,
  }) async {
    if (_currentUserId == null) return false;

    final dateStr = date.toIso8601String().split('T')[0];

    // Check for full-day blocks
    var query = _table
        .select('id')
        .eq('driver_id', _currentUserId!)
        .eq('block_date', dateStr)
        .eq('is_full_day', true);

    if (vehicleId != null) {
      query = query.or('vehicle_id.is.null,vehicle_id.eq.$vehicleId');
    }

    final fullDayBlocks = await query;
    if ((fullDayBlocks as List).isNotEmpty) {
      return false;
    }

    // Check for overlapping partial blocks
    // This is a simplified check - in production, you'd want more sophisticated overlap detection
    final partialBlocks = await _table
        .select('id, start_time, end_time')
        .eq('driver_id', _currentUserId!)
        .eq('block_date', dateStr)
        .eq('is_full_day', false);

    for (final block in partialBlocks as List) {
      final blockStart = block['start_time'] as String;
      final blockEnd = block['end_time'] as String;

      // Check for overlap
      if (_timesOverlap(startTime, endTime, blockStart, blockEnd)) {
        return false;
      }
    }

    return true;
  }

  bool _timesOverlap(
    String start1,
    String end1,
    String start2,
    String end2,
  ) {
    // Simple string comparison works for HH:MM format
    return start1.compareTo(end2) < 0 && start2.compareTo(end1) < 0;
  }

  BlockReason _parseReason(String reason) {
    return BlockReason.values.firstWhere(
      (r) => r.value == reason || r.name == reason,
      orElse: () => BlockReason.personal,
    );
  }
}
