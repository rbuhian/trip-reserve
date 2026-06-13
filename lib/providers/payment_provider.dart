import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/payment.dart';
import '../repositories/payment_repository.dart';

/// Watches the latest payment for a booking (null until one is created).
/// Driven by Supabase Realtime so the UI reacts when the webhook marks it paid.
/// Family keyed by bookingId. The UI calls `createCheckout` on the repository
/// directly via `ref.read(paymentRepositoryProvider)`.
final paymentForBookingProvider =
    StreamProvider.family<Payment?, String>((ref, bookingId) {
  final repo = ref.watch(paymentRepositoryProvider);
  return repo.watchPayment(bookingId);
});
