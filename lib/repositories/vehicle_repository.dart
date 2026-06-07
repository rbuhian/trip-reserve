import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/vehicle.dart';
import '../providers/supabase_provider.dart';

/// Provider for VehicleRepository
final vehicleRepositoryProvider = Provider<VehicleRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return VehicleRepository(client);
});

/// Repository for vehicle CRUD operations
class VehicleRepository {
  final SupabaseClient _client;

  VehicleRepository(this._client);

  SupabaseQueryBuilder get _table => _client.from('vehicles');

  /// Get current user's ID
  String? get _currentUserId => _client.auth.currentUser?.id;

  /// Get all vehicles for the current driver
  Future<List<Vehicle>> getMyVehicles() async {
    if (_currentUserId == null) {
      throw Exception('User not authenticated');
    }

    final response = await _table
        .select()
        .eq('driver_id', _currentUserId!)
        .order('created_at', ascending: false);

    return (response as List)
        .map((json) => Vehicle.fromJson(json))
        .toList();
  }

  /// Get active vehicles for the current driver
  Future<List<Vehicle>> getMyActiveVehicles() async {
    if (_currentUserId == null) {
      throw Exception('User not authenticated');
    }

    final response = await _table
        .select()
        .eq('driver_id', _currentUserId!)
        .eq('is_active', true)
        .order('created_at', ascending: false);

    return (response as List)
        .map((json) => Vehicle.fromJson(json))
        .toList();
  }

  /// Get a single vehicle by ID
  Future<Vehicle?> getById(String id) async {
    final response = await _table
        .select()
        .eq('id', id)
        .maybeSingle();

    return response != null ? Vehicle.fromJson(response) : null;
  }

  /// Get all active vehicles (for customer booking)
  Future<List<Vehicle>> getAvailableVehicles() async {
    final response = await _table
        .select('''
          *,
          driver:users!driver_id(id, full_name, phone, avatar_url)
        ''')
        .eq('is_active', true)
        .order('name');

    return (response as List)
        .map((json) => Vehicle.fromJson(json))
        .toList();
  }

  /// Get vehicles available for a specific date and time
  ///
  /// Checks against:
  /// 1. Driver availability blocks (time-offs, vacations, maintenance)
  /// 2. Existing confirmed/in-progress bookings
  Future<List<Vehicle>> getAvailableVehiclesForDateTime({
    required DateTime date,
    required String pickupTime,
    int estimatedDurationMinutes = 120,
  }) async {
    final dateStr = date.toIso8601String().split('T')[0];

    // Calculate estimated end time
    final timeParts = pickupTime.split(':');
    final startHour = int.parse(timeParts[0]);
    final startMinute = int.parse(timeParts[1]);
    final startMinutes = startHour * 60 + startMinute;
    final endMinutes = startMinutes + estimatedDurationMinutes;
    final endHour = (endMinutes ~/ 60).clamp(0, 23);
    final endMinute = endMinutes % 60;
    final endTime = '${endHour.toString().padLeft(2, '0')}:${endMinute.toString().padLeft(2, '0')}';

    // Get all active vehicles
    final vehiclesResponse = await _table
        .select('''
          *,
          driver:users!driver_id(id, full_name, phone, avatar_url)
        ''')
        .eq('is_active', true)
        .order('name');

    final allVehicles = (vehiclesResponse as List)
        .map((json) => Vehicle.fromJson(json))
        .toList();

    if (allVehicles.isEmpty) return [];

    // Get driver IDs from vehicles
    final driverIds = allVehicles
        .where((v) => v.driverId != null)
        .map((v) => v.driverId!)
        .toSet()
        .toList();

    // Get vehicle IDs
    final vehicleIds = allVehicles.map((v) => v.id).toList();

    // Check for availability blocks (driver time-offs)
    Set<String> blockedDrivers = {};
    if (driverIds.isNotEmpty) {
      // Check for full-day blocks
      final fullDayBlocks = await _client
          .from('availability_blocks')
          .select('driver_id')
          .inFilter('driver_id', driverIds)
          .eq('block_date', dateStr)
          .eq('is_full_day', true);

      for (final block in fullDayBlocks as List) {
        blockedDrivers.add(block['driver_id'] as String);
      }

      // Check for partial blocks that overlap with requested time
      final partialBlocks = await _client
          .from('availability_blocks')
          .select('driver_id, start_time, end_time')
          .inFilter('driver_id', driverIds)
          .eq('block_date', dateStr)
          .eq('is_full_day', false);

      for (final block in partialBlocks as List) {
        final blockStart = block['start_time'] as String? ?? '00:00';
        final blockEnd = block['end_time'] as String? ?? '23:59';
        if (_timesOverlap(pickupTime, endTime, blockStart, blockEnd)) {
          blockedDrivers.add(block['driver_id'] as String);
        }
      }
    }

    // Check for existing bookings (confirmed or in_progress)
    Set<String> bookedVehicles = {};
    if (vehicleIds.isNotEmpty) {
      final existingBookings = await _client
          .from('bookings')
          .select('vehicle_id, pickup_time, duration_minutes')
          .inFilter('vehicle_id', vehicleIds)
          .eq('scheduled_date', dateStr)
          .inFilter('status', ['confirmed', 'in_progress']);

      for (final booking in existingBookings as List) {
        final bookingStart = booking['pickup_time'] as String;
        final bookingDuration = booking['duration_minutes'] as int? ?? 120;

        // Calculate booking end time
        final bookingTimeParts = bookingStart.split(':');
        final bookingStartMinutes = int.parse(bookingTimeParts[0]) * 60 + int.parse(bookingTimeParts[1]);
        final bookingEndMinutes = bookingStartMinutes + bookingDuration;
        final bookingEndHour = (bookingEndMinutes ~/ 60).clamp(0, 23);
        final bookingEndMinute = bookingEndMinutes % 60;
        final bookingEnd = '${bookingEndHour.toString().padLeft(2, '0')}:${bookingEndMinute.toString().padLeft(2, '0')}';

        if (_timesOverlap(pickupTime, endTime, bookingStart, bookingEnd)) {
          bookedVehicles.add(booking['vehicle_id'] as String);
        }
      }
    }

    // Filter out unavailable vehicles
    return allVehicles.where((vehicle) {
      // Check if driver is blocked
      if (vehicle.driverId != null && blockedDrivers.contains(vehicle.driverId)) {
        return false;
      }
      // Check if vehicle is booked
      if (bookedVehicles.contains(vehicle.id)) {
        return false;
      }
      return true;
    }).toList();
  }

  /// Check if two time ranges overlap
  bool _timesOverlap(String start1, String end1, String start2, String end2) {
    // Simple string comparison works for HH:MM format
    return start1.compareTo(end2) < 0 && start2.compareTo(end1) < 0;
  }

  /// Create a new vehicle
  Future<Vehicle> create(VehicleCreate data) async {
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

    return Vehicle.fromJson(response);
  }

  /// Update a vehicle
  Future<Vehicle> update(String id, VehicleUpdate data) async {
    final response = await _table
        .update(data.toJson()..removeWhere((_, v) => v == null))
        .eq('id', id)
        .select()
        .single();

    return Vehicle.fromJson(response);
  }

  /// Deactivate a vehicle (soft delete)
  Future<void> deactivate(String id) async {
    await _table
        .update({'is_active': false})
        .eq('id', id);
  }

  /// Reactivate a vehicle
  Future<void> reactivate(String id) async {
    await _table
        .update({'is_active': true})
        .eq('id', id);
  }

  /// Delete a vehicle permanently
  Future<void> delete(String id) async {
    await _table.delete().eq('id', id);
  }

  /// Check if plate number is unique
  Future<bool> isPlateNumberUnique(String plateNumber, {String? excludeId}) async {
    var query = _table
        .select('id')
        .eq('plate_number', plateNumber)
        .eq('is_active', true);

    if (excludeId != null) {
      query = query.neq('id', excludeId);
    }

    final response = await query;
    return (response as List).isEmpty;
  }
}
