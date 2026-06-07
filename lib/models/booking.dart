import 'package:freezed_annotation/freezed_annotation.dart';

import 'enums.dart';
import 'user.dart';
import 'vehicle.dart';

part 'booking.freezed.dart';
part 'booking.g.dart';

/// Full booking model with all details
@freezed
abstract class Booking with _$Booking {
  const factory Booking({
    required String id,
    @JsonKey(name: 'reference_number') required String referenceNumber,

    // Parties
    @JsonKey(name: 'customer_id') required String customerId,
    @JsonKey(name: 'driver_id') String? driverId,
    @JsonKey(name: 'vehicle_id') String? vehicleId,

    // Status
    @Default(BookingStatus.pending) BookingStatus status,

    // Vehicle category selection
    @Default(VehicleCategory.sedan) VehicleCategory category,
    @JsonKey(name: 'num_bags') @Default(0) int numBags,
    @JsonKey(name: 'additional_info') String? additionalInfo,

    // Locations
    @JsonKey(name: 'pickup_address') required String pickupAddress,
    @JsonKey(name: 'pickup_lat') required double pickupLat,
    @JsonKey(name: 'pickup_lng') required double pickupLng,
    @JsonKey(name: 'dropoff_address') required String dropoffAddress,
    @JsonKey(name: 'dropoff_lat') required double dropoffLat,
    @JsonKey(name: 'dropoff_lng') required double dropoffLng,

    // Trip details
    @JsonKey(name: 'distance_km') required double distanceKm,
    @JsonKey(name: 'duration_minutes') required int durationMinutes,
    @JsonKey(name: 'scheduled_date') required DateTime scheduledDate,
    @JsonKey(name: 'pickup_time') required String pickupTime,

    // Pricing (in PHP)
    @JsonKey(name: 'base_fare') required double baseFare,
    @JsonKey(name: 'distance_fee') required double distanceFee,
    @JsonKey(name: 'addons_fee') @Default(0) double addonsFee,
    @JsonKey(name: 'total_amount') required double totalAmount,

    // Timestamps
    @JsonKey(name: 'confirmed_at') DateTime? confirmedAt,
    @JsonKey(name: 'started_at') DateTime? startedAt,
    @JsonKey(name: 'completed_at') DateTime? completedAt,
    @JsonKey(name: 'cancelled_at') DateTime? cancelledAt,
    @JsonKey(name: 'cancellation_reason') String? cancellationReason,
    @JsonKey(name: 'created_at') DateTime? createdAt,
    @JsonKey(name: 'updated_at') DateTime? updatedAt,

    // Joined data (optional)
    UserRef? customer,
    UserRef? driver,
    VehicleRef? vehicle,
  }) = _Booking;

  const Booking._();

  factory Booking.fromJson(Map<String, dynamic> json) => _$BookingFromJson(json);

  /// Formatted distance: "12.5 km"
  String get distanceText => '${distanceKm.toStringAsFixed(1)} km';

  /// Formatted duration: "45 min" or "1h 30min"
  String get durationText {
    if (durationMinutes < 60) {
      return '$durationMinutes min';
    }
    final hours = durationMinutes ~/ 60;
    final mins = durationMinutes % 60;
    return mins > 0 ? '${hours}h ${mins}min' : '${hours}h';
  }

  /// Check if booking can be cancelled
  bool get canCancel =>
      status == BookingStatus.pending || status == BookingStatus.confirmed;

  /// Check if driver can start the trip
  bool get canStart => status == BookingStatus.confirmed;

  /// Check if driver can complete the trip
  bool get canComplete => status == BookingStatus.inProgress;
}

/// Lightweight booking for list views
@freezed
abstract class BookingListItem with _$BookingListItem {
  const factory BookingListItem({
    required String id,
    @JsonKey(name: 'reference_number') required String referenceNumber,
    required BookingStatus status,

    // Vehicle category info (for driver display)
    @Default(VehicleCategory.sedan) VehicleCategory category,
    @JsonKey(name: 'num_bags') @Default(0) int numBags,
    @JsonKey(name: 'additional_info') String? additionalInfo,

    @JsonKey(name: 'pickup_address') required String pickupAddress,
    @JsonKey(name: 'dropoff_address') required String dropoffAddress,
    @JsonKey(name: 'scheduled_date') required DateTime scheduledDate,
    @JsonKey(name: 'pickup_time') required String pickupTime,
    @JsonKey(name: 'total_amount') required double totalAmount,
    @JsonKey(name: 'created_at') DateTime? createdAt,

    // Joined data
    UserRef? customer,
    UserRef? driver,
    VehicleRef? vehicle,
  }) = _BookingListItem;

  const BookingListItem._();

  factory BookingListItem.fromJson(Map<String, dynamic> json) =>
      _$BookingListItemFromJson(json);

  /// Check if booking can be accepted by driver
  bool get canAccept => status == BookingStatus.pending;

  /// Check if driver can start the trip
  bool get canStart => status == BookingStatus.confirmed;

  /// Check if driver can complete the trip
  bool get canComplete => status == BookingStatus.inProgress;
}

/// Data for creating a new booking
@freezed
abstract class BookingCreate with _$BookingCreate {
  const factory BookingCreate({
    // Vehicle category selection
    @Default(VehicleCategory.sedan) VehicleCategory category,
    @JsonKey(name: 'num_bags') @Default(0) int numBags,
    @JsonKey(name: 'additional_info') String? additionalInfo,

    // Locations
    @JsonKey(name: 'pickup_address') required String pickupAddress,
    @JsonKey(name: 'pickup_lat') required double pickupLat,
    @JsonKey(name: 'pickup_lng') required double pickupLng,
    @JsonKey(name: 'dropoff_address') required String dropoffAddress,
    @JsonKey(name: 'dropoff_lat') required double dropoffLat,
    @JsonKey(name: 'dropoff_lng') required double dropoffLng,

    // Trip details
    @JsonKey(name: 'distance_km') required double distanceKm,
    @JsonKey(name: 'duration_minutes') required int durationMinutes,
    @JsonKey(name: 'scheduled_date') required DateTime scheduledDate,
    @JsonKey(name: 'pickup_time') required String pickupTime,

    // Vehicle selection (optional - driver accepts based on category)
    @JsonKey(name: 'vehicle_id') String? vehicleId,

    // Pricing
    @JsonKey(name: 'base_fare') required double baseFare,
    @JsonKey(name: 'distance_fee') required double distanceFee,
    @JsonKey(name: 'addons_fee') @Default(0) double addonsFee,
    @JsonKey(name: 'total_amount') required double totalAmount,
  }) = _BookingCreate;

  factory BookingCreate.fromJson(Map<String, dynamic> json) =>
      _$BookingCreateFromJson(json);
}

/// Location data with coordinates
@freezed
abstract class LocationData with _$LocationData {
  const factory LocationData({
    required String address,
    required double lat,
    required double lng,
  }) = _LocationData;

  factory LocationData.fromJson(Map<String, dynamic> json) =>
      _$LocationDataFromJson(json);
}
