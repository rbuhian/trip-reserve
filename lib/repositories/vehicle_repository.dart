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
