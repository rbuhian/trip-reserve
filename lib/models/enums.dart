import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../core/theme/app_colors.dart';

/// User roles in the system
@JsonEnum(valueField: 'value')
enum UserRole {
  customer('customer'),
  driver('driver'),
  admin('admin');

  const UserRole(this.value);
  final String value;

  static UserRole fromString(String value) {
    return UserRole.values.firstWhere(
      (e) => e.value == value,
      orElse: () => UserRole.customer,
    );
  }

  /// Human-readable display name
  String get displayName {
    switch (this) {
      case UserRole.customer:
        return 'Customer';
      case UserRole.driver:
        return 'Driver';
      case UserRole.admin:
        return 'Admin';
    }
  }
}

/// Booking lifecycle statuses
@JsonEnum(valueField: 'value')
enum BookingStatus {
  pending('pending'),
  confirmed('confirmed'),
  inProgress('in_progress'),
  completed('completed'),
  cancelled('cancelled');

  const BookingStatus(this.value);
  final String value;

  static BookingStatus fromString(String value) {
    return BookingStatus.values.firstWhere(
      (e) => e.value == value,
      orElse: () => BookingStatus.pending,
    );
  }

  /// Human-readable display name
  String get displayName {
    switch (this) {
      case BookingStatus.pending:
        return 'Pending';
      case BookingStatus.confirmed:
        return 'Confirmed';
      case BookingStatus.inProgress:
        return 'In Progress';
      case BookingStatus.completed:
        return 'Completed';
      case BookingStatus.cancelled:
        return 'Cancelled';
    }
  }

  /// Whether the booking is active (not finished)
  bool get isActive =>
      this == BookingStatus.pending ||
      this == BookingStatus.confirmed ||
      this == BookingStatus.inProgress;

  /// Background color for status pill
  Color get backgroundColor {
    switch (this) {
      case BookingStatus.pending:
        return AppColors.statusPendingBg;
      case BookingStatus.confirmed:
        return AppColors.statusConfirmedBg;
      case BookingStatus.inProgress:
        return AppColors.statusInProgressBg;
      case BookingStatus.completed:
        return AppColors.statusCompletedBg;
      case BookingStatus.cancelled:
        return AppColors.statusCancelledBg;
    }
  }

  /// Text color for status pill
  Color get textColor {
    switch (this) {
      case BookingStatus.pending:
        return AppColors.statusPendingText;
      case BookingStatus.confirmed:
        return AppColors.statusConfirmedText;
      case BookingStatus.inProgress:
        return AppColors.statusInProgressText;
      case BookingStatus.completed:
        return AppColors.statusCompletedText;
      case BookingStatus.cancelled:
        return AppColors.statusCancelledText;
    }
  }
}

/// Payment statuses
@JsonEnum(valueField: 'value')
enum PaymentStatus {
  pending('pending'),
  processing('processing'),
  paid('paid'),
  failed('failed'),
  refunded('refunded');

  const PaymentStatus(this.value);
  final String value;

  static PaymentStatus fromString(String value) {
    return PaymentStatus.values.firstWhere(
      (e) => e.value == value,
      orElse: () => PaymentStatus.pending,
    );
  }
}

/// Payment methods available
@JsonEnum(valueField: 'value')
enum PaymentMethod {
  gcash('gcash'),
  card('card'),
  maya('maya');

  const PaymentMethod(this.value);
  final String value;

  static PaymentMethod fromString(String value) {
    return PaymentMethod.values.firstWhere(
      (e) => e.value == value,
      orElse: () => PaymentMethod.gcash,
    );
  }

  String get displayName {
    switch (this) {
      case PaymentMethod.gcash:
        return 'GCash';
      case PaymentMethod.card:
        return 'Credit/Debit Card';
      case PaymentMethod.maya:
        return 'Maya';
    }
  }
}

/// Reasons for blocking availability
@JsonEnum(valueField: 'value')
enum BlockReason {
  vacation('vacation'),
  maintenance('maintenance'),
  personal('personal'),
  booked('booked'),
  other('other');

  const BlockReason(this.value);
  final String value;

  static BlockReason fromString(String value) {
    return BlockReason.values.firstWhere(
      (e) => e.value == value,
      orElse: () => BlockReason.other,
    );
  }
}

/// Add-on pricing types
@JsonEnum(valueField: 'value')
enum AddonType {
  flat('flat'),
  perHour('per_hour'),
  perUnit('per_unit');

  const AddonType(this.value);
  final String value;

  static AddonType fromString(String value) {
    return AddonType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => AddonType.flat,
    );
  }
}

/// Driver earning statuses
@JsonEnum(valueField: 'value')
enum EarningStatus {
  pending('pending'),
  paid('paid'),
  cancelled('cancelled');

  const EarningStatus(this.value);
  final String value;

  static EarningStatus fromString(String value) {
    return EarningStatus.values.firstWhere(
      (e) => e.value == value,
      orElse: () => EarningStatus.pending,
    );
  }
}

/// Withdrawal request statuses
@JsonEnum(valueField: 'value')
enum WithdrawalStatus {
  pending('pending'),
  approved('approved'),
  rejected('rejected'),
  paid('paid'),
  cancelled('cancelled');

  const WithdrawalStatus(this.value);
  final String value;

  static WithdrawalStatus fromString(String value) {
    return WithdrawalStatus.values.firstWhere(
      (e) => e.value == value,
      orElse: () => WithdrawalStatus.pending,
    );
  }

  String get displayName {
    switch (this) {
      case WithdrawalStatus.pending:
        return 'Pending';
      case WithdrawalStatus.approved:
        return 'Approved';
      case WithdrawalStatus.rejected:
        return 'Rejected';
      case WithdrawalStatus.paid:
        return 'Paid';
      case WithdrawalStatus.cancelled:
        return 'Cancelled';
    }
  }
}

/// Payout methods for withdrawals
@JsonEnum(valueField: 'value')
enum PayoutMethod {
  gcash('gcash'),
  maya('maya'),
  bank('bank');

  const PayoutMethod(this.value);
  final String value;

  static PayoutMethod fromString(String value) {
    return PayoutMethod.values.firstWhere(
      (e) => e.value == value,
      orElse: () => PayoutMethod.gcash,
    );
  }

  String get displayName {
    switch (this) {
      case PayoutMethod.gcash:
        return 'GCash';
      case PayoutMethod.maya:
        return 'Maya';
      case PayoutMethod.bank:
        return 'Bank Transfer';
    }
  }
}

/// Vehicle categories
@JsonEnum(valueField: 'value')
enum VehicleCategory {
  sedan('sedan'),
  mpvSuv('mpv_suv'),
  van('van');

  const VehicleCategory(this.value);
  final String value;

  static VehicleCategory fromString(String value) {
    return VehicleCategory.values.firstWhere(
      (e) => e.value == value,
      orElse: () => VehicleCategory.sedan,
    );
  }

  /// Human-readable display name
  String get displayName {
    switch (this) {
      case VehicleCategory.sedan:
        return 'Sedan';
      case VehicleCategory.mpvSuv:
        return 'MPV/SUV';
      case VehicleCategory.van:
        return 'Van';
    }
  }

  /// Description of the category
  String get description {
    switch (this) {
      case VehicleCategory.sedan:
        return 'Standard car, up to 4 passengers';
      case VehicleCategory.mpvSuv:
        return 'Larger vehicle, up to 7 passengers';
      case VehicleCategory.van:
        return 'Van, up to 15 passengers';
    }
  }

  /// Icon name for the category
  String get iconName {
    switch (this) {
      case VehicleCategory.sedan:
        return 'directions_car';
      case VehicleCategory.mpvSuv:
        return 'airport_shuttle';
      case VehicleCategory.van:
        return 'directions_bus';
    }
  }

  /// Check if this category can accept bookings for another category
  /// Returns true if this vehicle category can accept a booking of the given category
  bool canAcceptCategory(VehicleCategory bookingCategory) {
    switch (this) {
      case VehicleCategory.van:
        // Van can accept all categories
        return true;
      case VehicleCategory.mpvSuv:
        // MPV/SUV can accept mpvSuv and sedan
        return bookingCategory == VehicleCategory.mpvSuv ||
            bookingCategory == VehicleCategory.sedan;
      case VehicleCategory.sedan:
        // Sedan can only accept sedan
        return bookingCategory == VehicleCategory.sedan;
    }
  }

  /// Get all categories this vehicle can accept
  List<VehicleCategory> get acceptableCategories {
    switch (this) {
      case VehicleCategory.van:
        return [VehicleCategory.van, VehicleCategory.mpvSuv, VehicleCategory.sedan];
      case VehicleCategory.mpvSuv:
        return [VehicleCategory.mpvSuv, VehicleCategory.sedan];
      case VehicleCategory.sedan:
        return [VehicleCategory.sedan];
    }
  }
}
