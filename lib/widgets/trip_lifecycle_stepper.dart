import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/theme/app_colors.dart';
import '../models/booking.dart';
import '../models/enums.dart';

/// Visual stepper showing trip lifecycle progress
/// States: Booked → Confirmed → In Progress → Completed
/// Or: Booked → Confirmed? → Cancelled
class TripLifecycleStepper extends StatelessWidget {
  final Booking booking;
  final bool showTimestamps;
  final bool compact;

  const TripLifecycleStepper({
    super.key,
    required this.booking,
    this.showTimestamps = true,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (booking.status == BookingStatus.cancelled) {
      return _buildCancelledStepper(context);
    }

    final steps = _buildSteps();

    if (compact) {
      return _buildCompactStepper(context, steps);
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.timeline, size: 18, color: colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                'Trip Progress',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...steps.asMap().entries.map((entry) {
            final index = entry.key;
            final step = entry.value;
            final isLast = index == steps.length - 1;

            return _buildStepItem(
              context,
              step: step,
              isLast: isLast,
            );
          }),
        ],
      ),
    );
  }

  Widget _buildCancelledStepper(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final steps = <_StepData>[
      _StepData(
        title: 'Booked',
        subtitle: _formatTimestamp(booking.createdAt),
        status: _StepStatus.completed,
        icon: Icons.bookmark_added,
      ),
      if (booking.confirmedAt != null)
        _StepData(
          title: 'Confirmed',
          subtitle: _formatTimestamp(booking.confirmedAt),
          status: _StepStatus.completed,
          icon: Icons.check_circle,
        ),
      _StepData(
        title: 'Cancelled',
        subtitle: _formatTimestamp(booking.cancelledAt),
        status: _StepStatus.cancelled,
        icon: Icons.cancel,
        description: booking.cancellationReason,
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.timeline, size: 18, color: colorScheme.error),
              const SizedBox(width: 8),
              Text(
                'Trip Cancelled',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.error,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...steps.asMap().entries.map((entry) {
            final index = entry.key;
            final step = entry.value;
            final isLast = index == steps.length - 1;

            return _buildStepItem(
              context,
              step: step,
              isLast: isLast,
            );
          }),
        ],
      ),
    );
  }

  List<_StepData> _buildSteps() {
    final currentStatus = booking.status;

    return [
      _StepData(
        title: 'Booked',
        subtitle: _formatTimestamp(booking.createdAt),
        status: _StepStatus.completed,
        icon: Icons.bookmark_added,
      ),
      _StepData(
        title: 'Confirmed',
        subtitle: booking.confirmedAt != null
            ? _formatTimestamp(booking.confirmedAt)
            : 'Awaiting driver',
        status: _getStepStatus(BookingStatus.confirmed, currentStatus),
        icon: Icons.check_circle,
      ),
      _StepData(
        title: 'In Progress',
        subtitle: booking.startedAt != null
            ? _formatTimestamp(booking.startedAt)
            : 'Trip not started',
        status: _getStepStatus(BookingStatus.inProgress, currentStatus),
        icon: Icons.directions_car,
      ),
      _StepData(
        title: 'Completed',
        subtitle: booking.completedAt != null
            ? _formatTimestamp(booking.completedAt)
            : 'Trip not completed',
        status: _getStepStatus(BookingStatus.completed, currentStatus),
        icon: Icons.flag,
      ),
    ];
  }

  _StepStatus _getStepStatus(BookingStatus stepStatus, BookingStatus currentStatus) {
    final order = [
      BookingStatus.pending,
      BookingStatus.confirmed,
      BookingStatus.inProgress,
      BookingStatus.completed,
    ];

    final stepIndex = order.indexOf(stepStatus);
    final currentIndex = order.indexOf(currentStatus);

    if (currentIndex > stepIndex) {
      return _StepStatus.completed;
    } else if (currentIndex == stepIndex) {
      return _StepStatus.current;
    } else {
      return _StepStatus.upcoming;
    }
  }

  Widget _buildStepItem(
    BuildContext context, {
    required _StepData step,
    required bool isLast,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    Color iconColor;
    Color bgColor;
    Color lineColor;

    switch (step.status) {
      case _StepStatus.completed:
        iconColor = Colors.white;
        bgColor = AppColors.success;
        lineColor = AppColors.success;
        break;
      case _StepStatus.current:
        iconColor = Colors.white;
        bgColor = colorScheme.primary;
        lineColor = colorScheme.outlineVariant;
        break;
      case _StepStatus.upcoming:
        iconColor = colorScheme.onSurfaceVariant;
        bgColor = colorScheme.surfaceContainerHighest;
        lineColor = colorScheme.outlineVariant;
        break;
      case _StepStatus.cancelled:
        iconColor = Colors.white;
        bgColor = colorScheme.error;
        lineColor = colorScheme.error;
        break;
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Icon and line
        Column(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: bgColor,
                shape: BoxShape.circle,
                boxShadow: step.status == _StepStatus.current
                    ? [
                        BoxShadow(
                          color: colorScheme.primary.withOpacity(0.3),
                          blurRadius: 8,
                          spreadRadius: 2,
                        ),
                      ]
                    : null,
              ),
              child: Icon(step.icon, size: 18, color: iconColor),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 40,
                color: lineColor,
              ),
          ],
        ),
        const SizedBox(width: 16),
        // Content
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: isLast ? 0 : 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  step.title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: step.status == _StepStatus.current
                        ? FontWeight.w700
                        : FontWeight.w600,
                    color: step.status == _StepStatus.upcoming
                        ? colorScheme.onSurfaceVariant
                        : colorScheme.onSurface,
                  ),
                ),
                if (showTimestamps && step.subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    step.subtitle!,
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                if (step.description != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    step.description!,
                    style: TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCompactStepper(BuildContext context, List<_StepData> steps) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      children: steps.asMap().entries.map((entry) {
        final index = entry.key;
        final step = entry.value;
        final isLast = index == steps.length - 1;

        Color dotColor;
        switch (step.status) {
          case _StepStatus.completed:
            dotColor = AppColors.success;
            break;
          case _StepStatus.current:
            dotColor = colorScheme.primary;
            break;
          case _StepStatus.upcoming:
            dotColor = colorScheme.outlineVariant;
            break;
          case _StepStatus.cancelled:
            dotColor = colorScheme.error;
            break;
        }

        return Expanded(
          child: Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: dotColor,
                  shape: BoxShape.circle,
                ),
                child: step.status == _StepStatus.completed
                    ? const Icon(Icons.check, size: 8, color: Colors.white)
                    : null,
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    height: 2,
                    color: step.status == _StepStatus.completed
                        ? AppColors.success
                        : colorScheme.outlineVariant,
                  ),
                ),
            ],
          ),
        );
      }).toList(),
    );
  }

  String? _formatTimestamp(DateTime? timestamp) {
    if (timestamp == null) return null;
    return DateFormat('MMM d, yyyy • h:mm a').format(timestamp);
  }
}

enum _StepStatus { completed, current, upcoming, cancelled }

class _StepData {
  final String title;
  final String? subtitle;
  final _StepStatus status;
  final IconData icon;
  final String? description;

  _StepData({
    required this.title,
    this.subtitle,
    required this.status,
    required this.icon,
    this.description,
  });
}

/// Horizontal progress indicator for booking cards
class TripProgressIndicator extends StatelessWidget {
  final BookingStatus status;

  const TripProgressIndicator({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (status == BookingStatus.cancelled) {
      return Row(
        children: [
          Icon(Icons.cancel, size: 14, color: colorScheme.error),
          const SizedBox(width: 4),
          Text(
            'Cancelled',
            style: TextStyle(
              fontSize: 11,
              color: colorScheme.error,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      );
    }

    final steps = ['Booked', 'Confirmed', 'In Progress', 'Completed'];
    final statusIndex = _getStatusIndex(status);

    return Row(
      children: steps.asMap().entries.map((entry) {
        final index = entry.key;
        final isCompleted = index < statusIndex;
        final isCurrent = index == statusIndex;
        final isLast = index == steps.length - 1;

        return Expanded(
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: isCompleted
                      ? AppColors.success
                      : isCurrent
                          ? colorScheme.primary
                          : colorScheme.outlineVariant,
                  shape: BoxShape.circle,
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    height: 2,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    color: isCompleted
                        ? AppColors.success
                        : colorScheme.outlineVariant,
                  ),
                ),
            ],
          ),
        );
      }).toList(),
    );
  }

  int _getStatusIndex(BookingStatus status) {
    switch (status) {
      case BookingStatus.pending:
        return 0;
      case BookingStatus.confirmed:
        return 1;
      case BookingStatus.inProgress:
        return 2;
      case BookingStatus.completed:
        return 3;
      case BookingStatus.cancelled:
        return -1;
    }
  }
}
