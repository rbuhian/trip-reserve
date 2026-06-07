import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/theme/app_colors.dart';
import '../models/booking.dart';
import '../models/enums.dart';
import 'status_pill.dart';

/// Card displaying a booking for driver views with action buttons
class DriverBookingCard extends StatelessWidget {
  final BookingListItem booking;
  final VoidCallback? onTap;
  final VoidCallback? onAccept;
  final VoidCallback? onStart;
  final VoidCallback? onComplete;
  final bool isLoading;

  const DriverBookingCard({
    super.key,
    required this.booking,
    this.onTap,
    this.onAccept,
    this.onStart,
    this.onComplete,
    this.isLoading = false,
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
                StatusPill(
                  status: booking.status,
                  fontSize: 11,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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

            // Category and Trip Info
            _buildCategoryInfo(colorScheme),

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

            // Customer info + Amount
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Customer info
                Expanded(
                  child: _buildCustomerInfo(colorScheme),
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

            // Additional info if present
            if (booking.additionalInfo != null && booking.additionalInfo!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 16,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        booking.additionalInfo!,
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurfaceVariant,
                          fontStyle: FontStyle.italic,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Action buttons based on status
            if (_shouldShowActions) ...[
              const SizedBox(height: 16),
              _buildActionButtons(context, colorScheme),
            ],
          ],
        ),
      ),
    );
  }

  bool get _shouldShowActions =>
      (booking.status == BookingStatus.pending && onAccept != null) ||
      (booking.status == BookingStatus.confirmed && onStart != null) ||
      (booking.status == BookingStatus.inProgress && onComplete != null);

  Widget _buildCategoryInfo(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _getCategoryColor(booking.category).withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: _getCategoryColor(booking.category).withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          // Category icon and name
          Icon(
            _getCategoryIcon(booking.category),
            size: 20,
            color: _getCategoryColor(booking.category),
          ),
          const SizedBox(width: 8),
          Text(
            booking.category.displayName,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: _getCategoryColor(booking.category),
            ),
          ),
          const Spacer(),
          // Number of bags
          Icon(
            Icons.luggage,
            size: 16,
            color: colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 4),
          Text(
            '${booking.numBags} bag${booking.numBags != 1 ? 's' : ''}',
            style: TextStyle(
              fontSize: 12,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getCategoryIcon(VehicleCategory category) {
    switch (category) {
      case VehicleCategory.sedan:
        return Icons.directions_car;
      case VehicleCategory.mpvSuv:
        return Icons.airport_shuttle;
      case VehicleCategory.van:
        return Icons.directions_bus;
    }
  }

  Color _getCategoryColor(VehicleCategory category) {
    switch (category) {
      case VehicleCategory.sedan:
        return AppColors.primary;
      case VehicleCategory.mpvSuv:
        return AppColors.primaryLight;
      case VehicleCategory.van:
        return AppColors.success;
    }
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

  Widget _buildCustomerInfo(ColorScheme colorScheme) {
    if (booking.customer == null) {
      return Text(
        'Customer info unavailable',
        style: TextStyle(
          fontSize: 13,
          color: colorScheme.onSurfaceVariant,
          fontStyle: FontStyle.italic,
        ),
      );
    }

    return Row(
      children: [
        // Customer avatar
        CircleAvatar(
          radius: 16,
          backgroundColor: colorScheme.primary.withOpacity(0.1),
          backgroundImage: booking.customer!.avatarUrl != null
              ? NetworkImage(booking.customer!.avatarUrl!)
              : null,
          child: booking.customer!.avatarUrl == null
              ? Text(
                  _getInitials(booking.customer!.fullName),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.primary,
                  ),
                )
              : null,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                booking.customer!.fullName,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: colorScheme.onSurface,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (booking.customer!.phone != null)
                Text(
                  booking.customer!.phone!,
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context, ColorScheme colorScheme) {
    if (isLoading) {
      return const Center(
        child: SizedBox(
          height: 36,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    switch (booking.status) {
      case BookingStatus.pending:
        if (onAccept != null) {
          return SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onAccept,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.success,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: const Text('Accept'),
            ),
          );
        }
        return const SizedBox.shrink();

      case BookingStatus.confirmed:
        if (onStart != null) {
          return SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onStart,
              icon: const Icon(Icons.play_arrow),
              label: const Text('Start Trip'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          );
        }
        return const SizedBox.shrink();

      case BookingStatus.inProgress:
        if (onComplete != null) {
          return SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onComplete,
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('Complete Trip'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.success,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          );
        }
        return const SizedBox.shrink();

      default:
        return const SizedBox.shrink();
    }
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

  String _getInitials(String name) {
    final parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return parts[0].substring(0, parts[0].length.clamp(0, 2)).toUpperCase();
  }
}
