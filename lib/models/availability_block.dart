import 'package:freezed_annotation/freezed_annotation.dart';

import 'enums.dart';

part 'availability_block.freezed.dart';
part 'availability_block.g.dart';

/// Availability block when driver is unavailable
@freezed
class AvailabilityBlock with _$AvailabilityBlock {
  const factory AvailabilityBlock({
    required String id,
    @JsonKey(name: 'driver_id') required String driverId,
    @JsonKey(name: 'vehicle_id') String? vehicleId,

    // Block period
    @JsonKey(name: 'block_date') required DateTime blockDate,
    @JsonKey(name: 'start_time') String? startTime,
    @JsonKey(name: 'end_time') String? endTime,
    @JsonKey(name: 'is_full_day') @Default(true) bool isFullDay,

    // Reason
    @Default(BlockReason.personal) BlockReason reason,
    String? notes,

    // If blocked due to booking
    @JsonKey(name: 'booking_id') String? bookingId,

    @JsonKey(name: 'created_at') DateTime? createdAt,
    @JsonKey(name: 'updated_at') DateTime? updatedAt,
  }) = _AvailabilityBlock;

  const AvailabilityBlock._();

  factory AvailabilityBlock.fromJson(Map<String, dynamic> json) =>
      _$AvailabilityBlockFromJson(json);

  /// Check if block is due to a booking
  bool get isBookingBlock => bookingId != null;

  /// Check if block can be edited (not booking-related)
  bool get canEdit => !isBookingBlock;

  /// Get display text for the block
  String get displayText {
    if (isFullDay) {
      return 'Full day';
    }
    return '$startTime - $endTime';
  }

  /// Get reason display text
  String get reasonText {
    switch (reason) {
      case BlockReason.vacation:
        return 'Vacation';
      case BlockReason.maintenance:
        return 'Vehicle Maintenance';
      case BlockReason.personal:
        return 'Personal';
      case BlockReason.booked:
        return 'Booked';
      case BlockReason.other:
        return notes ?? 'Other';
    }
  }
}

/// Data for creating an availability block
@freezed
class AvailabilityBlockCreate with _$AvailabilityBlockCreate {
  const factory AvailabilityBlockCreate({
    @JsonKey(name: 'vehicle_id') String? vehicleId,
    @JsonKey(name: 'block_date') required DateTime blockDate,
    @JsonKey(name: 'start_time') String? startTime,
    @JsonKey(name: 'end_time') String? endTime,
    @JsonKey(name: 'is_full_day') @Default(true) bool isFullDay,
    @Default(BlockReason.personal) BlockReason reason,
    String? notes,
  }) = _AvailabilityBlockCreate;

  factory AvailabilityBlockCreate.fromJson(Map<String, dynamic> json) =>
      _$AvailabilityBlockCreateFromJson(json);
}

/// Day availability status for calendar display
@freezed
class DayAvailability with _$DayAvailability {
  const factory DayAvailability({
    required DateTime date,
    @Default(false) bool hasBooking,
    @Default(false) bool isBlocked,
    @Default(false) bool isPartiallyBlocked,
    @Default([]) List<AvailabilityBlock> blocks,
  }) = _DayAvailability;

  const DayAvailability._();

  factory DayAvailability.fromJson(Map<String, dynamic> json) =>
      _$DayAvailabilityFromJson(json);

  /// Get availability status for display
  DayStatus get status {
    if (isBlocked) return DayStatus.blocked;
    if (hasBooking) return DayStatus.booked;
    if (isPartiallyBlocked) return DayStatus.partial;
    return DayStatus.available;
  }
}

/// Day status for calendar
enum DayStatus {
  available,
  partial,
  booked,
  blocked,
}
