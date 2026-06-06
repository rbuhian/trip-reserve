import 'package:flutter/material.dart';

/// App color palette
class AppColors {
  AppColors._();

  // ============================================
  // PRIMARY COLORS (Blue)
  // ============================================

  /// Primary blue - main brand color
  static const Color primary = Color(0xFF2563EB);

  /// Darker blue
  static const Color primaryDark = Color(0xFF1D4ED8);

  /// Light blue variant
  static const Color primaryLight = Color(0xFF3B82F6);

  // ============================================
  // ACCENT/SECONDARY COLORS (Green)
  // ============================================

  /// Secondary green
  static const Color accent = Color(0xFF10B981);

  /// Light green
  static const Color accentLight = Color(0xFF34D399);

  /// Dark green
  static const Color accentDark = Color(0xFF059669);

  // ============================================
  // SURFACE & BACKGROUND
  // ============================================

  /// Light gray - card backgrounds
  static const Color surface = Color(0xFFF3F4F6);

  /// Near-white - scaffold background
  static const Color background = Color(0xFFFAFAFA);

  /// White
  static const Color white = Color(0xFFFFFFFF);

  /// Dark text color
  static const Color textDark = Color(0xFF1F2937);

  /// Medium text color
  static const Color textMedium = Color(0xFF6B7280);

  /// Light text color
  static const Color textLight = Color(0xFF9CA3AF);

  // ============================================
  // STATUS COLORS
  // ============================================

  /// Confirmed status
  static const Color statusConfirmedBg = Color(0xFFD1FAE5);
  static const Color statusConfirmedText = Color(0xFF065F46);

  /// Pending status
  static const Color statusPendingBg = Color(0xFFFEF3C7);
  static const Color statusPendingText = Color(0xFF92400E);

  /// In Progress status
  static const Color statusInProgressBg = Color(0xFFDBEAFE);
  static const Color statusInProgressText = Color(0xFF1E40AF);

  /// Completed status
  static const Color statusCompletedBg = Color(0xFFE5E7EB);
  static const Color statusCompletedText = Color(0xFF374151);

  /// Cancelled status
  static const Color statusCancelledBg = Color(0xFFFEE2E2);
  static const Color statusCancelledText = Color(0xFF991B1B);

  // ============================================
  // SEMANTIC COLORS
  // ============================================

  /// Success green
  static const Color success = Color(0xFF10B981);
  static const Color successLight = Color(0xFFD1FAE5);

  /// Warning amber
  static const Color warning = Color(0xFFF59E0B);
  static const Color warningLight = Color(0xFFFEF3C7);

  /// Error red
  static const Color error = Color(0xFFEF4444);
  static const Color errorLight = Color(0xFFFEE2E2);

  /// Info blue
  static const Color info = Color(0xFF3B82F6);
  static const Color infoLight = Color(0xFFDBEAFE);

  // ============================================
  // UI ELEMENT COLORS
  // ============================================

  /// Divider color
  static const Color divider = Color(0xFFE5E7EB);

  /// Border color
  static const Color border = Color(0xFFD1D5DB);

  /// Disabled state
  static const Color disabled = Color(0xFF9CA3AF);

  /// Shadow color
  static const Color shadow = Color(0x1A000000);

  // ============================================
  // MAP MARKER COLORS
  // ============================================

  /// Pickup marker (green)
  static const Color markerPickup = Color(0xFF10B981);

  /// Dropoff marker (red)
  static const Color markerDropoff = Color(0xFFEF4444);

  /// Current location marker
  static const Color markerCurrent = Color(0xFF2563EB);
}
