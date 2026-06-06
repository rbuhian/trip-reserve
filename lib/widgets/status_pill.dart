import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../models/enums.dart';

/// A pill-shaped widget to display booking status
class StatusPill extends StatelessWidget {
  final BookingStatus status;
  final double? fontSize;
  final EdgeInsetsGeometry? padding;

  const StatusPill({
    super.key,
    required this.status,
    this.fontSize,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ?? const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: status.backgroundColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.displayName,
        style: TextStyle(
          color: status.textColor,
          fontSize: fontSize ?? 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// A pill-shaped widget to display payment status
class PaymentStatusPill extends StatelessWidget {
  final PaymentStatus status;
  final double? fontSize;
  final EdgeInsetsGeometry? padding;

  const PaymentStatusPill({
    super.key,
    required this.status,
    this.fontSize,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ?? const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _backgroundColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        _displayName,
        style: TextStyle(
          color: _textColor,
          fontSize: fontSize ?? 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  String get _displayName {
    switch (status) {
      case PaymentStatus.pending:
        return 'Awaiting Payment';
      case PaymentStatus.processing:
        return 'Processing';
      case PaymentStatus.paid:
        return 'Paid';
      case PaymentStatus.failed:
        return 'Failed';
      case PaymentStatus.refunded:
        return 'Refunded';
    }
  }

  Color get _backgroundColor {
    switch (status) {
      case PaymentStatus.pending:
        return AppColors.statusPendingBg;
      case PaymentStatus.processing:
        return AppColors.statusInProgressBg;
      case PaymentStatus.paid:
        return AppColors.statusConfirmedBg;
      case PaymentStatus.failed:
        return AppColors.statusCancelledBg;
      case PaymentStatus.refunded:
        return AppColors.statusCompletedBg;
    }
  }

  Color get _textColor {
    switch (status) {
      case PaymentStatus.pending:
        return AppColors.statusPendingText;
      case PaymentStatus.processing:
        return AppColors.statusInProgressText;
      case PaymentStatus.paid:
        return AppColors.statusConfirmedText;
      case PaymentStatus.failed:
        return AppColors.statusCancelledText;
      case PaymentStatus.refunded:
        return AppColors.statusCompletedText;
    }
  }
}
