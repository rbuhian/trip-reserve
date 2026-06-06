import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/availability_block.dart';
import '../repositories/availability_repository.dart';

/// Current selected month for calendar
final selectedMonthProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, 1);
});

/// Current selected date for day view
final selectedDateProvider = StateProvider<DateTime?>((ref) => null);

/// Blocks for the selected month
final monthBlocksProvider = FutureProvider<Map<DateTime, List<AvailabilityBlock>>>((ref) async {
  final selectedMonth = ref.watch(selectedMonthProvider);
  final repository = ref.watch(availabilityRepositoryProvider);

  return repository.getBlocksForMonth(
    selectedMonth.year,
    selectedMonth.month,
  );
});

/// Blocks for the selected date
final dayBlocksProvider = FutureProvider<List<AvailabilityBlock>>((ref) async {
  final selectedDate = ref.watch(selectedDateProvider);
  if (selectedDate == null) return [];

  final repository = ref.watch(availabilityRepositoryProvider);
  return repository.getBlocksForDate(selectedDate);
});

/// Day availability data for calendar
final dayAvailabilityProvider = Provider.family<DayAvailability, DateTime>((ref, date) {
  final monthBlocks = ref.watch(monthBlocksProvider);
  final blocks = monthBlocks.valueOrNull?[DateTime(date.year, date.month, date.day)] ?? [];

  final hasFullDayBlock = blocks.any((b) => b.isFullDay);
  final hasBooking = blocks.any((b) => b.bookingId != null);
  final hasPartialBlock = blocks.any((b) => !b.isFullDay && b.bookingId == null);

  return DayAvailability(
    date: date,
    hasBooking: hasBooking,
    isBlocked: hasFullDayBlock && !hasBooking,
    isPartiallyBlocked: hasPartialBlock && !hasFullDayBlock,
    blocks: blocks,
  );
});

/// Availability actions notifier
final availabilityActionsProvider = AsyncNotifierProvider<AvailabilityActionsNotifier, void>(
  AvailabilityActionsNotifier.new,
);

class AvailabilityActionsNotifier extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  AvailabilityRepository get _repository => ref.read(availabilityRepositoryProvider);

  /// Block a full day
  Future<AvailabilityBlock> blockFullDay({
    required DateTime date,
    required String reason,
    String? vehicleId,
    String? notes,
  }) async {
    state = const AsyncLoading();

    try {
      final block = await _repository.blockFullDay(
        date: date,
        reason: reason,
        vehicleId: vehicleId,
        notes: notes,
      );

      // Refresh the month blocks
      ref.invalidate(monthBlocksProvider);
      ref.invalidate(dayBlocksProvider);

      state = const AsyncData(null);
      return block;
    } catch (e) {
      state = AsyncError(e, StackTrace.current);
      rethrow;
    }
  }

  /// Block a time slot
  Future<AvailabilityBlock> blockTimeSlot({
    required DateTime date,
    required String startTime,
    required String endTime,
    required String reason,
    String? vehicleId,
    String? notes,
  }) async {
    state = const AsyncLoading();

    try {
      final block = await _repository.blockTimeSlot(
        date: date,
        startTime: startTime,
        endTime: endTime,
        reason: reason,
        vehicleId: vehicleId,
        notes: notes,
      );

      // Refresh
      ref.invalidate(monthBlocksProvider);
      ref.invalidate(dayBlocksProvider);

      state = const AsyncData(null);
      return block;
    } catch (e) {
      state = AsyncError(e, StackTrace.current);
      rethrow;
    }
  }

  /// Delete a block
  Future<void> deleteBlock(String id) async {
    state = const AsyncLoading();

    try {
      await _repository.delete(id);

      // Refresh
      ref.invalidate(monthBlocksProvider);
      ref.invalidate(dayBlocksProvider);

      state = const AsyncData(null);
    } catch (e) {
      state = AsyncError(e, StackTrace.current);
      rethrow;
    }
  }

  /// Clear all blocks for a date (except booking-related)
  Future<void> clearBlocksForDate(DateTime date) async {
    state = const AsyncLoading();

    try {
      await _repository.deleteBlocksForDate(date);

      // Refresh
      ref.invalidate(monthBlocksProvider);
      ref.invalidate(dayBlocksProvider);

      state = const AsyncData(null);
    } catch (e) {
      state = AsyncError(e, StackTrace.current);
      rethrow;
    }
  }
}

/// Calendar navigation helpers
final calendarNavigationProvider = Provider((ref) {
  return CalendarNavigation(ref);
});

class CalendarNavigation {
  final Ref _ref;

  CalendarNavigation(this._ref);

  void goToPreviousMonth() {
    final current = _ref.read(selectedMonthProvider);
    _ref.read(selectedMonthProvider.notifier).state = DateTime(
      current.year,
      current.month - 1,
      1,
    );
  }

  void goToNextMonth() {
    final current = _ref.read(selectedMonthProvider);
    _ref.read(selectedMonthProvider.notifier).state = DateTime(
      current.year,
      current.month + 1,
      1,
    );
  }

  void goToToday() {
    final now = DateTime.now();
    _ref.read(selectedMonthProvider.notifier).state = DateTime(now.year, now.month, 1);
    _ref.read(selectedDateProvider.notifier).state = now;
  }

  void selectDate(DateTime date) {
    _ref.read(selectedDateProvider.notifier).state = date;
  }

  void clearSelectedDate() {
    _ref.read(selectedDateProvider.notifier).state = null;
  }
}
