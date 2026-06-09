import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/booking.dart';
import '../repositories/booking_repository.dart';

final upcomingBookingsProvider = FutureProvider<List<BookingListItem>>((ref) async {
  final repo = ref.watch(bookingRepositoryProvider);
  return repo.getUpcomingBookings();
});

final pastBookingsProvider = FutureProvider<List<BookingListItem>>((ref) async {
  final repo = ref.watch(bookingRepositoryProvider);
  return repo.getPastBookings(limit: 50);
});

final recentBookingsProvider = FutureProvider<List<BookingListItem>>((ref) async {
  final bookings = await ref.watch(upcomingBookingsProvider.future);
  return bookings.take(3).toList();
});
