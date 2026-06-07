import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../providers/booking_form_provider.dart';

/// Screen for selecting booking date and time
class BookingDateTimeScreen extends ConsumerStatefulWidget {
  const BookingDateTimeScreen({super.key});

  @override
  ConsumerState<BookingDateTimeScreen> createState() =>
      _BookingDateTimeScreenState();
}

class _BookingDateTimeScreenState extends ConsumerState<BookingDateTimeScreen> {
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;

  @override
  void initState() {
    super.initState();
    // Initialize booking form with location data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(bookingFormProvider.notifier).initializeFromLocation();

      // Restore previous selections if any
      final formState = ref.read(bookingFormProvider);
      if (formState.scheduledDate != null) {
        setState(() {
          _selectedDate = formState.scheduledDate;
        });
      }
      if (formState.pickupTime != null) {
        final parts = formState.pickupTime!.split(':');
        setState(() {
          _selectedTime = TimeOfDay(
            hour: int.parse(parts[0]),
            minute: int.parse(parts[1]),
          );
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final formState = ref.watch(bookingFormProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Date & Time'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: Column(
        children: [
          // Trip summary
          _buildTripSummary(formState),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Date section
                  Text(
                    'Select Date',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildDateSelector(),

                  const SizedBox(height: 24),

                  // Time section
                  Text(
                    'Select Pickup Time',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildTimeSelector(),

                  const SizedBox(height: 24),

                  // Quick time options
                  _buildQuickTimeOptions(),
                ],
              ),
            ),
          ),

          // Continue button
          _buildBottomButton(),
        ],
      ),
    );
  }

  Widget _buildTripSummary(BookingFormState formState) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.circle, size: 10, color: AppColors.success),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        formState.pickup?.address ?? '-',
                        style: const TextStyle(fontSize: 13),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Container(
                    width: 2,
                    height: 16,
                    color: AppColors.border,
                  ),
                ),
                Row(
                  children: [
                    Icon(Icons.location_on, size: 10, color: AppColors.accent),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        formState.dropoff?.address ?? '-',
                        style: const TextStyle(fontSize: 13),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                formState.distanceText,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              Text(
                formState.durationText,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textMedium,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDateSelector() {
    final now = DateTime.now();
    final maxDate = now.add(const Duration(days: 30)); // Max 30 days ahead

    return GestureDetector(
      onTap: () async {
        final date = await showDatePicker(
          context: context,
          initialDate: _selectedDate ?? now,
          firstDate: now,
          lastDate: maxDate,
          builder: (context, child) {
            return Theme(
              data: Theme.of(context).copyWith(
                colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: AppColors.primary,
                  onPrimary: AppColors.white,
                ),
              ),
              child: child!,
            );
          },
        );
        if (date != null) {
          setState(() => _selectedDate = date);
          ref.read(bookingFormProvider.notifier).setDate(date);
        }
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _selectedDate != null ? AppColors.primary : AppColors.border,
            width: _selectedDate != null ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.calendar_today,
              color: _selectedDate != null
                  ? AppColors.primary
                  : AppColors.textMedium,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _selectedDate != null
                    ? DateFormat('EEEE, MMMM d, yyyy').format(_selectedDate!)
                    : 'Tap to select date',
                style: TextStyle(
                  fontSize: 16,
                  color: _selectedDate != null
                      ? AppColors.textDark
                      : AppColors.textMedium,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: AppColors.textMedium,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeSelector() {
    return GestureDetector(
      onTap: () async {
        final time = await showTimePicker(
          context: context,
          initialTime: _selectedTime ?? const TimeOfDay(hour: 9, minute: 0),
          builder: (context, child) {
            return Theme(
              data: Theme.of(context).copyWith(
                colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: AppColors.primary,
                  onPrimary: AppColors.white,
                ),
              ),
              child: child!,
            );
          },
        );
        if (time != null) {
          setState(() => _selectedTime = time);
          final timeString =
              '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
          ref.read(bookingFormProvider.notifier).setTime(timeString);
        }
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _selectedTime != null ? AppColors.primary : AppColors.border,
            width: _selectedTime != null ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.access_time,
              color: _selectedTime != null
                  ? AppColors.primary
                  : AppColors.textMedium,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _selectedTime != null
                    ? _formatTime(_selectedTime!)
                    : 'Tap to select time',
                style: TextStyle(
                  fontSize: 16,
                  color: _selectedTime != null
                      ? AppColors.textDark
                      : AppColors.textMedium,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: AppColors.textMedium,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickTimeOptions() {
    final quickTimes = [
      const TimeOfDay(hour: 6, minute: 0),
      const TimeOfDay(hour: 8, minute: 0),
      const TimeOfDay(hour: 10, minute: 0),
      const TimeOfDay(hour: 12, minute: 0),
      const TimeOfDay(hour: 14, minute: 0),
      const TimeOfDay(hour: 16, minute: 0),
      const TimeOfDay(hour: 18, minute: 0),
      const TimeOfDay(hour: 20, minute: 0),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Select',
          style: TextStyle(
            fontSize: 14,
            color: AppColors.textMedium,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: quickTimes.map((time) {
            final isSelected = _selectedTime?.hour == time.hour &&
                _selectedTime?.minute == time.minute;
            return GestureDetector(
              onTap: () {
                setState(() => _selectedTime = time);
                final timeString =
                    '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
                ref.read(bookingFormProvider.notifier).setTime(timeString);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primary.withOpacity(0.1)
                      : AppColors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected ? AppColors.primary : AppColors.border,
                  ),
                ),
                child: Text(
                  _formatTime(time),
                  style: TextStyle(
                    color: isSelected ? AppColors.primary : AppColors.textDark,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  Widget _buildBottomButton() {
    final isComplete = _selectedDate != null && _selectedTime != null;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: isComplete
                ? () {
                    context.push('/book/vehicle');
                  }
                : null,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              disabledBackgroundColor: AppColors.disabled,
            ),
            child: const Text(
              'Continue',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ),
    );
  }
}
