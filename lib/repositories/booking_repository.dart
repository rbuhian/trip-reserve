import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/booking.dart';
import '../models/enums.dart';
import '../models/pricing.dart';
import '../providers/supabase_provider.dart';

/// Provider for BookingRepository
final bookingRepositoryProvider = Provider<BookingRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return BookingRepository(client);
});

/// Repository for booking CRUD operations
class BookingRepository {
  final SupabaseClient _client;

  BookingRepository(this._client);

  SupabaseQueryBuilder get _table => _client.from('bookings');
  SupabaseQueryBuilder get _addonsTable => _client.from('booking_addons');

  /// Get current user's ID
  String? get _currentUserId => _client.auth.currentUser?.id;

  /// Generate a unique reference number
  String _generateReferenceNumber() {
    final now = DateTime.now();
    final datePart = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final timePart = '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
    final randomPart = (now.millisecond % 1000).toString().padLeft(3, '0');
    return 'TR$datePart$timePart$randomPart';
  }

  /// Create a new booking
  Future<Booking> create(BookingCreate data, {List<BookingAddonCreate>? addons}) async {
    if (_currentUserId == null) {
      throw Exception('User not authenticated');
    }

    final referenceNumber = _generateReferenceNumber();

    // Insert booking
    final bookingResponse = await _table
        .insert({
          ...data.toJson(),
          'customer_id': _currentUserId,
          'reference_number': referenceNumber,
          'status': BookingStatus.pending.value,
        })
        .select('''
          *,
          customer:users!customer_id(id, full_name, phone, avatar_url),
          driver:users!driver_id(id, full_name, phone, avatar_url),
          vehicle:vehicles!vehicle_id(id, name, plate_number, category, capacity, image_url)
        ''')
        .single();

    final booking = Booking.fromJson(bookingResponse);

    // Insert addons if any
    if (addons != null && addons.isNotEmpty) {
      await _addonsTable.insert(
        addons.map((a) => {
          ...a.toJson(),
          'booking_id': booking.id,
        }).toList(),
      );
    }

    return booking;
  }

  /// Get a booking by ID
  Future<Booking?> getById(String id) async {
    final response = await _table
        .select('''
          *,
          customer:users!customer_id(id, full_name, phone, avatar_url),
          driver:users!driver_id(id, full_name, phone, avatar_url),
          vehicle:vehicles!vehicle_id(id, name, plate_number, category, capacity, image_url)
        ''')
        .eq('id', id)
        .maybeSingle();

    return response != null ? Booking.fromJson(response) : null;
  }

  /// Get a booking by reference number
  Future<Booking?> getByReferenceNumber(String referenceNumber) async {
    final response = await _table
        .select('''
          *,
          customer:users!customer_id(id, full_name, phone, avatar_url),
          driver:users!driver_id(id, full_name, phone, avatar_url),
          vehicle:vehicles!vehicle_id(id, name, plate_number, category, capacity, image_url)
        ''')
        .eq('reference_number', referenceNumber)
        .maybeSingle();

    return response != null ? Booking.fromJson(response) : null;
  }

  /// Get current customer's bookings
  Future<List<BookingListItem>> getMyBookings({
    BookingStatus? status,
    int limit = 20,
    int offset = 0,
  }) async {
    if (_currentUserId == null) {
      throw Exception('User not authenticated');
    }

    var query = _table
        .select('''
          id, reference_number, status, category, num_bags, additional_info,
          pickup_address, dropoff_address,
          scheduled_date, pickup_time, total_amount, created_at,
          driver:users!driver_id(id, full_name, phone, avatar_url),
          vehicle:vehicles!vehicle_id(id, name, plate_number, category, capacity, image_url)
        ''')
        .eq('customer_id', _currentUserId!);

    if (status != null) {
      query = query.eq('status', status.value);
    }

    final response = await query
        .order('scheduled_date', ascending: false)
        .range(offset, offset + limit - 1);

    return (response as List)
        .map((json) => BookingListItem.fromJson(json))
        .toList();
  }

  /// Get upcoming bookings for customer
  Future<List<BookingListItem>> getUpcomingBookings() async {
    if (_currentUserId == null) {
      throw Exception('User not authenticated');
    }

    final today = DateTime.now().toIso8601String().split('T')[0];

    final response = await _table
        .select('''
          id, reference_number, status, category, num_bags, additional_info,
          pickup_address, dropoff_address,
          scheduled_date, pickup_time, total_amount, created_at,
          driver:users!driver_id(id, full_name, phone, avatar_url),
          vehicle:vehicles!vehicle_id(id, name, plate_number, category, capacity, image_url)
        ''')
        .eq('customer_id', _currentUserId!)
        .gte('scheduled_date', today)
        .inFilter('status', ['pending', 'confirmed', 'in_progress'])
        .order('scheduled_date')
        .order('pickup_time');

    return (response as List)
        .map((json) => BookingListItem.fromJson(json))
        .toList();
  }

  /// Get past bookings for customer
  Future<List<BookingListItem>> getPastBookings({int limit = 20}) async {
    if (_currentUserId == null) {
      throw Exception('User not authenticated');
    }

    final response = await _table
        .select('''
          id, reference_number, status, category, num_bags, additional_info,
          pickup_address, dropoff_address,
          scheduled_date, pickup_time, total_amount, created_at,
          driver:users!driver_id(id, full_name, phone, avatar_url),
          vehicle:vehicles!vehicle_id(id, name, plate_number, category, capacity, image_url)
        ''')
        .eq('customer_id', _currentUserId!)
        .inFilter('status', ['completed', 'cancelled'])
        .order('scheduled_date', ascending: false)
        .limit(limit);

    return (response as List)
        .map((json) => BookingListItem.fromJson(json))
        .toList();
  }

  /// Cancel a booking
  Future<Booking> cancel(String id, {String? reason}) async {
    final response = await _table
        .update({
          'status': BookingStatus.cancelled.value,
          'cancelled_at': DateTime.now().toIso8601String(),
          'cancellation_reason': reason,
        })
        .eq('id', id)
        .select('''
          *,
          customer:users!customer_id(id, full_name, phone, avatar_url),
          driver:users!driver_id(id, full_name, phone, avatar_url),
          vehicle:vehicles!vehicle_id(id, name, plate_number, category, capacity, image_url)
        ''')
        .single();

    return Booking.fromJson(response);
  }

  /// Get booking addons
  Future<List<BookingAddon>> getBookingAddons(String bookingId) async {
    final response = await _addonsTable
        .select('''
          *,
          addon:pricing_addons!addon_id(*)
        ''')
        .eq('booking_id', bookingId);

    return (response as List)
        .map((json) => BookingAddon.fromJson(json))
        .toList();
  }

  // === Driver-specific methods ===

  /// Get bookings assigned to current driver
  Future<List<BookingListItem>> getDriverBookings({
    BookingStatus? status,
    int limit = 20,
  }) async {
    if (_currentUserId == null) {
      throw Exception('User not authenticated');
    }

    var query = _table
        .select('''
          id, reference_number, status, category, num_bags, additional_info,
          pickup_address, dropoff_address,
          scheduled_date, pickup_time, total_amount, created_at,
          customer:users!customer_id(id, full_name, phone, avatar_url),
          vehicle:vehicles!vehicle_id(id, name, plate_number, category, capacity, image_url)
        ''')
        .eq('driver_id', _currentUserId!);

    if (status != null) {
      query = query.eq('status', status.value);
    }

    final response = await query
        .order('scheduled_date', ascending: false)
        .limit(limit);

    return (response as List)
        .map((json) => BookingListItem.fromJson(json))
        .toList();
  }

  /// Get pending booking requests that driver can accept based on vehicle categories
  ///
  /// Shows bookings where:
  /// - Status is pending (not yet accepted)
  /// - Driver has at least one vehicle that can accept the booking's category
  ///
  /// Category acceptance rules:
  /// - Van can accept: Van, MPV/SUV, Sedan
  /// - MPV/SUV can accept: MPV/SUV, Sedan
  /// - Sedan can accept: Sedan only
  Future<List<BookingListItem>> getPendingRequests() async {
    if (_currentUserId == null) {
      throw Exception('User not authenticated');
    }

    // First, get the driver's vehicles to determine which categories they can accept
    final vehiclesResponse = await _client
        .from('vehicles')
        .select('category')
        .eq('driver_id', _currentUserId!)
        .eq('is_active', true);

    final driverVehicleCategories = (vehiclesResponse as List)
        .map((v) => VehicleCategory.fromString(v['category'] as String))
        .toSet();

    if (driverVehicleCategories.isEmpty) {
      return []; // Driver has no vehicles
    }

    // Determine all categories this driver can accept
    final acceptableCategories = <String>{};
    for (final vehicleCategory in driverVehicleCategories) {
      for (final acceptable in vehicleCategory.acceptableCategories) {
        acceptableCategories.add(acceptable.value);
      }
    }

    // Get all pending bookings (no driver assigned yet) that are today or in the future
    final today = DateTime.now().toIso8601String().split('T')[0];

    final response = await _table
        .select('''
          id, reference_number, status, category, num_bags, additional_info,
          pickup_address, dropoff_address,
          scheduled_date, pickup_time, total_amount, created_at,
          customer:users!customer_id(id, full_name, phone, avatar_url),
          vehicle:vehicles!vehicle_id(id, name, plate_number, category, capacity, image_url)
        ''')
        .eq('status', BookingStatus.pending.value)
        .isFilter('driver_id', null)
        .gte('scheduled_date', today)
        .inFilter('category', acceptableCategories.toList())
        .order('scheduled_date')
        .order('pickup_time');

    return (response as List)
        .map((json) => BookingListItem.fromJson(json))
        .toList();
  }

  /// Get driver's upcoming confirmed/in-progress bookings
  Future<List<BookingListItem>> getDriverUpcomingBookings() async {
    if (_currentUserId == null) {
      throw Exception('User not authenticated');
    }

    final today = DateTime.now().toIso8601String().split('T')[0];

    final response = await _table
        .select('''
          id, reference_number, status, category, num_bags, additional_info,
          pickup_address, dropoff_address,
          scheduled_date, pickup_time, total_amount, created_at,
          customer:users!customer_id(id, full_name, phone, avatar_url),
          vehicle:vehicles!vehicle_id(id, name, plate_number, category, capacity, image_url)
        ''')
        .eq('driver_id', _currentUserId!)
        .gte('scheduled_date', today)
        .inFilter('status', ['confirmed', 'in_progress'])
        .order('scheduled_date')
        .order('pickup_time');

    return (response as List)
        .map((json) => BookingListItem.fromJson(json))
        .toList();
  }

  /// Get driver's completed bookings
  Future<List<BookingListItem>> getDriverCompletedBookings({int limit = 50}) async {
    if (_currentUserId == null) {
      throw Exception('User not authenticated');
    }

    final response = await _table
        .select('''
          id, reference_number, status, category, num_bags, additional_info,
          pickup_address, dropoff_address,
          scheduled_date, pickup_time, total_amount, created_at,
          customer:users!customer_id(id, full_name, phone, avatar_url),
          vehicle:vehicles!vehicle_id(id, name, plate_number, category, capacity, image_url)
        ''')
        .eq('driver_id', _currentUserId!)
        .eq('status', BookingStatus.completed.value)
        .order('completed_at', ascending: false)
        .limit(limit);

    return (response as List)
        .map((json) => BookingListItem.fromJson(json))
        .toList();
  }

  /// Accept a booking (driver)
  Future<Booking> accept(String id, {required String vehicleId}) async {
    if (_currentUserId == null) {
      throw Exception('User not authenticated');
    }

    final response = await _table
        .update({
          'status': BookingStatus.confirmed.value,
          'driver_id': _currentUserId,
          'vehicle_id': vehicleId,
          'confirmed_at': DateTime.now().toIso8601String(),
        })
        .eq('id', id)
        .select('''
          *,
          customer:users!customer_id(id, full_name, phone, avatar_url),
          driver:users!driver_id(id, full_name, phone, avatar_url),
          vehicle:vehicles!vehicle_id(id, name, plate_number, category, capacity, image_url)
        ''')
        .single();

    return Booking.fromJson(response);
  }

  /// Decline a booking (driver)
  Future<void> decline(String id) async {
    // Simply remove driver assignment if any
    await _table
        .update({
          'driver_id': null,
          'vehicle_id': null,
        })
        .eq('id', id);
  }

  /// Start a trip (driver)
  Future<Booking> startTrip(String id) async {
    final response = await _table
        .update({
          'status': BookingStatus.inProgress.value,
          'started_at': DateTime.now().toIso8601String(),
        })
        .eq('id', id)
        .select('''
          *,
          customer:users!customer_id(id, full_name, phone, avatar_url),
          driver:users!driver_id(id, full_name, phone, avatar_url),
          vehicle:vehicles!vehicle_id(id, name, plate_number, category, capacity, image_url)
        ''')
        .single();

    return Booking.fromJson(response);
  }

  /// Complete a trip (driver)
  Future<Booking> completeTrip(String id) async {
    final response = await _table
        .update({
          'status': BookingStatus.completed.value,
          'completed_at': DateTime.now().toIso8601String(),
        })
        .eq('id', id)
        .select('''
          *,
          customer:users!customer_id(id, full_name, phone, avatar_url),
          driver:users!driver_id(id, full_name, phone, avatar_url),
          vehicle:vehicles!vehicle_id(id, name, plate_number, category, capacity, image_url)
        ''')
        .single();

    return Booking.fromJson(response);
  }
}
