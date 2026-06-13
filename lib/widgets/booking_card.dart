import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/theme/app_colors.dart';
import '../models/booking.dart';
import 'status_pill.dart';

/// Card displaying a booking summary for list views
class BookingCard extends StatelessWidget {
  final BookingListItem booking;
  final VoidCallback? onTap;
  final int unreadCount;

  const BookingCard({
    super.key,
    required this.booking,
    this.onTap,
    this.unreadCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: colorScheme.outlineVariant.withOpacity(0.3),
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.textDark.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Reference number + Status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  booking.referenceNumber,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: colorScheme.primary,
                    letterSpacing: 0.5,
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (unreadCount > 0) ...[
                      UnreadChatBadge(count: unreadCount),
                      const SizedBox(width: 8),
                    ],
                    StatusPill(
                      status: booking.status,
                      fontSize: 11,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Date and Time
            Row(
              children: [
                Icon(
                  Icons.calendar_today_outlined,
                  size: 16,
                  color: colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Text(
                  _formatDate(booking.scheduledDate),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(width: 16),
                Icon(
                  Icons.access_time,
                  size: 16,
                  color: colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Text(
                  booking.pickupTime,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Route
            _buildRouteSection(colorScheme),

            const SizedBox(height: 12),

            // Divider
            Divider(
              color: colorScheme.outlineVariant.withOpacity(0.3),
              height: 1,
            ),

            const SizedBox(height: 12),

            // Bottom: Driver/Vehicle info + Amount
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Driver and vehicle info
                Expanded(
                  child: _buildDriverVehicleInfo(colorScheme),
                ),
                // Amount
                Text(
                  '₱${booking.totalAmount.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRouteSection(ColorScheme colorScheme) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Route icons
        Column(
          children: [
            Icon(
              Icons.trip_origin,
              size: 14,
              color: AppColors.success,
            ),
            Container(
              width: 1,
              height: 20,
              color: colorScheme.outlineVariant,
            ),
            Icon(
              Icons.location_on,
              size: 14,
              color: AppColors.error,
            ),
          ],
        ),
        const SizedBox(width: 10),
        // Addresses
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                booking.pickupAddress,
                style: TextStyle(
                  fontSize: 13,
                  color: colorScheme.onSurface,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              Text(
                booking.dropoffAddress,
                style: TextStyle(
                  fontSize: 13,
                  color: colorScheme.onSurface,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDriverVehicleInfo(ColorScheme colorScheme) {
    if (booking.driver == null && booking.vehicle == null) {
      return Text(
        'Awaiting driver assignment',
        style: TextStyle(
          fontSize: 13,
          color: colorScheme.onSurfaceVariant,
          fontStyle: FontStyle.italic,
        ),
      );
    }

    final parts = <String>[];
    if (booking.driver != null) {
      parts.add(booking.driver!.fullName);
    }
    if (booking.vehicle != null) {
      parts.add('${booking.vehicle!.name} • ${booking.vehicle!.plateNumber}');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (booking.driver != null)
          Row(
            children: [
              Icon(
                Icons.person_outline,
                size: 14,
                color: colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  booking.driver!.fullName,
                  style: TextStyle(
                    fontSize: 13,
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        if (booking.vehicle != null) ...[
          if (booking.driver != null) const SizedBox(height: 4),
          Row(
            children: [
              Icon(
                Icons.directions_car_outlined,
                size: 14,
                color: colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '${booking.vehicle!.name} • ${booking.vehicle!.plateNumber}',
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final bookingDate = DateTime(date.year, date.month, date.day);

    if (bookingDate == today) {
      return 'Today';
    } else if (bookingDate == tomorrow) {
      return 'Tomorrow';
    } else {
      return DateFormat('MMM d, yyyy').format(date);
    }
  }
}

/// Small pill showing the unread message count for a booking's chat.
class UnreadChatBadge extends StatelessWidget {
  final int count;

  const UnreadChatBadge({super.key, required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.accent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.chat_bubble,
            size: 12,
            color: AppColors.white,
          ),
          const SizedBox(width: 4),
          Text(
            count > 99 ? '99+' : '$count',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.white,
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact booking card for dashboard or summary views
class BookingCardCompact extends StatelessWidget {
  final BookingListItem booking;
  final VoidCallback? onTap;

  const BookingCardCompact({
    super.key,
    required this.booking,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            // Date circle
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    DateFormat('d').format(booking.scheduledDate),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: colorScheme.primary,
                    ),
                  ),
                  Text(
                    DateFormat('MMM').format(booking.scheduledDate).toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          booking.referenceNumber,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onSurface,
                          ),
                        ),
                      ),
                      StatusPill(
                        status: booking.status,
                        fontSize: 10,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    booking.dropoffAddress,
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Arrow
            Icon(
              Icons.chevron_right,
              color: colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}
