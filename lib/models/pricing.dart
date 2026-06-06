import 'package:freezed_annotation/freezed_annotation.dart';

import 'enums.dart';

part 'pricing.freezed.dart';
part 'pricing.g.dart';

/// Global pricing configuration
@freezed
class PricingConfig with _$PricingConfig {
  const factory PricingConfig({
    required String id,
    @JsonKey(name: 'base_rate') required double baseRate,
    @JsonKey(name: 'per_km_rate') required double perKmRate,
    @JsonKey(name: 'minimum_fare') required double minimumFare,
    @JsonKey(name: 'cancellation_hours') required int cancellationHours,
    @JsonKey(name: 'cancellation_fee_percent') required double cancellationFeePercent,
    @JsonKey(name: 'is_active') @Default(true) bool isActive,
    @JsonKey(name: 'created_at') DateTime? createdAt,
    @JsonKey(name: 'updated_at') DateTime? updatedAt,
  }) = _PricingConfig;

  const PricingConfig._();

  factory PricingConfig.fromJson(Map<String, dynamic> json) =>
      _$PricingConfigFromJson(json);

  /// Calculate fare for a given distance
  double calculateFare(double distanceKm) {
    final fare = baseRate + (distanceKm * perKmRate);
    return fare < minimumFare ? minimumFare : fare;
  }

  /// Calculate distance fee only
  double calculateDistanceFee(double distanceKm) {
    return distanceKm * perKmRate;
  }

  /// Calculate cancellation fee for a given amount
  double calculateCancellationFee(double amount) {
    return amount * (cancellationFeePercent / 100);
  }
}

/// Optional add-on services
@freezed
class PricingAddon with _$PricingAddon {
  const factory PricingAddon({
    required String id,
    required String name,
    String? description,
    @JsonKey(name: 'addon_type') required AddonType addonType,
    required double price,
    String? icon,
    @JsonKey(name: 'display_order') @Default(0) int displayOrder,
    @JsonKey(name: 'is_active') @Default(true) bool isActive,
    @JsonKey(name: 'created_at') DateTime? createdAt,
    @JsonKey(name: 'updated_at') DateTime? updatedAt,
  }) = _PricingAddon;

  const PricingAddon._();

  factory PricingAddon.fromJson(Map<String, dynamic> json) =>
      _$PricingAddonFromJson(json);

  /// Calculate price for given quantity/hours
  double calculatePrice(int quantity) {
    return price * quantity;
  }

  /// Get price label based on type
  String get priceLabel {
    switch (addonType) {
      case AddonType.flat:
        return '₱${price.toStringAsFixed(0)}';
      case AddonType.perHour:
        return '₱${price.toStringAsFixed(0)}/hr';
      case AddonType.perUnit:
        return '₱${price.toStringAsFixed(0)}/unit';
    }
  }
}

/// Selected add-on for a booking
@freezed
class BookingAddon with _$BookingAddon {
  const factory BookingAddon({
    required String id,
    @JsonKey(name: 'booking_id') required String bookingId,
    @JsonKey(name: 'addon_id') required String addonId,
    @Default(1) int quantity,
    @JsonKey(name: 'unit_price') required double unitPrice,
    @JsonKey(name: 'total_price') required double totalPrice,
    @JsonKey(name: 'created_at') DateTime? createdAt,

    // Joined data
    PricingAddon? addon,
  }) = _BookingAddon;

  factory BookingAddon.fromJson(Map<String, dynamic> json) =>
      _$BookingAddonFromJson(json);
}

/// Data for adding an addon to a booking
@freezed
class BookingAddonCreate with _$BookingAddonCreate {
  const factory BookingAddonCreate({
    @JsonKey(name: 'addon_id') required String addonId,
    @Default(1) int quantity,
    @JsonKey(name: 'unit_price') required double unitPrice,
    @JsonKey(name: 'total_price') required double totalPrice,
  }) = _BookingAddonCreate;

  factory BookingAddonCreate.fromJson(Map<String, dynamic> json) =>
      _$BookingAddonCreateFromJson(json);
}
