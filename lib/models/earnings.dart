import 'package:freezed_annotation/freezed_annotation.dart';

part 'earnings.freezed.dart';
part 'earnings.g.dart';

/// Earnings status enum
enum EarningsStatus {
  pending,
  paid;

  String get displayName {
    switch (this) {
      case EarningsStatus.pending:
        return 'Pending';
      case EarningsStatus.paid:
        return 'Paid';
    }
  }
}

/// Single earnings record from a completed trip
@freezed
abstract class DriverEarning with _$DriverEarning {
  const factory DriverEarning({
    required String id,
    @JsonKey(name: 'driver_id') required String driverId,
    @JsonKey(name: 'booking_id') required String bookingId,
    @JsonKey(name: 'gross_amount') required double grossAmount,
    @JsonKey(name: 'platform_fee') required double platformFee,
    @JsonKey(name: 'net_amount') required double netAmount,
    @Default(EarningsStatus.pending) EarningsStatus status,
    @JsonKey(name: 'paid_at') DateTime? paidAt,
    @JsonKey(name: 'created_at') DateTime? createdAt,
  }) = _DriverEarning;

  factory DriverEarning.fromJson(Map<String, dynamic> json) =>
      _$DriverEarningFromJson(json);
}

/// Summary of driver earnings for a period
@freezed
abstract class EarningsSummary with _$EarningsSummary {
  const factory EarningsSummary({
    /// Total gross earnings
    required double totalGross,

    /// Total platform fees
    required double totalFees,

    /// Total net earnings (after fees)
    required double totalNet,

    /// Pending earnings (not yet paid out)
    required double pendingAmount,

    /// Paid earnings
    required double paidAmount,

    /// Number of completed trips
    required int tripCount,

    /// Period start date
    required DateTime periodStart,

    /// Period end date
    required DateTime periodEnd,
  }) = _EarningsSummary;

  const EarningsSummary._();

  factory EarningsSummary.fromJson(Map<String, dynamic> json) =>
      _$EarningsSummaryFromJson(json);

  /// Empty summary for when there are no earnings
  factory EarningsSummary.empty({
    required DateTime periodStart,
    required DateTime periodEnd,
  }) {
    return EarningsSummary(
      totalGross: 0,
      totalFees: 0,
      totalNet: 0,
      pendingAmount: 0,
      paidAmount: 0,
      tripCount: 0,
      periodStart: periodStart,
      periodEnd: periodEnd,
    );
  }

  /// Format net amount as currency
  String get netAmountText => '₱${totalNet.toStringAsFixed(0)}';

  /// Format pending amount as currency
  String get pendingAmountText => '₱${pendingAmount.toStringAsFixed(0)}';
}
