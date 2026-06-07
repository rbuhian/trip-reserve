import 'package:flutter/material.dart';

/// Midnight & Amber color palette for Trip Reserve
class AppColors {
  AppColors._();

  // ============================================
  // PRIMARY COLORS (Midnight Navy)
  // ============================================

  /// Deep navy - main brand color
  static const Color primary = Color(0xFF0C2340);

  /// Darker navy - AppBar, headers
  static const Color primaryDark = Color(0xFF1A3A5C);

  /// Light navy variant
  static const Color primaryLight = Color(0xFF2D5A87);

  // ============================================
  // ACCENT COLORS (Amber)
  // ============================================

  /// Amber - CTAs, active states, highlights
  static const Color accent = Color(0xFFF5A623);

  /// Light amber - hover, secondary actions
  static const Color accentLight = Color(0xFFFFC85A);

  /// Dark amber - pressed states
  static const Color accentDark = Color(0xFFD4891A);

  // ============================================
  // SURFACE & BACKGROUND
  // ============================================

  /// Light blue-gray - card backgrounds
  static const Color surface = Color(0xFFE8F0F8);

  /// Near-white - scaffold background
  static const Color background = Color(0xFFF8FBFF);

  /// White - pure white for contrast
  static const Color white = Color(0xFFFFFFFF);

  /// Dark text color
  static const Color textDark = Color(0xFF1A1A1A);

  /// Medium text color
  static const Color textMedium = Color(0xFF666666);

  /// Light text color
  static const Color textLight = Color(0xFF999999);

  // ============================================
  // STATUS COLORS
  // ============================================

  /// Confirmed status
  static const Color statusConfirmedBg = Color(0xFFE8F4EC);
  static const Color statusConfirmedText = Color(0xFF1A6B35);

  /// Pending / Awaiting Payment status
  static const Color statusPendingBg = Color(0xFFFFF3CD);
  static const Color statusPendingText = Color(0xFF856404);

  /// In Progress status
  static const Color statusInProgressBg = Color(0xFFE8F0F8);
  static const Color statusInProgressText = Color(0xFF0C2340);

  /// Completed status
  static const Color statusCompletedBg = Color(0xFFEFEFEF);
  static const Color statusCompletedText = Color(0xFF444444);

  /// Cancelled status
  static const Color statusCancelledBg = Color(0xFFFAECEA);
  static const Color statusCancelledText = Color(0xFF993C1D);

  // ============================================
  // SEMANTIC COLORS
  // ============================================

  /// Success green
  static const Color success = Color(0xFF1A6B35);
  static const Color successLight = Color(0xFFE8F4EC);

  /// Warning amber (uses accent)
  static const Color warning = Color(0xFFF5A623);
  static const Color warningLight = Color(0xFFFFF3CD);

  /// Error red
  static const Color error = Color(0xFF993C1D);
  static const Color errorLight = Color(0xFFFAECEA);

  /// Info blue
  static const Color info = Color(0xFF0C2340);
  static const Color infoLight = Color(0xFFE8F0F8);

  // ============================================
  // UI ELEMENT COLORS
  // ============================================

  /// Divider color
  static const Color divider = Color(0xFFE0E0E0);

  /// Border color
  static const Color border = Color(0xFFD0D0D0);

  /// Disabled state
  static const Color disabled = Color(0xFFBDBDBD);

  /// Shadow color
  static const Color shadow = Color(0x1A000000);

  // ============================================
  // MAP MARKER COLORS
  // ============================================

  /// Pickup marker (green)
  static const Color markerPickup = Color(0xFF1A6B35);

  /// Dropoff marker (amber accent)
  static const Color markerDropoff = Color(0xFFF5A623);

  /// Current location marker
  static const Color markerCurrent = Color(0xFF0C2340);
}
