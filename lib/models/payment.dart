import 'package:freezed_annotation/freezed_annotation.dart';

import 'enums.dart';

part 'payment.freezed.dart';
part 'payment.g.dart';

/// Payment model
@freezed
abstract class Payment with _$Payment {
  const factory Payment({
    required String id,
    @JsonKey(name: 'booking_id') required String bookingId,

    // Payment details
    required double amount,
    required PaymentMethod method,
    @Default(PaymentStatus.pending) PaymentStatus status,

    // External references
    @JsonKey(name: 'external_id') String? externalId,
    @JsonKey(name: 'external_source_id') String? externalSourceId,

    // Timestamps
    @JsonKey(name: 'paid_at') DateTime? paidAt,
    @JsonKey(name: 'failed_at') DateTime? failedAt,
    @JsonKey(name: 'failure_reason') String? failureReason,
    @JsonKey(name: 'refunded_at') DateTime? refundedAt,
    @JsonKey(name: 'refund_reason') String? refundReason,
    @JsonKey(name: 'created_at') DateTime? createdAt,
    @JsonKey(name: 'updated_at') DateTime? updatedAt,
  }) = _Payment;

  const Payment._();

  factory Payment.fromJson(Map<String, dynamic> json) => _$PaymentFromJson(json);

  /// Check if payment is successful
  bool get isPaid => status == PaymentStatus.paid;

  /// Check if payment failed
  bool get isFailed => status == PaymentStatus.failed;

  /// Check if payment is pending
  bool get isPending =>
      status == PaymentStatus.pending || status == PaymentStatus.processing;
}

/// Data for creating a payment
@freezed
abstract class PaymentCreate with _$PaymentCreate {
  const factory PaymentCreate({
    @JsonKey(name: 'booking_id') required String bookingId,
    required double amount,
    required PaymentMethod method,
  }) = _PaymentCreate;

  factory PaymentCreate.fromJson(Map<String, dynamic> json) =>
      _$PaymentCreateFromJson(json);
}

/// Price breakdown for display
@freezed
abstract class PriceBreakdown with _$PriceBreakdown {
  const factory PriceBreakdown({
    @JsonKey(name: 'base_fare') required double baseFare,
    @JsonKey(name: 'distance_km') required double distanceKm,
    @JsonKey(name: 'distance_fee') required double distanceFee,
    @Default([]) List<AddonLineItem> addons,
    @JsonKey(name: 'addons_fee') @Default(0) double addonsFee,
    required double subtotal,
    @JsonKey(name: 'total_amount') required double totalAmount,
  }) = _PriceBreakdown;

  factory PriceBreakdown.fromJson(Map<String, dynamic> json) =>
      _$PriceBreakdownFromJson(json);
}

/// Line item for add-on in price breakdown
@freezed
abstract class AddonLineItem with _$AddonLineItem {
  const factory AddonLineItem({
    required String name,
    required int quantity,
    @JsonKey(name: 'unit_price') required double unitPrice,
    @JsonKey(name: 'total_price') required double totalPrice,
  }) = _AddonLineItem;

  factory AddonLineItem.fromJson(Map<String, dynamic> json) =>
      _$AddonLineItemFromJson(json);
}

/// Result of creating a PayMongo hosted checkout session.
@freezed
abstract class PaymentCheckout with _$PaymentCheckout {
  const factory PaymentCheckout({
    @JsonKey(name: 'checkout_url') required String checkoutUrl,
    @JsonKey(name: 'payment_id') required String paymentId,
  }) = _PaymentCheckout;

  factory PaymentCheckout.fromJson(Map<String, dynamic> json) =>
      _$PaymentCheckoutFromJson(json);
}
